defmodule Xaas.Ultracode.Probes do
  @moduledoc """
  Falsifier probes: named, known-breaking mutations, given as DATA, that a
  definition-of-done (DoD) suite is REQUIRED to notice.

  A green DoD proves nothing if the same command is also green on a tree that
  is known to be broken -- an `exit 0` DoD passes everything. A probe makes
  that check mechanical: apply the mutation to a SCRATCH CLONE of the exact
  head under test, rerun the suite there, and require it to FAIL. The
  orchestration (rerun, verdict, refusal) lives in `Xaas.Ultracode.Verifier`;
  this module owns the two halves that are pure data + git:

    * `admit/1` -- normalises and validates probe declarations (string- or
      atom-keyed; unknown keys refused; nothing from a declaration is ever
      turned into an atom, interpolated into an argv, or used as a path
      without the containment checks below);
    * `scratch_clone/3` + `apply_probe/2` -- materialise the exact head in a fresh
      clone and mutate THAT. The real worktree is never opened for writing.

  ## Probe shape

      %{"id" => "kill-answer",              # [A-Za-z0-9._:-]{1,80}, unique
        "kind" => "replace",                # see below
        "file" => "answer.txt",             # repo-relative, no `..`, not under .git
        "pattern" => "42",                  # literal text (never a regex)
        "replacement" => "41",              # replace only
        "occurrence" => "first",            # "first" (default) | "all"
        "falsifier" => "wrong answer accepted",   # optional order anchors
        "acceptance" => 0}                  #   (text or index into the order)

  Kinds:

    * `replace` -- replace `pattern` with `replacement` in `file`;
    * `delete_line` -- drop the line(s) of `file` containing `pattern`;
    * `delete_file` -- remove `file`;
    * `truncate` -- empty `file` (corrupt a fixture);
    * `revert_commit` -- `git revert --no-commit` the `commit` (7-40 hex, or
      `HEAD`/`HEAD~N`) in the clone: the implementation of a feature is
      removed and the DoD must notice.

  ## Refusal law

  A probe that cannot be applied (pattern absent, file missing, revert
  conflict, mutation that leaves the tree unchanged) proves nothing and is a
  typed `{:probe_unapplicable, reason}` -- the verifier refuses rather than
  count it as a kill or a survival. File paths are walked component by
  component with `lstat`; a symlink anywhere on the path is refused, so a
  committed symlink cannot aim a mutation outside the clone.
  """

  @kinds ~w(replace delete_line delete_file truncate revert_commit)
  @occurrences ~w(first all)
  @id_re ~r/\A[A-Za-z0-9._:-]{1,80}\z/
  @rev_re ~r/\A([0-9a-fA-F]{7,40}|HEAD(~[0-9]{1,3})?)\z/
  @head_re ~r/\A[0-9a-f]{40}\z/
  @max_probes 32
  @max_text 4_096
  @max_path 512
  @max_file_bytes 8_388_608

  @key_atoms %{
    "id" => :id,
    "kind" => :kind,
    "file" => :file,
    "pattern" => :pattern,
    "replacement" => :replacement,
    "commit" => :commit,
    "occurrence" => :occurrence,
    "falsifier" => :falsifier,
    "acceptance" => :acceptance
  }

  @git_env [
    {"GIT_TERMINAL_PROMPT", "0"},
    {"GIT_AUTHOR_NAME", "xaas-probe"},
    {"GIT_AUTHOR_EMAIL", "probe@xaas.local"},
    {"GIT_COMMITTER_NAME", "xaas-probe"},
    {"GIT_COMMITTER_EMAIL", "probe@xaas.local"}
  ]

  @type probe :: %{
          required(:id) => String.t(),
          required(:kind) => String.t(),
          optional(atom()) => term()
        }

  @doc "The mutation kinds a probe may declare."
  @spec kinds() :: [String.t()]
  def kinds, do: @kinds

  @doc """
  Admits a list of probe declarations: `{:ok, [probe]}` (atom-keyed, canonical)
  or `{:error, reason}`. `[]` and `nil` admit as `[]`.
  """
  @spec admit(term()) :: {:ok, [probe()]} | {:error, term()}
  def admit(nil), do: {:ok, []}
  def admit([]), do: {:ok, []}

  def admit(list) when is_list(list) do
    if length(list) > @max_probes do
      {:error, {:too_many_probes, length(list), @max_probes}}
    else
      list
      |> Enum.with_index()
      |> Enum.reduce_while({:ok, []}, fn {raw, index}, {:ok, acc} ->
        case admit_one(raw) do
          {:ok, probe} -> {:cont, {:ok, [probe | acc]}}
          {:error, reason} -> {:halt, {:error, {:invalid_probe, label(raw, index), reason}}}
        end
      end)
      |> case do
        {:ok, reversed} -> unique(Enum.reverse(reversed))
        error -> error
      end
    end
  end

  def admit(_), do: {:error, :probes_must_be_a_list}

  @doc "Registration-time problem strings for `Xaas.Ultracode.TargetSuites.validate/1`."
  @spec problems(term()) :: [String.t()]
  def problems(probes) do
    case admit(probes) do
      {:ok, _} -> []
      {:error, reason} -> ["probes: #{inspect(reason)}"]
    end
  end

  @doc "JSON-safe (string-keyed) form of an admitted probe."
  @spec to_map(probe()) :: map()
  def to_map(probe), do: Map.new(probe, fn {k, v} -> {Atom.to_string(k), v} end)

  # ------------------------------------------------------------------
  # Scratch clone
  # ------------------------------------------------------------------

  @doc """
  Materialises `head` (a full 40-hex sha) of the repository that owns
  `source` (a repo root or a linked worktree) as a fresh clone at `dest`,
  detached at `head`. Template-free (no hooks) and never writes to `source`.
  Returns `{:ok, dest}`; on any failure `dest` is removed.
  """
  @spec scratch_clone(String.t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def scratch_clone(source, head, dest) when is_binary(source) and is_binary(dest) do
    with :ok <- check(is_binary(head) and Regex.match?(@head_re, head), :head_must_be_full_sha),
         {:ok, common} <- common_dir(source),
         :ok <- File.mkdir_p(Path.dirname(dest)),
         :ok <- check(not File.exists?(dest), :scratch_exists),
         {_, 0} <- git_out(["clone", "--quiet", "--no-checkout", "--template=", common, dest]),
         {_, 0} <-
           git_out([
             "-C",
             dest,
             "-c",
             "advice.detachedHead=false",
             "checkout",
             "--quiet",
             "--detach",
             head
           ]) do
      {:ok, dest}
    else
      # Never remove a `dest` this call did not create.
      {:error, :scratch_exists} = error ->
        error

      {:error, _} = error ->
        File.rm_rf(dest)
        error

      {out, code} when is_binary(out) and is_integer(code) ->
        File.rm_rf(dest)
        {:error, {:scratch_clone_failed, code, tail(out)}}
    end
  end

  # ------------------------------------------------------------------
  # Mutation
  # ------------------------------------------------------------------

  @doc """
  Applies an admitted `probe` to `clone`. `:ok` only when the tree really
  changed; `{:error, {:probe_unapplicable, reason}}` otherwise.
  """
  @spec apply_probe(probe(), String.t()) :: :ok | {:error, {:probe_unapplicable, term()}}
  def apply_probe(probe, clone) do
    with :ok <- mutate(probe, clone),
         :ok <- changed(clone) do
      :ok
    else
      {:error, {:probe_unapplicable, _}} = error -> error
      {:error, reason} -> {:error, {:probe_unapplicable, reason}}
    end
  end

  defp mutate(%{kind: "replace"} = p, clone) do
    with {:ok, path} <- regular_file(clone, p.file),
         {:ok, text} <- read_bounded(path),
         :ok <- check(:binary.match(text, p.pattern) != :nomatch, :pattern_not_found) do
      File.write(path, replace(text, p.pattern, p.replacement, p.occurrence))
    end
  end

  defp mutate(%{kind: "delete_line"} = p, clone) do
    with {:ok, path} <- regular_file(clone, p.file),
         {:ok, text} <- read_bounded(path),
         :ok <- check(:binary.match(text, p.pattern) != :nomatch, :pattern_not_found) do
      {_dropped, kept} = split_lines(String.split(text, "\n"), p.pattern, p.occurrence)
      File.write(path, Enum.join(kept, "\n"))
    end
  end

  defp mutate(%{kind: "delete_file"} = p, clone) do
    with {:ok, path} <- regular_file(clone, p.file), do: File.rm(path)
  end

  defp mutate(%{kind: "truncate"} = p, clone) do
    with {:ok, path} <- regular_file(clone, p.file),
         {:ok, %File.Stat{size: size}} <- File.stat(path),
         :ok <- check(size > 0, :file_already_empty) do
      File.write(path, "")
    end
  end

  defp mutate(%{kind: "revert_commit", commit: commit}, clone) do
    with {_, 0} <-
           git_out(["-C", clone, "rev-parse", "--verify", "--quiet", commit <> "^{commit}"]),
         {_, 0} <- git_out(["-C", clone, "revert", "--no-commit", "--no-edit", commit]) do
      :ok
    else
      {out, code} when is_binary(out) and is_integer(code) ->
        {:error, {:revert_failed, code, tail(out)}}
    end
  end

  defp replace(text, pattern, replacement, "all"), do: String.replace(text, pattern, replacement)

  defp replace(text, pattern, replacement, "first"),
    do: String.replace(text, pattern, replacement, global: false)

  defp split_lines(lines, pattern, "all"),
    do: Enum.split_with(lines, &String.contains?(&1, pattern))

  defp split_lines(lines, pattern, "first") do
    case Enum.find_index(lines, &String.contains?(&1, pattern)) do
      nil -> {[], lines}
      index -> {[Enum.at(lines, index)], List.delete_at(lines, index)}
    end
  end

  defp changed(clone) do
    case git_out(["-C", clone, "status", "--porcelain"]) do
      {"", 0} -> {:error, :mutation_left_tree_unchanged}
      {_, 0} -> :ok
      {out, code} -> {:error, {:git_status_failed, code, tail(out)}}
    end
  end

  # A regular file at `rel` under `clone`, reached WITHOUT crossing a symlink.
  defp regular_file(clone, rel) do
    parts = Path.split(rel)

    Enum.reduce_while(parts, {:ok, clone}, fn part, {:ok, dir} ->
      candidate = Path.join(dir, part)

      case File.lstat(candidate) do
        {:ok, %File.Stat{type: :symlink}} -> {:halt, {:error, :symlink_refused}}
        {:ok, _} -> {:cont, {:ok, candidate}}
        {:error, _} -> {:halt, {:error, :file_not_found}}
      end
    end)
    |> case do
      {:ok, path} ->
        case File.lstat(path) do
          {:ok, %File.Stat{type: :regular}} -> {:ok, path}
          _ -> {:error, :not_a_regular_file}
        end

      error ->
        error
    end
  end

  defp read_bounded(path) do
    case File.stat(path) do
      {:ok, %File.Stat{size: size}} when size <= @max_file_bytes -> File.read(path)
      {:ok, _} -> {:error, :file_too_large}
      {:error, reason} -> {:error, reason}
    end
  end

  # ------------------------------------------------------------------
  # Admission
  # ------------------------------------------------------------------

  defp admit_one(raw) when is_map(raw) do
    with {:ok, probe} <- normalize_keys(raw),
         :ok <- valid_id(probe),
         :ok <- valid_kind(probe),
         probe = Map.put_new(probe, :occurrence, "first"),
         :ok <- valid_occurrence(probe),
         :ok <- valid_fields(probe),
         :ok <- valid_anchors(probe) do
      {:ok, probe}
    end
  end

  defp admit_one(_), do: {:error, :probe_must_be_a_map}

  defp normalize_keys(raw) do
    Enum.reduce_while(raw, {:ok, %{}}, fn {k, v}, {:ok, acc} ->
      key = if is_atom(k), do: Atom.to_string(k), else: k

      case Map.fetch(@key_atoms, key) do
        {:ok, atom} -> {:cont, {:ok, Map.put(acc, atom, v)}}
        :error -> {:halt, {:error, {:unknown_key, inspect(k)}}}
      end
    end)
  end

  defp valid_id(%{id: id}) when is_binary(id) do
    if Regex.match?(@id_re, id), do: :ok, else: {:error, :bad_id}
  end

  defp valid_id(_), do: {:error, :id_required}

  defp valid_kind(%{kind: kind}) when kind in @kinds, do: :ok
  defp valid_kind(%{kind: kind}), do: {:error, {:unknown_kind, inspect(kind)}}
  defp valid_kind(_), do: {:error, :kind_required}

  defp valid_occurrence(%{occurrence: occ}) when occ in @occurrences, do: :ok
  defp valid_occurrence(_), do: {:error, :bad_occurrence}

  defp valid_fields(%{kind: "replace"} = p),
    do: all([file(p), pattern(p), replacement(p)])

  defp valid_fields(%{kind: "delete_line"} = p), do: all([file(p), pattern(p)])
  defp valid_fields(%{kind: "delete_file"} = p), do: file(p)
  defp valid_fields(%{kind: "truncate"} = p), do: file(p)

  defp valid_fields(%{kind: "revert_commit"} = p) do
    case Map.get(p, :commit) do
      commit when is_binary(commit) ->
        if Regex.match?(@rev_re, commit), do: :ok, else: {:error, :bad_commit}

      _ ->
        {:error, :commit_required}
    end
  end

  defp all(results), do: Enum.find(results, :ok, &(&1 != :ok))

  defp file(%{file: file}) when is_binary(file) do
    parts = Path.split(file)

    cond do
      file == "" or byte_size(file) > @max_path -> {:error, :bad_file}
      String.contains?(file, <<0>>) -> {:error, :bad_file}
      Path.type(file) != :relative -> {:error, :file_must_be_relative}
      ".." in parts -> {:error, :file_escapes_repo}
      hd(parts) == ".git" -> {:error, :file_in_git_dir}
      true -> :ok
    end
  end

  defp file(_), do: {:error, :file_required}

  defp pattern(%{pattern: pattern}) when is_binary(pattern) do
    if pattern != "" and byte_size(pattern) <= @max_text and not String.contains?(pattern, <<0>>),
      do: :ok,
      else: {:error, :bad_pattern}
  end

  defp pattern(_), do: {:error, :pattern_required}

  defp replacement(%{replacement: r}) when is_binary(r) do
    if byte_size(r) <= @max_text and not String.contains?(r, <<0>>),
      do: :ok,
      else: {:error, :bad_replacement}
  end

  defp replacement(_), do: {:error, :replacement_required}

  defp valid_anchors(probe) do
    [:falsifier, :acceptance]
    |> Enum.find_value(:ok, fn key ->
      case Map.fetch(probe, key) do
        :error -> nil
        {:ok, v} when (is_binary(v) and v != "") or (is_integer(v) and v >= 0) -> nil
        {:ok, _} -> {:error, {:bad_anchor, key}}
      end
    end)
  end

  defp unique(probes) do
    ids = Enum.map(probes, & &1.id)

    case ids -- Enum.uniq(ids) do
      [] -> {:ok, probes}
      dups -> {:error, {:duplicate_probe_ids, Enum.uniq(dups)}}
    end
  end

  defp label(%{} = raw, index), do: to_string(raw["id"] || raw[:id] || "##{index}")
  defp label(_, index), do: "##{index}"

  # ------------------------------------------------------------------
  # git plumbing
  # ------------------------------------------------------------------

  defp common_dir(source) do
    case git_out(["-C", source, "rev-parse", "--path-format=absolute", "--git-common-dir"]) do
      {out, 0} -> {:ok, String.trim(out)}
      {out, code} -> {:error, {:not_a_repository, code, tail(out)}}
    end
  end

  defp git_out(args), do: System.cmd("git", args, stderr_to_stdout: true, env: @git_env)

  defp check(true, _reason), do: :ok
  defp check(false, reason), do: {:error, reason}

  defp tail(out), do: out |> String.trim() |> String.slice(-300, 300)
end
