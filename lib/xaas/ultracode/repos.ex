defmodule Xaas.Ultracode.Repos do
  @moduledoc """
  The multi-repo registry law for the ultracode campaign: WHICH repositories
  the loop may target, and what each target is provisioned with -- a local
  clone path, a sensing profile, a verifier suite, an optional worktree root.

  Before this registry, `config :xaas, :ultracode_repos` was a bare
  alias => path map and the loop hard-wired every other fact to APS: the
  backlog script (`priv/verifiers/aps_backlog.py`), the suites
  (`aps-dod` / `aps-canonical`), even the worktree name prefixes. Targeting a
  second repository meant re-reading the loop's source. The registry makes
  the target a validated datum instead of an assumption.

  ## Entry shape (normalized)

      %{
        alias: "aps",                     # ^[a-z][a-z0-9_-]{0,31}$
        path: "/abs/clone",               # exists + is a git work tree
        sensing: "aps",                   # sensing profile name (see below)
        suite: "aps-dod",                 # per-item verifier suite name
        canonical_suite: "aps-canonical", # integration-head suite (nil = skip)
        worktree_root: nil,               # nil = global :ultracode_worktree_root
        suite_registered: true            # named in :ultracode_verifier_suites?
      }

  ## Sources

    * `config :xaas, :ultracode_repos` -- the code-seeded baseline map. Two
      raw forms per alias: a bare path STRING (the legacy form; carries the
      historical APS defaults -- sensing "aps", suite "aps-dod",
      canonical_suite "aps-canonical" -- so `%{"aps" => path}` behaves exactly
      as before this registry) or a MAP with `path` plus optional `sensing`,
      `suite`, `canonical_suite`, `worktree_root` (string or atom keys).
    * the durable registry file (`config :xaas, :ultracode_repos_file`,
      default `~/xaas-worktrees/ultracode-repos.json` in dev) -- written ONLY
      through `register/2` (the `mix xaas.ultracode.repos --register` path),
      which validates before writing and merges additively. File entries WIN
      over env entries for the same alias: the file is the operator's latest
      registration intent.

  ## Validation law (fail closed, typed)

    * alias matches `^[a-z][a-z0-9_-]{0,31}$` -- a worktree-name-safe slug;
    * path: expanded, absolute, exists, and `git -C path rev-parse --git-dir`
      succeeds (a real checkout or a linked worktree, not merely a `.git`
      name);
    * suite and sensing names match the alias format (the verifier suite
      vocabulary is name-only -- nothing here interprets what a suite runs);
    * worktree_root, when set: absolute, and -- because the fabric court's
      containment law (`Xaas.Ultracode.Verifier`) admits only worktrees under
      the GLOBAL `:ultracode_worktree_root` -- equal to or under that root.
      An override outside the global root would provision worktrees the court
      refuses to judge, so it is refused at registration, never at verify
      time.

  ## Reservation law (suite gaps are noted, not refused)

  An entry's suite does NOT have to be in `config :xaas,
  :ultracode_verifier_suites` yet: registering a target RESERVES the name --
  that is how the campaign grows before implementations land. The gap is
  computed on every read (`gaps/1`, `ready?/1`) and printed by
  `mix xaas.ultracode.repos`. Dispatch still fails closed where the gap
  bites: `Run` admission refuses an unregistered suite
  (`VerifierSuiteRegistered`). The entry's `sensing` name is RECORDED
  metadata for the target (profile-driven sensing is owned by
  `Xaas.Ultracode.Sensing`; the loop's script-backed aps stage is wired in
  `Autonomic.sense/1`) -- this module never judges or resolves it.

  This module is registry-only: it never starts the application, never
  touches a database, and never runs a suite. It reads config, the
  filesystem, and git -- nothing else.
  """

  alias Xaas.Ultracode.Verifier

  @name_format ~r/^[a-z][a-z0-9_-]{0,31}$/

  # The legacy path-string form carries exactly the pre-registry behavior:
  # an APS-shaped target. Structured entries name their own facts.
  @legacy_defaults %{
    sensing: "aps",
    suite: "aps-dod",
    canonical_suite: "aps-canonical",
    worktree_root: nil
  }

  @typedoc "A validated registry entry."
  @type entry :: %{
          required(:alias) => String.t(),
          required(:path) => String.t(),
          required(:sensing) => String.t(),
          required(:suite) => String.t(),
          required(:canonical_suite) => String.t() | nil,
          required(:worktree_root) => String.t() | nil,
          required(:suite_registered) => boolean(),
          required(:canonical_suite_registered) => boolean() | nil
        }

  @typedoc "A source-level warning (a corrupt registry file, a bad env shape)."
  @type warning :: {atom(), term()}

  @doc """
  Resolves `repo_alias` to a validated entry from the merged registry
  (config baseline + durable file, file wins). Unknown aliases and invalid
  entries are typed refusals, never guesses.
  """
  @spec resolve(term()) ::
          {:ok, entry()}
          | {:error, {:unknown_repo_alias, term()}}
          | {:error, {:invalid_repo_entry, term(), term()}}
  def resolve(repo_alias) do
    {raw, _warnings} = raw_entries()

    case raw do
      %{^repo_alias => raw_entry} -> validate(repo_alias, raw_entry)
      _ -> {:error, {:unknown_repo_alias, repo_alias}}
    end
  end

  @doc """
  The RAW (unvalidated) registry entry for `repo_alias` from the merged
  sources -- the lookup `Xaas.Ultracode.Worktrees.registry_entry/1` delegates
  to, so file-registered targets are provisionable without a second
  hand-edited copy of the registry anywhere.
  """
  @spec raw_entry(term()) :: {:ok, term()} | :error
  def raw_entry(repo_alias) do
    {raw, _warnings} = raw_entries()
    Map.fetch(raw, repo_alias)
  end

  @doc """
  Every registry entry with its per-entry validation result, plus the
  source-level warnings (a corrupt registry file never silently disappears:
  it is surfaced here and printed by `mix xaas.ultracode.repos`).
  """
  @spec entries() :: {%{optional(String.t()) => {:ok, entry()} | {:error, term()}}, [warning()]}
  def entries do
    {raw, warnings} = raw_entries()
    {Map.new(raw, fn {alias, raw_entry} -> {alias, validate(alias, raw_entry)} end), warnings}
  end

  @doc """
  Validates one raw `{alias, raw_entry}` pair under the registry law and
  returns the normalized entry (with its registration gaps computed) or a
  typed error. This is the exact judgment `register/2` and `resolve/1` apply.
  """
  @spec validate(term(), term()) ::
          {:ok, entry()} | {:error, {:invalid_repo_entry, term(), term()}}
  def validate(alias, raw_entry) do
    with :ok <- check(name?(alias), {:bad_alias, alias}),
         fields = normalize_raw(raw_entry),
         {:ok, path} <- validate_path(fields.path),
         :ok <- check(name?(fields.sensing), {:bad_sensing_profile, fields.sensing}),
         :ok <- check(name?(fields.suite), {:bad_suite_name, fields.suite}),
         :ok <-
           check(
             is_nil(fields.canonical_suite) or name?(fields.canonical_suite),
             {:bad_suite_name, fields.canonical_suite}
           ),
         {:ok, worktree_root} <- validate_worktree_root(fields.worktree_root) do
      {:ok,
       %{
         alias: alias,
         path: path,
         sensing: fields.sensing,
         suite: fields.suite,
         canonical_suite: fields.canonical_suite,
         worktree_root: worktree_root,
         suite_registered: Verifier.registered?(fields.suite),
         canonical_suite_registered:
           if(fields.canonical_suite, do: Verifier.registered?(fields.canonical_suite))
       }}
    else
      {:error, reason} -> {:error, {:invalid_repo_entry, alias, reason}}
    end
  end

  @doc """
  Validates every entry in `additions` and writes them into the durable
  registry file (opts `:file` overrides `config :xaas, :ultracode_repos_file`).
  Additive merge: existing file entries are preserved, same-alias additions
  replace. A corrupt or unparseable file is NEVER clobbered -- the write is
  refused so the corruption stays visible. Writes are atomic (tmp + rename).
  """
  @spec register(map(), keyword()) :: {:ok, [entry()]} | {:error, term()}
  def register(additions, opts \\ []) when is_map(additions) do
    with {:ok, file} <- registry_file(opts),
         :ok <- validate_all(additions) do
      case file_entries(file) do
        {existing, []} ->
          # Nil-valued keys are OMITTED (never written as null): an absent
          # key means "default", and `Worktrees` entry law refuses explicit
          # nil optionals.
          additions = Map.new(additions, fn {a, raw} -> {a, drop_nils(raw)} end)
          merged = Map.merge(existing, additions)
          json = Jason.encode!(merged, pretty: true) <> "\n"
          tmp = file <> ".tmp-#{System.unique_integer([:positive])}"

          with :ok <- File.mkdir_p(Path.dirname(file)),
               :ok <- File.write(tmp, json),
               :ok <- File.rename(tmp, file) do
            {:ok, Enum.map(additions, fn {alias, raw} -> elem(validate(alias, raw), 1) end)}
          end

        {_corrupted, [warning | _]} ->
          {:error, warning}
      end
    end
  end

  @doc "True when the entry has no registration gaps (suites registered)."
  @spec ready?(entry()) :: boolean()
  def ready?(%{suite_registered: suite?, canonical_suite_registered: canonical?}) do
    suite? and (is_nil(canonical?) or canonical?)
  end

  @doc "The registration gaps of an entry (empty iff `ready?/1`), for listings and docs."
  @spec gaps(entry()) :: [atom()]
  def gaps(entry) do
    [
      if(entry.suite_registered, do: nil, else: :suite_not_registered),
      if(is_nil(entry.canonical_suite) or entry.canonical_suite_registered,
        do: nil,
        else: :canonical_suite_not_registered
      )
    ]
    |> Enum.reject(&is_nil/1)
  end

  # ------------------------------------------------------------------
  # Sources
  # ------------------------------------------------------------------

  defp raw_entries do
    {env_map, env_warnings} = env_entries()

    {file_map, file_warnings} =
      case registry_file([]) do
        {:ok, file} -> file_entries(file)
        {:error, _} -> {%{}, []}
      end

    # File wins: the durable file is the operator's latest registration
    # intent over the code-seeded baseline.
    {Map.merge(env_map, file_map), env_warnings ++ file_warnings}
  end

  defp env_entries do
    case Application.get_env(:xaas, :ultracode_repos, %{}) do
      map when is_map(map) -> {map, []}
      other -> {%{}, [{:invalid_repos_env, other}]}
    end
  end

  defp registry_file(opts) do
    case Keyword.get(opts, :file) || Application.get_env(:xaas, :ultracode_repos_file) do
      file when is_binary(file) and file != "" -> {:ok, file}
      _ -> {:error, :registry_file_unconfigured}
    end
  end

  # Reads ONLY the durable file (not the merge): `register/2` must extend the
  # operator's file, never fold the code-seeded env baseline into it.
  defp file_entries(file) do
    if File.regular?(file) do
      case file |> File.read!() |> Jason.decode() do
        {:ok, map} when is_map(map) -> {map, []}
        {:ok, other} -> {%{}, [{:registry_file_not_a_map, file, other}]}
        {:error, reason} -> {%{}, [{:registry_file_unreadable, file, reason}]}
      end
    else
      {%{}, []}
    end
  end

  # ------------------------------------------------------------------
  # Validation
  # ------------------------------------------------------------------

  # Legacy path-string => historical APS-shaped target (byte-compatible with
  # the pre-registry `%{"aps" => path}` behavior). Structured raw entries
  # name their own facts; an absent canonical_suite defaults to the aps one,
  # an EXPLICIT nil skips the canonical suite.
  defp normalize_raw(raw) when is_binary(raw), do: Map.merge(@legacy_defaults, %{path: raw})

  defp normalize_raw(raw) when is_map(raw) do
    %{
      path: lookup(raw, :path),
      sensing: lookup(raw, :sensing) || "aps",
      suite: lookup(raw, :suite) || "aps-dod",
      canonical_suite: canonical_of(raw),
      worktree_root: lookup(raw, :worktree_root)
    }
  end

  defp normalize_raw(other),
    do: %{path: other, sensing: nil, suite: nil, canonical_suite: nil, worktree_root: nil}

  # Raw entries may carry atom or string keys (config files vs the JSON
  # registry file). Single total clause -- no guarded clause pairs.
  defp lookup(raw, key) do
    cond do
      Map.has_key?(raw, key) -> Map.get(raw, key)
      Map.has_key?(raw, to_string(key)) -> Map.get(raw, to_string(key))
      true -> nil
    end
  end

  # Absent key defaults to the historical aps canonical suite; an EXPLICIT
  # nil means the canonical suite is skipped for this target.
  defp canonical_of(raw) do
    if lookup(raw, :canonical_suite) == nil and not has_canonical_key?(raw) do
      "aps-canonical"
    else
      lookup(raw, :canonical_suite)
    end
  end

  defp has_canonical_key?(raw),
    do: Map.has_key?(raw, :canonical_suite) or Map.has_key?(raw, "canonical_suite")

  defp validate_path(path) do
    cond do
      not is_binary(path) ->
        {:error, :bad_repo_path}

      # Refused BEFORE expansion: a relative path would silently become
      # cwd-dependent; registry entries are absolute facts.
      not String.starts_with?(path, "/") ->
        {:error, :repo_path_not_absolute}

      true ->
        expanded = Path.expand(path)

        cond do
          not File.exists?(expanded) -> {:error, :repo_path_missing}
          not git_work_tree?(expanded) -> {:error, :repo_is_not_a_git_checkout}
          true -> {:ok, expanded}
        end
    end
  end

  # A real git work tree (checkout or linked worktree) -- not merely a
  # directory that happens to contain a `.git` name.
  defp git_work_tree?(path) do
    match?(
      {_, 0},
      System.cmd("git", ["-C", path, "rev-parse", "--git-dir"], stderr_to_stdout: true)
    )
  end

  defp validate_worktree_root(nil), do: {:ok, nil}

  defp validate_worktree_root(root) when is_binary(root) do
    # Refused BEFORE expansion, for the same cwd-dependence reason as the
    # clone path.
    if String.starts_with?(root, "/") do
      expanded = Path.expand(root)

      case global_worktree_root() do
        nil ->
          {:ok, expanded}

        global ->
          if expanded == global or String.starts_with?(expanded, global <> "/"),
            do: {:ok, expanded},
            else: {:error, :worktree_root_outside_global}
      end
    else
      {:error, :worktree_root_not_absolute}
    end
  end

  defp validate_worktree_root(_other), do: {:error, :bad_worktree_root}

  defp global_worktree_root do
    case Application.get_env(:xaas, :ultracode_worktree_root) do
      root when is_binary(root) and root != "" -> Path.expand(root)
      _ -> nil
    end
  end

  defp validate_all(additions) do
    Enum.find_value(additions, :ok, fn {alias, raw} ->
      case validate(alias, raw) do
        {:ok, _} -> nil
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  defp drop_nils(raw) when is_map(raw),
    do: Map.reject(raw, fn {_k, v} -> is_nil(v) end)

  defp drop_nils(other), do: other

  defp name?(value) when is_binary(value), do: Regex.match?(@name_format, value)
  defp name?(_), do: false

  defp check(true, _reason), do: :ok
  defp check(false, reason), do: {:error, reason}
end
