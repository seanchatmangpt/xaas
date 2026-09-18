defmodule Xaas.Ultracode.WorktreesTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Chicago-style qualification of operator-side worktree provisioning: real git
  repositories, real `git worktree add`, real directory state. Nothing mocked.
  """

  alias Xaas.Ultracode.Worktrees

  setup do
    original = %{
      repos: Application.get_env(:xaas, :ultracode_repos),
      root: Application.get_env(:xaas, :ultracode_worktree_root)
    }

    base = mktmp("base")
    repo = Path.join(base, "repo")
    root = Path.join(base, "runs")
    File.mkdir_p!(repo)
    sha = init_repo(repo)

    Application.put_env(:xaas, :ultracode_repos, %{"demo" => repo})
    Application.put_env(:xaas, :ultracode_worktree_root, root)

    on_exit(fn ->
      Application.put_env(:xaas, :ultracode_repos, original.repos)
      Application.put_env(:xaas, :ultracode_worktree_root, original.root)
    end)

    %{repo: repo, root: root, sha: sha}
  end

  test "provisions a detached worktree at base_sha under the root", %{
    repo: repo,
    root: root,
    sha: sha
  } do
    assert {:ok, path} = Worktrees.provision("demo", sha, "run-1")

    assert path == Path.join(root, "run-1")
    assert File.read!(Path.join(path, "hello.txt")) == "hello\n"
    assert git!(path, ["rev-parse", "HEAD"]) == sha
    assert git!(path, ["rev-parse", "--abbrev-ref", "HEAD"]) == "HEAD"
    assert git!(repo, ["worktree", "list"]) =~ path
    assert git!(repo, ["status", "--porcelain"]) == ""
  end

  test "an existing path is refused, never silently reused", %{sha: sha} do
    assert {:ok, _} = Worktrees.provision("demo", sha, "run-1")
    assert {:error, :worktree_exists} = Worktrees.provision("demo", sha, "run-1")
  end

  test "callers cannot name paths, traversal, or malformed shas", %{sha: sha, root: root} do
    for bad <- ["../escape", "a/b", "/abs", "Run 1", "", ".hidden", String.duplicate("a", 65)] do
      assert {:error, :bad_worktree_name} = Worktrees.provision("demo", sha, bad),
             "name #{inspect(bad)}"
    end

    for bad <- ["HEAD", "main", "abc", String.upcase(sha), sha <> "0"] do
      assert {:error, :bad_base_sha} = Worktrees.provision("demo", bad, "run-x"),
             "sha #{inspect(bad)}"
    end

    assert {:error, :base_sha_not_in_repo} =
             Worktrees.provision("demo", String.duplicate("a", 40), "run-x")

    refute File.exists?(Path.join(root, "run-x"))
  end

  test "an unregistered alias, a non-git alias target, and an unset root all fail closed", %{
    repo: repo,
    sha: sha
  } do
    assert {:error, :unknown_repo_alias} = Worktrees.provision("nope", sha, "run-1")

    plain = mktmp("plain")
    Application.put_env(:xaas, :ultracode_repos, %{"plain" => plain})
    assert {:error, :repo_is_not_a_git_checkout} = Worktrees.provision("plain", sha, "run-1")

    Application.put_env(:xaas, :ultracode_repos, %{"demo" => repo})
    Application.put_env(:xaas, :ultracode_worktree_root, nil)
    assert {:error, :worktree_root_unconfigured} = Worktrees.provision("demo", sha, "run-1")
  end

  test "cleanup removes the worktree and git forgets it; foreign paths are refused",
       %{repo: repo, sha: sha} do
    assert {:ok, path} = Worktrees.provision("demo", sha, "run-1")
    assert :ok = Worktrees.cleanup("demo", path)

    refute File.exists?(path)
    refute git!(repo, ["worktree", "list"]) =~ path

    assert {:error, :outside_root} = Worktrees.cleanup("demo", repo)
    assert {:error, :outside_root} = Worktrees.cleanup("demo", "/tmp")
    assert File.dir?(repo)
  end

  # ------------------------------------------------------------------

  defp mktmp(label) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "xaas-worktrees-test-#{label}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end

  defp init_repo(repo) do
    env = [
      {"GIT_AUTHOR_NAME", "t"},
      {"GIT_AUTHOR_EMAIL", "t@t"},
      {"GIT_COMMITTER_NAME", "t"},
      {"GIT_COMMITTER_EMAIL", "t@t"}
    ]

    {_, 0} =
      System.cmd("git", ["-C", repo, "init", "--quiet", "-b", "main"], stderr_to_stdout: true)

    File.write!(Path.join(repo, "hello.txt"), "hello\n")
    {_, 0} = System.cmd("git", ["-C", repo, "add", "hello.txt"], stderr_to_stdout: true)

    {_, 0} =
      System.cmd("git", ["-C", repo, "commit", "-m", "init", "--quiet"],
        stderr_to_stdout: true,
        env: env
      )

    git!(repo, ["rev-parse", "HEAD"])
  end

  defp git!(dir, args) do
    {out, 0} = System.cmd("git", ["-C", dir | args], stderr_to_stdout: true)
    String.trim(out)
  end
end
