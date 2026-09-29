defmodule Xaas.Test.DodFixture do
  @moduledoc """
  Real git repositories in real temp dirs for the DoD-trust qualification tests
  (`Xaas.Ultracode.Probes`, the verifier's falsifier probes, the suite health
  court, order probes). Nothing here fakes a collaborator: every helper shells
  out to the real `git` and every returned path is a real directory on disk.
  """

  import ExUnit.Callbacks, only: [on_exit: 1]

  @git_env [
    {"GIT_AUTHOR_NAME", "t"},
    {"GIT_AUTHOR_EMAIL", "t@t"},
    {"GIT_COMMITTER_NAME", "t"},
    {"GIT_COMMITTER_EMAIL", "t@t"}
  ]

  @doc "A fresh canonical (symlink-resolved) temp dir, removed on test exit."
  @spec tmp(String.t()) :: String.t()
  def tmp(label) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "xaas-dodtrust-#{label}-#{System.system_time(:millisecond)}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    canonical(dir)
  end

  @spec canonical(String.t()) :: String.t()
  def canonical(path) do
    {out, 0} = System.cmd("sh", ["-c", ~s(cd "$1" && pwd -P), "sh", path])
    String.trim(out)
  end

  @doc "Creates a repo under `parent` with `files` (`%{relpath => content}`) committed; returns `{dir, head}`."
  @spec repo(String.t(), map(), String.t()) :: {String.t(), String.t()}
  def repo(parent, files, name \\ "repo") do
    dir = Path.join(parent, "#{name}-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    git!(dir, ["init", "--quiet", "-b", "main"])
    {dir, commit(dir, files, "init")}
  end

  @doc "Writes `files` (a nil content deletes), commits everything, returns the new head."
  @spec commit(String.t(), map(), String.t()) :: String.t()
  def commit(dir, files, message) do
    for {rel, content} <- files do
      path = Path.join(dir, rel)

      if is_nil(content) do
        File.rm!(path)
      else
        File.mkdir_p!(Path.dirname(path))
        File.write!(path, content)
      end
    end

    git!(dir, ["add", "-A"])
    git!(dir, ["commit", "--quiet", "--allow-empty", "-m", message])
    head(dir)
  end

  @doc "A detached linked worktree of `repo` at `sha` (what `Worktrees.provision/3` produces)."
  @spec linked_worktree(String.t(), String.t(), String.t()) :: String.t()
  def linked_worktree(repo, parent, sha) do
    path = Path.join(parent, "wt-#{System.unique_integer([:positive])}")
    git!(repo, ["worktree", "add", "--quiet", "--detach", path, sha])
    canonical(path)
  end

  @spec head(String.t()) :: String.t()
  def head(dir), do: dir |> git!(["rev-parse", "HEAD"]) |> String.trim()

  @spec status(String.t()) :: String.t()
  def status(dir), do: git!(dir, ["status", "--porcelain"])

  @spec tag(String.t(), String.t(), String.t()) :: :ok
  def tag(dir, name, sha) do
    git!(dir, ["tag", name, sha])
    :ok
  end

  @spec git!(String.t(), [String.t()]) :: String.t()
  def git!(dir, args) do
    {out, 0} = System.cmd("git", ["-C", dir | args], stderr_to_stdout: true, env: @git_env)
    out
  end

  @doc "Names of `xaas-verifier-<epoch>-*` temp dirs still on disk (leak check)."
  @spec leftover_tmp(String.t()) :: [String.t()]
  def leftover_tmp(epoch_id) do
    System.tmp_dir!()
    |> File.ls!()
    |> Enum.filter(&String.starts_with?(&1, "xaas-verifier-#{epoch_id}"))
  end
end
