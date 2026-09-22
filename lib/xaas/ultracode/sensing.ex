defmodule Xaas.Ultracode.Sensing do
  @moduledoc """
  Profile-driven backlog sensing for ANY registered repository (wave 5,
  generic `sense` stage). The APS-specific ancestor of this capability is
  `priv/verifiers/aps_backlog.py` driven by `Xaas.Ultracode.Autonomic.sense/1`;
  that path is untouched. This module derives work items from a repo's OWN
  artifacts (a TODO file, a jira ticket directory, a failing test suite), so
  CLI-agent waves can iterate on repos other than APS.

  ## Profile contract (the W5-A1 registry references this section)

  A sensing profile is a JSON-compatible map -- string keys are canonical,
  atom keys are accepted and normalized -- with one discriminator key `type`:

      %{"type" => "todo_file",
        "file" => "TODO.md",           # optional relative path, default "TODO.md"
        ...common options...}

        One item per unchecked GitHub task-list line (`- [ ] ...`) in the file.

      %{"type" => "jira_dir",
        "dir" => "docs/jira",          # optional relative dir, default "docs/jira"
        "closed" => ["DONE", ...],     # optional closed standing first-words
        "include_unknown_status" => false,  # optional, default false
        ...common options...}

        One item per `*.md` ticket anywhere under `dir` whose `## Status`
        section's first non-blank line does NOT begin with a closed standing
        word (default closed set: DONE, MERGED, LANDED, CLOSED, RESOLVED,
        ALIVE -- case-insensitive). Tickets with no `## Status` section are
        skipped unless `include_unknown_status` is true.

      %{"type" => "failing_tests",
        "command" => ["mix", "test"],  # REQUIRED argv list, never a shell string
        "parser" => "exunit",          # optional: "exunit" (default) or "regex"
        "pattern" => "...",            # required iff parser == "regex"; matches
                                       # one failing test per line, optional
                                       # named captures `id` and `file`
        "timeout_ms" => 120_000,       # optional, default 120_000
        ...common options...}

        The command runs with its working directory set to the sensed tree (a
        provisioned worktree, never an operator checkout); its stdout+stderr is
        parsed and one item is emitted per distinct failing test. A non-zero
        suite exit is EXPECTED (that is what failing means) -- it is folded
        into each item's goal text; only a command that cannot run, hangs past
        `timeout_ms`, or a bad parser pattern is an error.

  Common options for every type:

      "max_items"      hard bound on emitted items, default 20 (applied after
                       dedup and the id sort -- the bound is part of the
                       deterministic output, never a silent prune)
      "allowed_paths"  non-empty glob list written into every item's ticket
                       scope, default ["*"] (the court's fnmatch-style globs)
      "item_overrides" map merged last into every item (lets a registry pin,
                       e.g. `"min_new_tests"`, without editing this module)

  ## Item contract (consumed by the wave planner / Autonomic)

  Every item is a JSON-compatible map with at least:

      "id"              stable: "<prefix>-<slug>-<6hex>"; the hash is the sha256
                        of the item's STABLE content (artifact text, not its
                        line number), so items do not churn when unrelated
                        lines move and change id only when their content
                        changes. Matches [A-Za-z0-9._:-]+.
      "goal"            mission text for the worker
      "allowed_paths"   non-empty glob list (ticket scope)
      "mutants"         [] (generic items carry no mutation contract)
      "min_new_tests"   nil unless set via "item_overrides"
      "min_kill_ratio"  nil unless set via "item_overrides"
      "source"          %{"file" => ..., "line" => ..., "text" => ...} -- the
                        exact artifact line the item came from

  ## Registered profile names (the fallback seam)

  A repo's registry entry CARRIES a profile name (`sensing: "xaas-sjira"`);
  the name-to-profile mapping itself is explicit operator config --
  `config :xaas, :ultracode_sensing_profiles` (`%{"xaas-sjira" => %{...}}
  `, same shape `derive/2` takes) -- resolved by `profile/1`.
  `registered?/1` is the registration-gap check `Xaas.Ultracode.Repos`
  computes for every entry. An unknown name, or a name mapped to a
  malformed profile, is a TYPED error -- never silently ignored. The
  consumer is the Autonomic sense stage's fallback law: a repo's backlog
  script that exits 0 wins unchanged; on a script failure the entry's
  `sensing:` name drives `derive/2` over the SAME provisioned tree; with no
  implemented profile the stage refuses typed.

  ## Determinism and pinning

  `derive/2` reads a CHECKOUT PATH; callers pin the tree by provisioning a
  detached worktree first (`Xaas.Ultracode.Worktrees.provision/3`) -- `sense/4`
  does exactly that against a registered alias at an exact `base_sha`, and
  always cleans the worktree up. The same tree state + the same profile yield a
  BYTE-IDENTICAL document: no clocks, no randomness, no environment reads;
  items are deduplicated by id, sorted by id, and bounded. The document shape:

      %{"schemaVersion" => "xaas-sensing/1",
        "head" => <40-hex sha of the sensed tree>,
        "profile" => <type string>,
        "items" => [...sorted by id...]}
  """

  alias Xaas.Ultracode.Worktrees

  @schema_version "xaas-sensing/1"
  @default_max_items 20
  @default_allowed_paths ["*"]
  @default_closed ~w(DONE MERGED LANDED CLOSED RESOLVED ALIVE)
  @known_types ~w(todo_file jira_dir failing_tests)
  @id_re ~r/\A[A-Za-z0-9._:-]+\z/

  @type profile :: map()

  @doc """
  Resolves a REGISTERED profile NAME to its explicit profile from
  `config :xaas, :ultracode_sensing_profiles`. This is the seam the
  Autonomic sense stage's fallback drives: a registry entry's `sensing:`
  name means nothing until it maps to a profile here, and the mapping is
  validated fail-closed -- an unknown name is `{:unknown_sensing_profile,
  name}`, a name mapped to a profile `derive/2` cannot normalize is
  `{:invalid_sensing_profile, name, reason}`. Never a guess, never a silent
  skip.
  """
  @spec profile(term()) ::
          {:ok, profile()}
          | {:error, {:unknown_sensing_profile, term()}}
          | {:error, {:invalid_sensing_profile, term(), term()}}
  def profile(name) when is_binary(name) do
    profiles = Application.get_env(:xaas, :ultracode_sensing_profiles, %{})

    with {:ok, prof} <- Map.fetch(profiles, name),
         {:ok, _normalized} <- normalize(prof) do
      {:ok, prof}
    else
      :error -> {:error, {:unknown_sensing_profile, name}}
      {:error, reason} -> {:error, {:invalid_sensing_profile, name, reason}}
    end
  end

  def profile(other), do: {:error, {:unknown_sensing_profile, other}}

  @doc """
  True iff `profile/1` resolves `name` to an implemented profile -- the
  registration-gap check `Xaas.Ultracode.Repos` computes for every entry
  (an unimplemented name is a visible `:sensing_profile_not_registered`
  gap, never silently ignored).
  """
  @spec registered?(term()) :: boolean()
  def registered?(name), do: match?({:ok, _}, profile(name))

  @doc """
  Senses a REGISTERED repo alias at an exact `base_sha`: provisions a detached
  worktree at that sha (never touching the operator clone's tree), derives
  items from the profile, and always cleans the worktree up. Options: `:name`
  (worktree slug override; a unique one is generated by default).
  """
  @spec sense(String.t(), String.t(), profile(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def sense(repo_alias, base_sha, profile, opts \\ []) do
    name = Keyword.get_lazy(opts, :name, fn -> "sense-#{System.unique_integer([:positive])}" end)

    with {:ok, path} <- Worktrees.provision(repo_alias, base_sha, name) do
      try do
        derive(profile, path)
      after
        Worktrees.cleanup(repo_alias, path)
      end
    end
  end

  @doc """
  Derives work items from the checkout (or detached worktree) at `path` using
  `profile`. See the module doc for the profile and item contracts.
  """
  @spec derive(profile(), String.t()) :: {:ok, map()} | {:error, term()}
  def derive(profile, path)

  def derive(profile, path) when is_map(profile) and is_binary(path) do
    with {:ok, prof} <- normalize(profile),
         {:ok, head} <- head_of(path),
         {:ok, items} <- derive_items(prof, path) do
      {:ok,
       %{
         "schemaVersion" => @schema_version,
         "head" => head,
         "profile" => prof.type,
         "items" => finalize(items, prof)
       }}
    end
  end

  def derive(profile, _path) when not is_map(profile), do: {:error, :profile_not_a_map}

  def derive(_profile, path) when not is_binary(path), do: {:error, :path_not_a_string}

  # ----------------------------------------------------------------------
  # Profile normalization (string keys canonical; atoms accepted)
  # ----------------------------------------------------------------------

  defp normalize(%{"type" => type} = profile) when is_atom(type),
    do: normalize(Map.put(profile, "type", Atom.to_string(type)))

  defp normalize(%{"type" => type} = profile) when type in @known_types do
    {:ok,
     %{
       type: type,
       max_items: positive_int(profile["max_items"]) || @default_max_items,
       allowed_paths: nonempty_str_list(profile["allowed_paths"]) || @default_allowed_paths,
       item_overrides: normalize_overrides(profile["item_overrides"]),
       file: profile["file"] || "TODO.md",
       dir: profile["dir"] || "docs/jira",
       closed:
         Enum.map(nonempty_str_list(profile["closed"]) || @default_closed, &String.upcase/1),
       include_unknown_status: profile["include_unknown_status"] == true,
       command: nonempty_str_list(profile["command"]),
       parser: profile["parser"] || "exunit",
       pattern: profile["pattern"],
       timeout_ms: positive_int(profile["timeout_ms"]) || 120_000
     }}
  end

  defp normalize(%{"type" => type}), do: {:error, {:unknown_profile_type, type}}
  defp normalize(_profile), do: {:error, :profile_missing_type}

  defp normalize_overrides(m) when is_map(m), do: Map.new(m, fn {k, v} -> {to_string(k), v} end)
  defp normalize_overrides(_), do: %{}

  defp positive_int(n) when is_integer(n) and n > 0, do: n
  defp positive_int(_), do: nil

  defp nonempty_str_list(l) when is_list(l) and l != [],
    do: if(Enum.all?(l, &is_binary/1), do: l)

  defp nonempty_str_list(_), do: nil

  # ----------------------------------------------------------------------
  # Derivation dispatch + determinism finish (dedupe, sort, bound, override)
  # ----------------------------------------------------------------------

  defp derive_items(prof, path) do
    case prof.type do
      "todo_file" -> todo_items(prof, path)
      "jira_dir" -> jira_items(prof, path)
      "failing_tests" -> failing_test_items(prof, path)
    end
  end

  defp finalize(items, prof) do
    items
    |> Enum.uniq_by(& &1["id"])
    |> Enum.sort_by(& &1["id"])
    |> Enum.take(prof.max_items)
    |> Enum.map(&Map.merge(&1, prof.item_overrides))
  end

  # -- todo_file ----------------------------------------------------------

  @todo_re ~r/\A\s*-\s\[\s\]\s*(\S.*)\z/

  defp todo_items(prof, path) do
    with :ok <- safe_relative(prof.file),
         {:ok, text} <- read_regular(Path.join(path, prof.file), {:todo_file_missing, prof.file}) do
      items =
        text
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {line, n} ->
          case Regex.run(@todo_re, line, capture: :all_but_first) do
            [unchecked] ->
              [
                build_item(
                  "todo",
                  unchecked,
                  unchecked,
                  %{
                    "file" => prof.file,
                    "line" => n,
                    "text" => String.trim(line)
                  },
                  prof.allowed_paths
                )
              ]

            _ ->
              []
          end
        end)

      {:ok, items}
    end
  end

  # -- jira_dir -----------------------------------------------------------

  defp jira_items(prof, path) do
    with :ok <- safe_relative(prof.dir),
         {:ok, root} <- existing_dir(Path.join(path, prof.dir), {:jira_dir_missing, prof.dir}) do
      files = md_files(root)
      {:ok, Enum.flat_map(files, &jira_item(prof, path, &1))}
    end
  end

  defp md_files(root) do
    ["**/*.md", "**/*.markdown"]
    |> Enum.flat_map(&Path.wildcard(Path.join(root, &1)))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp jira_item(prof, tree_root, full) do
    rel = Path.relative_to(full, tree_root)
    stem = full |> Path.basename() |> Path.rootname()
    text = File.read!(full)
    title = h1_title(text) || stem
    status = status_line(text)

    open? =
      cond do
        is_nil(status) -> prof.include_unknown_status
        true -> first_word(status) not in prof.closed
      end

    if open? do
      # Stable content = relative path + title: History appends (the
      # operator's append-only ticket convention) must not churn the id.
      [
        build_item(
          "jira",
          title,
          rel <> "\n" <> title,
          %{
            "file" => rel,
            "line" => nil,
            "text" => status || ""
          },
          prof.allowed_paths
        )
      ]
    else
      []
    end
  end

  defp h1_title(text) do
    case Regex.run(~r/^#\s+(.+)$/m, text) do
      [_, title] -> String.trim(title)
      _ -> nil
    end
  end

  defp status_line(text) do
    case String.split(text, ~r/^##\s+Status\s*$/m, parts: 2) do
      [_before, after_status] ->
        after_status
        |> String.split("\n")
        |> Enum.drop_while(&(String.trim(&1) == ""))
        |> case do
          [line | _] -> String.trim(line)
          [] -> nil
        end

      [_only] ->
        nil
    end
  end

  defp first_word(line) do
    line
    |> String.split(~r/[\s—:,-]/, parts: 2)
    |> List.first()
    |> to_string()
    |> String.trim()
    |> String.upcase()
  end

  # -- failing_tests ------------------------------------------------------

  defp failing_test_items(prof, path) do
    with {:ok, argv} <- require_command(prof),
         {:ok, {out, suite_exit}} <- run_argv(argv, path, prof.timeout_ms),
         {:ok, failures} <- parse_failures(prof, out) do
      items =
        Enum.map(failures, fn {name, file} ->
          item =
            build_item(
              "fail",
              name,
              name <> "\n" <> file,
              %{
                "file" => file,
                "line" => nil,
                "text" => "#{name} -- #{file}"
              },
              prof.allowed_paths
            )

          put_suite_exit(item, suite_exit)
        end)

      {:ok, items}
    end
  end

  defp require_command(prof) do
    case prof.command do
      nil -> {:error, :failing_tests_requires_command}
      argv -> {:ok, argv}
    end
  end

  defp put_suite_exit(item, suite_exit) do
    goal =
      item["goal"] <>
        "\n\nThe test suite exited with code #{suite_exit} when this item was sensed."

    Map.put(item, "goal", goal)
  end

  # Runs `argv` with cwd = dir via a Port (System.cmd/3 cannot set the working
  # directory). Output is collected until EOF; the exit status rides AFTER all
  # port data in the mailbox, so returning on it cannot truncate output. A
  # non-zero exit is DATA here (a failing suite is the signal), never an error.
  defp run_argv(argv, dir, timeout_ms) do
    [exe_name | rest] = argv

    case exe_name && System.find_executable(exe_name) do
      nil ->
        {:error, {:command_not_found, exe_name}}

      exe ->
        port =
          Port.open({:spawn_executable, exe}, [
            :binary,
            :exit_status,
            :stderr_to_stdout,
            :hide,
            {:cd, dir},
            {:args, rest}
          ])

        deadline = System.monotonic_time(:millisecond) + timeout_ms
        collect(port, deadline, "", nil)
    end
  end

  defp collect(port, deadline, acc, nil) do
    remaining = deadline - System.monotonic_time(:millisecond)

    if remaining <= 0 do
      _ = Port.close(port)
      {:error, :command_timeout}
    else
      receive do
        {^port, {:data, data}} -> collect(port, deadline, acc <> data, nil)
        {^port, {:exit_status, code}} -> {:ok, {acc, code}}
      after
        remaining ->
          _ = Port.close(port)
          {:error, :command_timeout}
      end
    end
  end

  # -- failure-output parsers ---------------------------------------------

  @exunit_fail_re ~r/\A\s*\d+\)\s+test\s+(.+?)\s+\(([^)]+)\)\s*\z/
  @exunit_loc_re ~r/\A[^\s:]+:\d+\z/

  # ExUnit failure blocks look like:
  #     1) test name (Ctx.Module.test name)
  #        test/path_test.exs:12
  # ExUnit's random seed reorders blocks between runs; ids hash name+file
  # (never order or line), and finalize/2 sorts by id, so the document stays
  # byte-identical across runs even while the blocks themselves reorder.
  defp parse_failures(%{parser: "exunit"}, out) do
    lines = String.split(out, "\n")

    failures =
      Enum.flat_map(lines, fn line ->
        case Regex.run(@exunit_fail_re, line, capture: :all_but_first) do
          [name, module] -> [{"#{name} (#{module})", exunit_file(lines, name, module)}]
          _ -> []
        end
      end)

    {:ok, failures}
  end

  defp parse_failures(%{parser: "regex", pattern: pattern}, out) when is_binary(pattern) do
    case Regex.compile(pattern) do
      {:ok, re} ->
        failures =
          Enum.flat_map(String.split(out, "\n"), fn line ->
            case Regex.run(re, line) do
              nil ->
                []

              [full] ->
                [{full, "suite-output"}]

              [full | captures] ->
                named = Regex.named_captures(re, line)

                id =
                  non_blank(named["id"]) || non_blank(Enum.find(captures, &(&1 != ""))) || full

                [{id, non_blank(named["file"]) || "suite-output"}]
            end
          end)

        {:ok, failures}

      {:error, reason} ->
        {:error, {:bad_pattern, reason}}
    end
  end

  defp parse_failures(%{parser: "regex"}, _out), do: {:error, :regex_parser_requires_pattern}
  defp parse_failures(%{parser: other}, _out), do: {:error, {:unknown_parser, other}}

  defp exunit_file(lines, name, module) do
    header = "test #{name} (#{module})"

    idx = Enum.find_index(lines, &String.contains?(&1, header))

    case idx && Enum.slice(lines, idx + 1, 3) do
      slice when is_list(slice) ->
        case Enum.find(slice, &(Regex.match?(@exunit_loc_re, String.trim(&1)) and &1 != "")) do
          nil -> module
          loc -> loc |> String.trim() |> String.split(":") |> hd()
        end

      _ ->
        module
    end
  end

  defp non_blank(s) when is_binary(s) and s != "", do: s
  defp non_blank(_), do: nil

  # ----------------------------------------------------------------------
  # Item construction (id law: slug + content hash of STABLE text)
  # ----------------------------------------------------------------------

  defp build_item(prefix, slug_text, hash_text, source, allowed_paths) do
    id = "#{prefix}-#{slugify(slug_text)}-#{content_hash(hash_text)}"
    validate_id!(id)

    %{
      "id" => id,
      "goal" => build_goal(prefix, source, id),
      "allowed_paths" => allowed_paths,
      "min_new_tests" => nil,
      "min_kill_ratio" => nil,
      "mutants" => [],
      "source" => source
    }
  end

  defp validate_id!(id) do
    if Regex.match?(@id_re, id) do
      :ok
    else
      raise "sensing id violated the ticket charset [A-Za-z0-9._:-]+: #{inspect(id)}"
    end
  end

  defp content_hash(text) do
    :crypto.hash(:sha256, text)
    |> Base.encode16(case: :lower)
    |> binary_part(0, 6)
  end

  defp slugify(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.replace(~r/\A-+|-+\z/, "")
    |> String.slice(0, 40)
    |> String.replace(~r/-+\z/, "")
  end

  defp build_goal("todo", source, id) do
    """

    Work item sensed from `#{source["file"]}` line #{source["line"]} (unchecked task):

        #{source["text"]}

    Implement the task it describes. Keep every change within the ticket's
    allowed_paths, commit with a message naming the item id `#{id}`, and close
    through the normal lease protocol with your final head.
    """
    |> String.trim_leading()
    |> String.trim_trailing()
  end

  defp build_goal("jira", source, _id) do
    """

    Work the ticket at `#{source["file"]}`. Read the ticket BEFORE working; it
    carries the authoritative scope, invariants, and dependencies. Follow the
    ticket's own acceptance criteria. Append every transition to the ticket's
    History section (ts | standing | branch+SHA | gates+exits | remaining),
    commit on a purpose branch in the worktree, and close through the normal
    lease protocol with your final head.
    """
    |> String.trim_leading()
    |> String.trim_trailing()
  end

  defp build_goal("fail", source, _id) do
    """

    The test suite reports this failure when sensed:

        #{source["text"]}

    Make the failing test pass WITHOUT weakening, skipping, or deleting it
    (and without weakening any other test). Fix the production or test code
    the failure points at, commit, and close through the normal lease protocol
    with your final head.
    """
    |> String.trim_leading()
    |> String.trim_trailing()
  end

  # ----------------------------------------------------------------------
  # Small shared helpers
  # ----------------------------------------------------------------------

  defp head_of(path) do
    case System.cmd("git", ["-C", path, "rev-parse", "HEAD"], stderr_to_stdout: true) do
      {out, 0} -> {:ok, String.trim(out)}
      {out, _} -> {:error, {:not_a_git_checkout, String.trim(out)}}
    end
  end

  # Profile-relative paths must stay inside the sensed tree: no absolute
  # paths, no `..` traversal.
  defp safe_relative(p) when is_binary(p) and p != "" do
    parts = Path.split(p)

    if "/" in parts or ".." in parts do
      {:error, {:profile_path_must_be_relative, p}}
    else
      :ok
    end
  end

  defp safe_relative(p), do: {:error, {:profile_path_must_be_relative, p}}

  defp read_regular(full, error) do
    if File.regular?(full), do: {:ok, File.read!(full)}, else: {:error, error}
  end

  defp existing_dir(full, error) do
    if File.dir?(full), do: {:ok, full}, else: {:error, error}
  end
end
