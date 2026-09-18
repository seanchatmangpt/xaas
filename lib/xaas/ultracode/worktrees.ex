defmodule Xaas.Ultracode.Worktrees do
  @moduledoc """
  Operator-side provisioning of the isolated git worktree an Epoch runs in.

  Nothing in the fabric created worktrees before this module: every
  production epoch had `worktree = nil` (see
  `docs/jira/v26.9.17/op-epoch-worktree-design-cut.md`), so head verification
  and the fabric verifier had nothing to verify. This is the missing step, and
  it is deliberately NOT reachable from the customer HTTP surface.

    * A repository is named by an **operator alias** in
      `config :xaas, :ultracode_repos` (`%{"aps" => "/path/to/clone"}`); a
      caller never supplies a path or a URL.
    * `base_sha` must be a full 40-hex commit id that exists in that repo.
    * The worktree name is a strict slug; the target path is
      `<:ultracode_worktree_root>/<name>` and can never leave the root. An
      existing path is refused (no silent reuse of someone else's tree).
    * Worktrees are detached at `base_sha`; the source clone's branches and
      working tree are never touched.

  `cleanup/1` removes a provisioned worktree (git-aware) and refuses any path
  that is not directly under the root.
  """

  @sha ~r/^[0-9a-f]{40}$/
  @name ~r/^[a-z0-9][a-z0-9_-]{0,63}$/

  @spec provision(String.t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def provision(repo_alias, base_sha, name)
      when is_binary(repo_alias) and is_binary(base_sha) and is_binary(name) do
    with {:ok, repo} <- repo_path(repo_alias),
         {:ok, root} <- root(),
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
         {:ok, root} <- root(),
         :ok <- check(Path.dirname(path) == root and Path.basename(path) =~ @name, :outside_root) do
      _ = git(repo, ["worktree", "remove", "--force", path])
      File.rm_rf(path)
      _ = git(repo, ["worktree", "prune"])
      :ok
    end
  end

  defp repo_path(repo_alias) do
    case :xaas |> Application.get_env(:ultracode_repos, %{}) |> Map.fetch(repo_alias) do
      {:ok, path} when is_binary(path) ->
        if File.dir?(Path.join(path, ".git")) or File.regular?(Path.join(path, ".git")),
          do: {:ok, path},
          else: {:error, :repo_is_not_a_git_checkout}

      _ ->
        {:error, :unknown_repo_alias}
    end
  end

  defp root do
    case Application.get_env(:xaas, :ultracode_worktree_root) do
      root when is_binary(root) and root != "" -> {:ok, root}
      _ -> {:error, :worktree_root_unconfigured}
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
