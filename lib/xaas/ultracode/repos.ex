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
        refresh: false,                   # fetch + fast-forward the clone before sensing
        suite_registered: true            # named in :ultracode_verifier_suites?
      }

  ## Sources

    * `config :xaas, :ultracode_repos` -- the code-seeded baseline map. Two
      raw forms per alias: a bare path STRING (the legacy form; carries the
      historical APS defaults -- sensing "aps", suite "aps-dod",
      canonical_suite "aps-canonical" -- so `%{"aps" => path}` behaves exactly
      as before this registry) or a MAP with `path` plus optional `sensing`,
      `suite`, `canonical_suite`, `worktree_root`, `refresh` (string or atom
      keys).
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
  metadata for the target: `Xaas.Ultracode.Sensing.profile_for/1` resolves it
  to a declared profile (`config :xaas, :ultracode_sensing_profiles`) and
  `Autonomic.sense/1` senses through that profile when one exists, else
  through the per-repo backlog script -- this module never judges or
  resolves it.

  ## Refresh law (a stale clone never senses silently)

  A clone created with `git clone --local <source>` (the way the operator
  targets `xaas`, `autofde-lab`, `gymact` and `ggen-igniter` are provisioned)
  goes stale the moment its source moves. `refresh/1` is the machine step that
  fixes that without a human: `git fetch <remote>` for the clone's upstream,
  then `git merge --ff-only` of the upstream ref into the clone's checked-out
  branch. It is deliberately non-destructive -- a clone that is ahead of, or
  has diverged from, its upstream is left untouched and reported as a typed
  result/refusal, and the per-alias integration branch (where court-approved
  work lands) is never involved. An entry opts in with `refresh: true`;
  `Xaas.Ultracode.Autonomic` then refreshes it before it pins `base_sha`, and
  `mix xaas.ultracode.repos --refresh ALIAS` runs the same step by hand.

  This module never starts the application, never touches a database, and
  never runs a suite. It reads config, the filesystem, and git -- and
  `refresh/1` additionally fetches from the clone's own configured remote
  (a local path for `git clone --local` clones; no other network is opened).
  """

  alias Xaas.Ultracode.Verifier

  @name_format ~r/^[a-z][a-z0-9_-]{0,31}$/

  # The legacy path-string form carries exactly the pre-registry behavior:
  # an APS-shaped target. Structured entries name their own facts.
  @legacy_defaults %{
    sensing: "aps",
    suite: "aps-dod",
    canonical_suite: "aps-canonical",
    worktree_root: nil,
    refresh: false
  }

  @typedoc "A validated registry entry."
  @type entry :: %{
          required(:alias) => String.t(),
          required(:path) => String.t(),
          required(:sensing) => String.t(),
          required(:suite) => String.t(),
          required(:canonical_suite) => String.t() | nil,
          required(:worktree_root) => String.t() | nil,
          required(:refresh) => boolean(),
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
         :ok <- check(is_boolean(fields.refresh), {:bad_refresh, fields.refresh}),
         {:ok, worktree_root} <- validate_worktree_root(fields.worktree_root) do
      {:ok,
       %{
         alias: alias,
         path: path,
         sensing: fields.sensing,
         suite: fields.suite,
         canonical_suite: fields.canonical_suite,
         worktree_root: worktree_root,
         refresh: fields.refresh,
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

  @typedoc """
  What `refresh/1` did to the clone: `:advanced` (fast-forwarded to the
  upstream head), `:current` (already at it) or `:ahead` (the clone holds
  commits its upstream lacks -- left untouched). `from`/`head` are the clone's
  HEAD before and after; `upstream` is the tracked ref (`origin/main`).
  """
  @type refresh_result :: %{
          status: :advanced | :current | :ahead,
          branch: String.t(),
          upstream: String.t(),
          from: String.t(),
          head: String.t()
        }

  @doc """
  Brings a registered clone up to its upstream so the loop never senses (and
  never pins `base_sha` at) a stale tree: fetches the tracked remote, then
  fast-forwards the checked-out branch to the upstream ref.

  Non-destructive by construction: only `git fetch` and `git merge --ff-only`
  are ever run, so a clone ahead of its upstream is reported `:ahead` and left
  alone, and a diverged clone is a typed refusal
  (`{:refresh_diverged, from, upstream_head}`) -- never a reset, never a
  rebase. Other typed refusals: `{:unknown_repo_alias, _}` /
  `{:invalid_repo_entry, _, _}` (registry law), `:refresh_detached_head`,
  `:refresh_no_upstream`, `{:refresh_fetch_failed, code, output}`,
  `{:refresh_ff_failed, code, output}`.
  """
  @spec refresh(term()) :: {:ok, refresh_result()} | {:error, term()}
  def refresh(repo_alias) do
    with {:ok, entry} <- resolve(repo_alias) do
      refresh_clone(entry.path)
    end
  end

  defp refresh_clone(path) do
    with {:ok, branch} <- current_branch(path),
         {:ok, upstream} <- upstream_of(path, branch),
         :ok <- fetch_remote(path, upstream),
         {:ok, from} <- rev(path, "HEAD"),
         {:ok, target} <- rev(path, upstream) do
      cond do
        from == target ->
          {:ok, refresh_result(:current, branch, upstream, from, from)}

        ancestor?(path, target, from) ->
          {:ok, refresh_result(:ahead, branch, upstream, from, from)}

        ancestor?(path, from, target) ->
          case System.cmd("git", ["-C", path, "merge", "--ff-only", "--quiet", upstream],
                 stderr_to_stdout: true
               ) do
            {_, 0} ->
              with {:ok, head} <- rev(path, "HEAD") do
                {:ok, refresh_result(:advanced, branch, upstream, from, head)}
              end

            {out, code} ->
              {:error, {:refresh_ff_failed, code, String.trim(out)}}
          end

        true ->
          {:error, {:refresh_diverged, from, target}}
      end
    end
  end

  defp refresh_result(status, branch, upstream, from, head),
    do: %{status: status, branch: branch, upstream: upstream, from: from, head: head}

  defp current_branch(path) do
    case System.cmd("git", ["-C", path, "symbolic-ref", "--quiet", "--short", "HEAD"],
           stderr_to_stdout: true
         ) do
      {out, 0} -> {:ok, String.trim(out)}
      {_, _} -> {:error, :refresh_detached_head}
    end
  end

  defp upstream_of(path, branch) do
    case System.cmd(
           "git",
           [
             "-C",
             path,
             "rev-parse",
             "--abbrev-ref",
             "--symbolic-full-name",
             branch <> "@{upstream}"
           ],
           stderr_to_stdout: true
         ) do
      {out, 0} -> {:ok, String.trim(out)}
      {_, _} -> {:error, :refresh_no_upstream}
    end
  end

  # `upstream` is "<remote>/<branch>"; fetch exactly that remote (its
  # configured refspec updates refs/remotes/<remote>/*, never a local branch).
  defp fetch_remote(path, upstream) do
    [remote | _] = String.split(upstream, "/", parts: 2)

    case System.cmd("git", ["-C", path, "fetch", "--quiet", remote], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {out, code} -> {:error, {:refresh_fetch_failed, code, String.trim(out)}}
    end
  end

  defp rev(path, ref) do
    case System.cmd("git", ["-C", path, "rev-parse", "--verify", "--quiet", ref <> "^{commit}"],
           stderr_to_stdout: true
         ) do
      {out, 0} -> {:ok, String.trim(out)}
      {_, _} -> {:error, {:refresh_unresolvable_ref, ref}}
    end
  end

  defp ancestor?(path, maybe_ancestor, descendant) do
    match?(
      {_, 0},
      System.cmd("git", ["-C", path, "merge-base", "--is-ancestor", maybe_ancestor, descendant],
        stderr_to_stdout: true
      )
    )
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
      worktree_root: lookup(raw, :worktree_root),
      refresh: refresh_of(raw)
    }
  end

  defp normalize_raw(other),
    do: %{
      path: other,
      sensing: nil,
      suite: nil,
      canonical_suite: nil,
      worktree_root: nil,
      refresh: false
    }

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

  # Absent key = no refresh. A present-but-non-boolean value is passed
  # through so `validate/2` refuses it as `{:bad_refresh, value}` instead of
  # silently coercing operator intent.
  defp refresh_of(raw) do
    case lookup(raw, :refresh) do
      nil -> false
      value -> value
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
