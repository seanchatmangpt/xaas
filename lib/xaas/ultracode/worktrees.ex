defmodule Xaas.Ultracode.Worktrees do
  @moduledoc """
  Operator-side provisioning of the isolated git worktree an Epoch runs in.

  Nothing in the fabric created worktrees before this module: every
  production epoch had `worktree = nil` (see
  `docs/jira/v26.9.17/op-epoch-worktree-design-cut.md`), so head verification
  and the fabric verifier had nothing to verify. This is the missing step, and
  it is deliberately NOT reachable from the customer HTTP surface.

  ## The generalized repo contract

  A repository is named by an **operator alias** registered in
  `config :xaas, :ultracode_repos`; a caller never supplies a path or a URL.
  Provisioning works for ANY registered repo whose LOCAL CLONE exists at the
  registry path — the APS clone is just the first entry, not a special case.

  A registry entry is one of:

      "aps" => "/path/to/clone"

      "zoela" => %{
        "path" => "/path/to/clone",              # required: the local clone
        "worktree_root" => "/path/to/runs",      # optional: per-repo root
        "integration_branch" => "main",          # optional: local merge target
        "toolchain_env" => %{"PATH" => "..."}    # optional: worker env pin
      }

  (Atom keys are accepted wherever string keys are.) Entries that are plain
  path strings behave exactly as they did before generalization.

  Semantics shared by every entry:

    * `base_sha` must be a full 40-hex commit id that exists in that repo.
    * The worktree name is a strict slug; the target path is
      `<root>/<name>` (root = the entry's `worktree_root`, else the global
      `:ultracode_worktree_root`) and can never leave the root. An existing
      path is refused (no silent reuse of someone else's tree).
    * A missing clone is a typed refusal (`:repo_clone_missing`); this
      module NEVER auto-clones from the network. A path that exists but is
      not a git checkout is `:repo_is_not_a_git_checkout`.
    * Worktrees are detached at `base_sha`; the source clone's branches and
      working tree are never touched.
    * `epoch_worktree_name/2` derives collision-free names per repo+subject,
      so two repos sharing the global root can never collide on one path.

  ## The canonical integration branch

  Each repo has ONE local integration branch — the target of the local
  `--no-ff` merges that promote court-approved epoch heads. It is the
  entry's `integration_branch`, defaulting to
  `ultracode/integration-<alias-slug>`. `merge_to_integration/3` performs
  the merge through a short-lived management worktree under the root and
  removes that worktree before returning, so the operator clone's
  checked-out branch and working tree are never touched. The integration
  branch itself persists in the clone. Nothing is ever pushed.

  ## Worker environment contract

  The epoch worker runs INSIDE the provisioned worktree (Dispatch sets the
  cwd). It inherits the node's environment plus `XAAS_WORKER`,
  `XAAS_LEASE_CWD`, the entry's `toolchain_env` assignments (passed through
  verbatim — values are literal strings, no shell expansion, so a `PATH`
  pin must be spelled out in full, e.g. asdf shims first for an Elixir
  repo), and the caller's `:extra_env` last (extra wins on duplicates).

  `cleanup/2` removes a provisioned worktree (git-aware) and refuses any path
  that is not directly under the repo's root.
  """

  @sha ~r/^[0-9a-f]{40}$/
  @name ~r/^[a-z0-9][a-z0-9_-]{0,63}$/
  @default_integration_prefix "ultracode/integration-"

  # Deterministic identity for the merge commits this module manufactures —
  # never the operator's ambient git config, never the worker's.
  @git_env [
    {"GIT_AUTHOR_NAME", "xaas-ultracode"},
    {"GIT_AUTHOR_EMAIL", "ultracode@xaas.local"},
    {"GIT_COMMITTER_NAME", "xaas-ultracode"},
    {"GIT_COMMITTER_EMAIL", "ultracode@xaas.local"}
  ]

  @type entry :: %{
          required(:path) => String.t(),
          required(:worktree_root) => String.t() | nil,
          required(:integration_branch) => String.t(),
          required(:toolchain_env) => [{String.t(), String.t()}]
        }

  @spec provision(String.t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def provision(repo_alias, base_sha, name)
      when is_binary(repo_alias) and is_binary(base_sha) and is_binary(name) do
    with {:ok, repo} <- repo_path(repo_alias),
         {:ok, root} <- worktree_root(repo_alias),
         :ok <- check(String.match?(base_sha, @sha), :bad_base_sha),
         :ok <- check(String.match?(name, @name), :bad_worktree_name),
         :ok <- commit_exists(repo, base_sha),
         path = Path.join(root, name),
         :ok <- check(not File.exists?(path), :worktree_exists),
         :ok <- File.mkdir_p(root),
         {_, 0} <- git(repo, ["worktree", "add", "--detach", path, base_sha]) do
      {:ok, path}
    else
      {output, code} when is_binary(output) and is_integer(code) ->
        {:error, {:git_worktree_add_failed, code, String.trim(output)}}

      {:error, _} = error ->
        error
    end
  end

  @spec cleanup(String.t(), String.t()) :: :ok | {:error, term()}
  def cleanup(repo_alias, path) when is_binary(repo_alias) and is_binary(path) do
    with {:ok, repo} <- repo_path(repo_alias),
         {:ok, root} <- worktree_root(repo_alias),
         :ok <- check(Path.dirname(path) == root and Path.basename(path) =~ @name, :outside_root) do
      _ = git(repo, ["worktree", "remove", "--force", path])
      File.rm_rf(path)
      _ = git(repo, ["worktree", "prune"])
      :ok
    end
  end

  @doc """
  Normalizes the registry entry for `repo_alias`, typed and fail-closed.

  Accepts the plain path string (the historical shape) and the map shape
  (`path` plus optional `worktree_root`, `integration_branch`,
  `toolchain_env`; string or atom keys). Returns the fully defaulted entry
  or a typed refusal (`:unknown_repo_alias`, `:invalid_repo_entry`,
  `:repo_clone_missing`, `:repo_is_not_a_git_checkout`).
  """
  @spec registry_entry(String.t()) :: {:ok, entry()} | {:error, term()}
  def registry_entry(repo_alias) when is_binary(repo_alias) do
    with {:ok, raw} <- fetch_raw_entry(repo_alias),
         {:ok, normalized} <- normalize_entry(repo_alias, raw),
         :ok <- check_checkout(normalized.path) do
      {:ok, normalized}
    end
  end

  def registry_entry(_), do: {:error, :unknown_repo_alias}

  @doc """
  The worktree containment root for `repo_alias`: the entry's
  `worktree_root` when set, else the global `:ultracode_worktree_root`.
  """
  @spec worktree_root(String.t()) :: {:ok, String.t()} | {:error, :worktree_root_unconfigured}
  def worktree_root(repo_alias) when is_binary(repo_alias) do
    with {:ok, entry} <- registry_entry(repo_alias) do
      case entry.worktree_root || Application.get_env(:xaas, :ultracode_worktree_root) do
        root when is_binary(root) and root != "" -> {:ok, root}
        _ -> {:error, :worktree_root_unconfigured}
      end
    end
  end

  @doc """
  A filesystem-safe slug for a repo alias: lowercased, every character
  outside `[a-z0-9_-]` replaced with `-`, capped at 24 characters.
  """
  @spec slug(String.t()) :: String.t()
  def slug(repo_alias) when is_binary(repo_alias) do
    repo_alias
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_-]/, "-")
    |> String.slice(0, 24)
  end

  @doc """
  Collision-free worktree name for one epoch of one repo: the repo slug plus
  the sha256 of `repo_alias <> "|" <> subject`. Two repos sharing the global
  root can never derive the same name from the same work order, and two work
  orders of one repo can never collide either.
  """
  @spec epoch_worktree_name(String.t(), String.t()) :: String.t()
  def epoch_worktree_name(repo_alias, subject)
      when is_binary(repo_alias) and is_binary(subject) do
    suffix =
      :crypto.hash(:sha256, repo_alias <> "|" <> subject)
      |> Base.encode16(case: :lower)
      |> String.slice(0, 20)

    slug(repo_alias) <> "-" <> suffix
  end

  @doc """
  The canonical per-repo integration branch: the entry's `integration_branch`
  when set, else `ultracode/integration-<slug>`.
  """
  @spec integration_branch(String.t()) :: {:ok, String.t()} | {:error, term()}
  def integration_branch(repo_alias) when is_binary(repo_alias) do
    with {:ok, entry} <- registry_entry(repo_alias) do
      {:ok, entry.integration_branch}
    end
  end

  @doc """
  Merges one court-approved candidate head into the repo's canonical
  integration branch — the local `--no-ff` merge target. Nothing is pushed.

  The merge runs in a short-lived management worktree created under the
  repo's worktree root and removed before returning, so the operator clone's
  checked-out branch and working tree are never touched. The integration
  branch is created in the clone (at the clone's HEAD) the first time this is
  called and persists across epochs.

  Options:

    * `:message` — the merge commit message
      (default `"ultracode: integrate <short-head>"`)

  Returns `{:ok, %{branch: branch, head: new_integration_head}}` or a typed
  error (`:bad_candidate_head`, `:base_sha_not_in_repo`,
  `{:integration_merge_conflict, output}`, `{:integration_merge_failed, code,
  output}`, `{:git_worktree_add_failed, code, output}`).
  """
  @spec merge_to_integration(String.t(), String.t(), keyword()) ::
          {:ok, %{branch: String.t(), head: String.t()}} | {:error, term()}
  def merge_to_integration(repo_alias, candidate_head, opts \\ [])
      when is_binary(repo_alias) and is_binary(candidate_head) and is_list(opts) do
    with {:ok, repo} <- repo_path(repo_alias),
         {:ok, root} <- worktree_root(repo_alias),
         :ok <- check(String.match?(candidate_head, @sha), :bad_candidate_head),
         :ok <- commit_exists(repo, candidate_head),
         {:ok, branch} <- integration_branch(repo_alias) do
      path = Path.join(root, "#{slug(repo_alias)}-integration-#{nonce()}")
      :ok = File.mkdir_p(root)

      with :ok <- add_integration_worktree(repo, path, branch),
           {:ok, head} <- merge_in(path, candidate_head, opts) do
        _ = cleanup(repo_alias, path)
        {:ok, %{branch: branch, head: head}}
      else
        {:error, _} = error ->
          abort_merge(path)
          _ = cleanup(repo_alias, path)
          error
      end
    end
  end

  # ------------------------------------------------------------------
  # Registry normalization
  # ------------------------------------------------------------------

  defp fetch_raw_entry(repo_alias) do
    case :xaas |> Application.get_env(:ultracode_repos, %{}) |> Map.fetch(repo_alias) do
      {:ok, raw} -> {:ok, raw}
      :error -> {:error, :unknown_repo_alias}
    end
  end

  defp normalize_entry(repo_alias, raw) when is_binary(raw) do
    {:ok, entry(repo_alias, raw, nil)}
  end

  defp normalize_entry(repo_alias, raw) when is_map(raw) and not is_struct(raw) do
    path = fetch_key(raw, ["path", :path])

    if is_binary(path) and path != "" and valid_optional?(raw, "worktree_root") and
         valid_optional?(raw, "integration_branch") do
      env = fetch_key(raw, ["toolchain_env", :toolchain_env])

      case normalize_toolchain_env(env) do
        {:ok, env} ->
          root = fetch_key(raw, ["worktree_root", :worktree_root])
          branch = fetch_key(raw, ["integration_branch", :integration_branch])

          base = entry(repo_alias, path, root)
          base = %{base | integration_branch: branch || base.integration_branch}
          {:ok, %{base | toolchain_env: env}}

        {:error, _} = error ->
          error
      end
    else
      {:error, :invalid_repo_entry}
    end
  end

  defp normalize_entry(_, _), do: {:error, :invalid_repo_entry}

  defp entry(repo_alias, path, root) do
    %{
      path: path,
      worktree_root: root,
      integration_branch: @default_integration_prefix <> slug(repo_alias),
      toolchain_env: []
    }
  end

  defp valid_optional?(map, key) do
    case Map.fetch(map, key) do
      {:ok, value} -> is_binary(value) and value != ""
      :error -> true
    end
  end

  defp normalize_toolchain_env(nil), do: {:ok, []}

  defp normalize_toolchain_env(%{} = env) do
    if Enum.all?(env, fn {k, v} -> (is_binary(k) or is_atom(k)) and is_binary(v) end),
      do: {:ok, Enum.map(env, fn {k, v} -> {to_string(k), v} end)},
      else: {:error, :invalid_repo_entry}
  end

  defp normalize_toolchain_env(env) when is_list(env) do
    if Enum.all?(env, fn pair -> match?({k, v} when is_binary(k) and is_binary(v), pair) end),
      do: {:ok, env},
      else: {:error, :invalid_repo_entry}
  end

  defp normalize_toolchain_env(_), do: {:error, :invalid_repo_entry}

  defp fetch_key(map, keys) do
    Enum.find_value(keys, fn key ->
      case Map.fetch(map, key) do
        {:ok, value} -> value
        :error -> nil
      end
    end)
  end

  # ------------------------------------------------------------------
  # Integration merge internals
  # ------------------------------------------------------------------

  defp add_integration_worktree(repo, path, branch) do
    branch_exists? =
      match?({_, 0}, git(repo, ["rev-parse", "--verify", "--quiet", "refs/heads/" <> branch]))

    args =
      if branch_exists? do
        ["worktree", "add", path, branch]
      else
        ["worktree", "add", "-b", branch, path]
      end

    case git(repo, args) do
      {_, 0} -> :ok
      {out, code} -> {:error, {:git_worktree_add_failed, code, String.trim(out)}}
    end
  end

  defp merge_in(path, candidate_head, opts) do
    message =
      Keyword.get(opts, :message, "ultracode: integrate #{String.slice(candidate_head, 0, 12)}")

    case System.cmd("git", ["-C", path, "merge", "--no-ff", "-m", message, candidate_head],
           stderr_to_stdout: true,
           env: @git_env
         ) do
      {_, 0} ->
        {out, 0} = git(path, ["rev-parse", "HEAD"])
        {:ok, String.trim(out)}

      {out, code} ->
        trimmed = String.slice(String.trim(out), -500, 500)

        if String.contains?(out, "CONFLICT") do
          {:error, {:integration_merge_conflict, trimmed}}
        else
          {:error, {:integration_merge_failed, code, trimmed}}
        end
    end
  end

  defp abort_merge(path) do
    if File.dir?(path), do: _ = git(path, ["merge", "--abort"])
  end

  defp nonce, do: :crypto.strong_rand_bytes(6) |> Base.encode16(case: :lower)

  # ------------------------------------------------------------------
  # Shared git plumbing
  # ------------------------------------------------------------------

  defp repo_path(repo_alias) do
    with {:ok, entry} <- registry_entry(repo_alias) do
      {:ok, entry.path}
    end
  end

  defp check_checkout(path) do
    cond do
      not File.exists?(path) ->
        {:error, :repo_clone_missing}

      File.dir?(Path.join(path, ".git")) or File.regular?(Path.join(path, ".git")) ->
        :ok

      true ->
        {:error, :repo_is_not_a_git_checkout}
    end
  end

  defp commit_exists(repo, sha) do
    case git(repo, ["cat-file", "-e", sha <> "^{commit}"]) do
      {_, 0} -> :ok
      {_, _} -> {:error, :base_sha_not_in_repo}
    end
  end

  defp check(true, _reason), do: :ok
  defp check(false, reason), do: {:error, reason}

  defp git(repo, args), do: System.cmd("git", ["-C", repo | args], stderr_to_stdout: true)
end
