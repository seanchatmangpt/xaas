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
  # Generalized multi-repo contract (W5-A5): any registered alias with a
  # local clone provisions exactly like the historical single-repo path.
  # ------------------------------------------------------------------

  test "provisions a second registered repo via a map-shaped entry with per-repo root", %{
    repo: repo,
    sha: sha,
    root: root
  } do
    {other_repo, other_root, other_sha} = second_repo("other")

    Application.put_env(:xaas, :ultracode_repos, %{
      "demo" => %{"path" => repo, "toolchain_env" => %{"PATH" => "/pinned/bin:/usr/bin:/bin"}},
      "other" => %{
        "path" => other_repo,
        "worktree_root" => other_root,
        "integration_branch" => "trunk"
      }
    })

    assert {:ok, p1} = Worktrees.provision("demo", sha, "run-1")
    assert {:ok, p2} = Worktrees.provision("other", other_sha, "run-1")

    # demo (map shape, no root) uses the global root; other uses its own.
    assert Path.dirname(p1) == root
    assert Path.dirname(p2) == other_root
    assert git!(p2, ["rev-parse", "HEAD"]) == other_sha

    # Per-repo integration branch override and the slug default.
    assert {:ok, "trunk"} = Worktrees.integration_branch("other")
    assert {:ok, "ultracode/integration-demo"} = Worktrees.integration_branch("demo")

    # The pinned toolchain env rides in the normalized entry.
    assert {:ok, entry} = Worktrees.registry_entry("demo")
    assert {"PATH", "/pinned/bin:/usr/bin:/bin"} in entry.toolchain_env
    assert {:ok, other} = Worktrees.registry_entry("other")
    assert other.toolchain_env == []

    for {alias, p} <- [{"demo", p1}, {"other", p2}] do
      assert :ok = Worktrees.cleanup(alias, p)
    end
  end

  test "a registered alias whose local clone is missing is a typed refusal, never an auto-clone",
       %{
         sha: sha
       } do
    ghost = Path.join(mktmp("ghost"), "not-there")
    Application.put_env(:xaas, :ultracode_repos, %{"ghost" => ghost})

    assert {:error, :repo_clone_missing} = Worktrees.registry_entry("ghost")
    assert {:error, :repo_clone_missing} = Worktrees.provision("ghost", sha, "run-1")
    refute File.exists?(ghost)
  end

  test "malformed map entries fail closed as :invalid_repo_entry" do
    Application.put_env(:xaas, :ultracode_repos, %{
      "notmap" => 123,
      "nopath" => %{},
      "emptyroot" => %{"path" => "/tmp", "worktree_root" => ""},
      "badenv" => %{"path" => "/tmp", "toolchain_env" => 42}
    })

    for alias <- ["notmap", "nopath", "emptyroot", "badenv"] do
      assert {:error, :invalid_repo_entry} = Worktrees.registry_entry(alias), "alias #{alias}"
    end
  end

  test "epoch names are deterministic and collision-free per repo+subject; concurrent provision of two epochs lands both",
       %{
         repo: repo,
         sha: sha
       } do
    {other_repo, _other_root, _other_sha} = second_repo("other")
    Application.put_env(:xaas, :ultracode_repos, %{"demo" => repo, "other" => other_repo})

    # Deterministic; distinct across subjects of one repo and across repos
    # sharing the same subject (same global root, no path collision).
    n1 = Worktrees.epoch_worktree_name("demo", "wo-1")
    assert n1 == Worktrees.epoch_worktree_name("demo", "wo-1")
    assert Regex.match?(~r/^demo-[0-9a-f]{20}$/, n1)
    assert Worktrees.epoch_worktree_name("demo", "wo-2") != n1
    assert Worktrees.epoch_worktree_name("other", "wo-1") != n1

    # Two epochs of the SAME repo, provisioned concurrently, both land.
    tasks =
      Enum.map(1..2, fn i ->
        Task.async(fn -> Worktrees.provision("demo", sha, "epoch-#{i}") end)
      end)

    results = Enum.map(tasks, &Task.await(&1, 30_000))
    assert Enum.all?(results, &match?({:ok, _}, &1))
    assert Enum.uniq(Enum.map(results, &elem(&1, 1))) |> length() == 2

    for {:ok, p} <- results, do: assert(:ok = Worktrees.cleanup("demo", p))
    refute git!(repo, ["worktree", "list"]) =~ "epoch-"
  end

  test "cleanup containment follows the repo's OWN root, not just the global one", %{
    repo: repo,
    sha: sha,
    root: root
  } do
    {other_repo, other_root, other_sha} = second_repo("other")

    Application.put_env(:xaas, :ultracode_repos, %{
      "demo" => repo,
      "other" => %{"path" => other_repo, "worktree_root" => other_root}
    })

    assert {:ok, global_path} = Worktrees.provision("demo", sha, "run-1")
    assert {:ok, other_path} = Worktrees.provision("other", other_sha, "run-1")
    assert Path.dirname(global_path) == root
    assert Path.dirname(other_path) == other_root

    # A path under the global root is foreign to the per-repo-rooted alias.
    assert {:error, :outside_root} = Worktrees.cleanup("other", global_path)
    assert File.dir?(global_path)

    assert :ok = Worktrees.cleanup("other", other_path)
    assert :ok = Worktrees.cleanup("demo", global_path)
  end

  test "merge_to_integration merges a candidate head into the per-repo integration branch without touching the clone",
       %{
         repo: repo,
         sha: sha
       } do
    assert {:ok, path} = Worktrees.provision("demo", sha, "run-1")
    head = commit_file!(path, "feature.txt", "feature\n", "add feature")

    assert {:ok, %{branch: branch, head: integration_head}} =
             Worktrees.merge_to_integration("demo", head)

    assert branch == "ultracode/integration-demo"
    assert integration_head != head

    # The merged content really is on the integration branch.
    {content, 0} = System.cmd("git", ["-C", repo, "show", "#{branch}:feature.txt"])
    assert String.trim(content) == "feature"

    # The clone's checked-out branch, HEAD, and working tree are untouched.
    assert git!(repo, ["rev-parse", "--abbrev-ref", "HEAD"]) == "main"
    assert git!(repo, ["rev-parse", "HEAD"]) == sha
    assert git!(repo, ["status", "--porcelain"]) == ""

    # The management worktree was removed; the branch persists.
    refute git!(repo, ["worktree", "list"]) =~ "demo-integration-"
    assert git!(repo, ["branch", "--list", branch]) =~ branch

    # A second candidate integrates on top of the first.
    assert {:ok, path2} = Worktrees.provision("demo", sha, "run-2")
    head2 = commit_file!(path2, "second.txt", "second\n", "add second")

    assert {:ok, %{head: h2}} = Worktrees.merge_to_integration("demo", head2)
    assert h2 != integration_head
    {content2, 0} = System.cmd("git", ["-C", repo, "show", "#{branch}:second.txt"])
    assert String.trim(content2) == "second"
  end

  test "merge_to_integration refuses typed on conflict and leaves no debris", %{
    repo: repo,
    sha: sha
  } do
    assert {:ok, path} = Worktrees.provision("demo", sha, "run-1")
    h1 = commit_file!(path, "shared.txt", "a\n", "add shared a")
    assert {:ok, %{head: _}} = Worktrees.merge_to_integration("demo", h1)

    assert {:ok, path2} = Worktrees.provision("demo", sha, "run-2")
    head2 = commit_file!(path2, "shared.txt", "b\n", "add shared b")

    assert {:error, {:integration_merge_conflict, _}} =
             Worktrees.merge_to_integration("demo", head2)

    assert git!(repo, ["status", "--porcelain"]) == ""
    refute git!(repo, ["worktree", "list"]) =~ "demo-integration-"
  end

  test "merge_to_integration refuses malformed or unknown candidate heads", %{sha: sha} do
    assert {:error, :bad_candidate_head} = Worktrees.merge_to_integration("demo", "main")

    assert {:error, :bad_candidate_head} =
             Worktrees.merge_to_integration("demo", String.upcase(sha))

    assert {:error, :base_sha_not_in_repo} =
             Worktrees.merge_to_integration("demo", String.duplicate("a", 40))
  end

  # ------------------------------------------------------------------

  defp mktmp(label) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "worktrees-test-#{label}-#{System.unique_integer([:positive])}"
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

  # A second real clone with its own per-repo root, for multi-repo tests.
  defp second_repo(label) do
    base = mktmp("second-#{label}")
    repo = Path.join(base, "clone")
    root = Path.join(base, "runs")
    File.mkdir_p!(repo)
    sha = init_repo(repo)
    {repo, root, sha}
  end

  defp commit_file!(dir, file, content, message) do
    env = [
      {"GIT_AUTHOR_NAME", "t"},
      {"GIT_AUTHOR_EMAIL", "t@t"},
      {"GIT_COMMITTER_NAME", "t"},
      {"GIT_COMMITTER_EMAIL", "t@t"}
    ]

    File.write!(Path.join(dir, file), content)
    {_, 0} = System.cmd("git", ["-C", dir, "add", file], stderr_to_stdout: true)

    {_, 0} =
      System.cmd("git", ["-C", dir, "commit", "-m", message, "--quiet"],
        stderr_to_stdout: true,
        env: env
      )

    git!(dir, ["rev-parse", "HEAD"])
  end

  defp git!(dir, args) do
    {out, 0} = System.cmd("git", ["-C", dir | args], stderr_to_stdout: true)
    String.trim(out)
  end
end
