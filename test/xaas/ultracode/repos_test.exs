defmodule Xaas.Ultracode.ReposTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Chicago-style qualification of the multi-repo registry law
  (`Xaas.Ultracode.Repos`): real git repositories, real filesystem, real
  registry-file writes, and the real consumers (`Worktrees`, `Autonomic`)
  against them. Nothing mocked.
  """

  alias Xaas.Ultracode.{Autonomic, Repos, Worktrees}

  setup do
    original =
      for key <- [
            :ultracode_repos,
            :ultracode_repos_file,
            :ultracode_worktree_root,
            :ultracode_verifier_suites
          ],
          into: %{},
          do: {key, Application.get_env(:xaas, key)}

    base = mktmp("repos")
    repo = Path.join(base, "repo")
    sha = init_repo(repo)

    Application.put_env(:xaas, :ultracode_repos, %{})
    Application.delete_env(:xaas, :ultracode_repos_file)
    Application.delete_env(:xaas, :ultracode_worktree_root)
    Application.delete_env(:xaas, :ultracode_verifier_suites)

    on_exit(fn ->
      for {key, value} <- original do
        if is_nil(value),
          do: Application.delete_env(:xaas, key),
          else: Application.put_env(:xaas, key, value)
      end
    end)

    %{base: base, repo: repo, sha: sha}
  end

  # ------------------------------------------------------------------
  # Resolution + backward compatibility
  # ------------------------------------------------------------------

  test "the legacy path-string form resolves with the historical aps facts", %{
    repo: repo
  } do
    Application.put_env(:xaas, :ultracode_repos, %{"aps" => repo})

    assert {:ok, entry} = Repos.resolve("aps")
    assert %{sensing: "aps", suite: "aps-dod", canonical_suite: "aps-canonical"} = entry
    assert entry.path == repo
    # No suites configured in this env: the gap is HONEST, not hidden.
    refute entry.suite_registered
  end

  test "a structured entry with registered suites is ready with no gaps", %{repo: repo} do
    Application.put_env(:xaas, :ultracode_verifier_suites, %{
      "demo-dod" => %{},
      "demo-canonical" => %{}
    })

    Application.put_env(:xaas, :ultracode_repos, %{
      "demo" => %{
        path: repo,
        sensing: "aps",
        suite: "demo-dod",
        canonical_suite: "demo-canonical"
      }
    })

    assert {:ok, entry} = Repos.resolve("demo")
    assert entry.suite_registered
    assert entry.canonical_suite_registered
    assert Repos.ready?(entry)
    assert Repos.gaps(entry) == []
  end

  test "the reservation law: a reserved suite resolves WITH a visible gap", %{
    repo: repo
  } do
    Application.put_env(:xaas, :ultracode_repos, %{
      "iac" => %{
        "path" => repo,
        "sensing" => "generic-pytest",
        "suite" => "iac-dod",
        "canonical_suite" => nil
      }
    })

    assert {:ok, entry} = Repos.resolve("iac")
    refute entry.suite_registered
    # The sensing name is recorded metadata (owned by Xaas.Ultracode.Sensing),
    # never judged here.
    assert entry.sensing == "generic-pytest"
    # Explicit nil canonical_suite stays nil (canonical skipped), so only
    # the suite gap is reported.
    assert Repos.gaps(entry) == [:suite_not_registered]
    refute Repos.ready?(entry)
  end

  test "an unknown alias is a typed refusal, never a guess" do
    assert {:error, {:unknown_repo_alias, "nope"}} = Repos.resolve("nope")
    assert {:error, {:unknown_repo_alias, 42}} = Repos.resolve(42)
  end

  # ------------------------------------------------------------------
  # Validation law: typed refusals
  # ------------------------------------------------------------------

  test "bad alias format is refused with the offending value", %{repo: repo} do
    Application.put_env(:xaas, :ultracode_repos, %{"Bad Alias" => repo})

    assert {:error, {:invalid_repo_entry, "Bad Alias", {:bad_alias, "Bad Alias"}}} =
             Repos.resolve("Bad Alias")
  end

  test "a missing path, a non-git directory, and a relative path all refuse", %{base: base} do
    Application.put_env(:xaas, :ultracode_repos, %{
      "ghost" => "/nonexistent/path/to/clone",
      "plain" => base,
      "relative" => "some/relative/path"
    })

    assert {:error, {:invalid_repo_entry, "ghost", :repo_path_missing}} = Repos.resolve("ghost")

    assert {:error, {:invalid_repo_entry, "plain", :repo_is_not_a_git_checkout}} =
             Repos.resolve("plain")

    assert {:error, {:invalid_repo_entry, "relative", :repo_path_not_absolute}} =
             Repos.resolve("relative")
  end

  test "malformed suite and sensing names refuse at the registry", %{repo: repo} do
    Application.put_env(:xaas, :ultracode_repos, %{
      "x" => %{"path" => repo, "suite" => "BAD SUITE"},
      "y" => %{"path" => repo, "sensing" => "Not-A-Profile"}
    })

    assert {:error, {:invalid_repo_entry, "x", {:bad_suite_name, "BAD SUITE"}}} =
             Repos.resolve("x")

    assert {:error, {:invalid_repo_entry, "y", {:bad_sensing_profile, "Not-A-Profile"}}} =
             Repos.resolve("y")
  end

  test "a worktree root outside the global root refuses at registration, not verify time", %{
    base: base,
    repo: repo
  } do
    Application.put_env(:xaas, :ultracode_worktree_root, Path.join(base, "global-runs"))

    Application.put_env(:xaas, :ultracode_repos, %{
      "outside" => %{"path" => repo, "worktree_root" => Path.join(base, "elsewhere")},
      "inside" => %{"path" => repo, "worktree_root" => Path.join(base, "global-runs/sub")},
      "relative" => %{"path" => repo, "worktree_root" => "relative/root"}
    })

    assert {:error, {:invalid_repo_entry, "outside", :worktree_root_outside_global}} =
             Repos.resolve("outside")

    assert {:ok, inside} = Repos.resolve("inside")
    assert inside.worktree_root == Path.join(base, "global-runs/sub")

    assert {:error, {:invalid_repo_entry, "relative", :worktree_root_not_absolute}} =
             Repos.resolve("relative")
  end

  # ------------------------------------------------------------------
  # Sensing profiles
  # ------------------------------------------------------------------

  # ------------------------------------------------------------------
  # Durable registry file: register, precedence, corruption
  # ------------------------------------------------------------------

  test "register writes the file, and the file resolves even from an empty env", %{
    base: base,
    repo: repo
  } do
    file = Path.join(base, "registry.json")
    Application.put_env(:xaas, :ultracode_repos_file, file)

    assert {:ok, [entry]} =
             Repos.register(%{"bt" => %{"path" => repo, "suite" => "bt-dod"}}, file: file)

    assert entry.alias == "bt" and entry.path == repo
    assert File.regular?(file)
    assert {:ok, ^entry} = Repos.resolve("bt")
  end

  test "file entries win over env entries for the same alias", %{base: base, repo: repo} do
    other = Path.join(base, "other")
    init_repo(other)
    file = Path.join(base, "registry.json")
    Application.put_env(:xaas, :ultracode_repos_file, file)

    {:ok, _} = Repos.register(%{"bt" => %{"path" => repo}}, file: file)
    Application.put_env(:xaas, :ultracode_repos, %{"bt" => other})

    assert {:ok, entry} = Repos.resolve("bt")
    assert entry.path == repo
  end

  test "register is additive: existing file entries survive", %{base: base, repo: repo} do
    file = Path.join(base, "registry.json")
    Application.put_env(:xaas, :ultracode_repos_file, file)
    {:ok, _} = Repos.register(%{"one" => %{"path" => repo}}, file: file)
    {:ok, _} = Repos.register(%{"two" => %{"path" => repo}}, file: file)

    {results, warnings} = Repos.entries()
    assert warnings == []
    assert Map.has_key?(results, "one")
    assert Map.has_key?(results, "two")
    assert {:ok, {:ok, entry}} = Map.fetch(results, "one")
    assert entry.path == repo
  end

  test "a corrupt registry file is never clobbered and is surfaced as a warning", %{
    base: base,
    repo: repo
  } do
    file = Path.join(base, "registry.json")
    File.write!(file, "{definitely not json")
    Application.put_env(:xaas, :ultracode_repos_file, file)

    assert {:error, {:registry_file_unreadable, ^file, _}} =
             Repos.register(%{"x" => %{"path" => repo}})

    assert File.read!(file) == "{definitely not json"

    {results, warnings} = Repos.entries()
    assert results == %{}
    assert [{:registry_file_unreadable, ^file, _}] = warnings
  end

  test "register without a configured file is a typed refusal", %{repo: repo} do
    assert {:error, :registry_file_unconfigured} = Repos.register(%{"x" => %{"path" => repo}})
  end

  test "register refuses when ANY new entry is invalid (all-or-nothing)", %{
    base: base,
    repo: repo
  } do
    file = Path.join(base, "registry.json")

    assert {:error, {:invalid_repo_entry, "bad", _}} =
             Repos.register(
               %{"good" => %{"path" => repo}, "bad" => %{"path" => "/no/such/repo"}},
               file: file
             )

    refute File.regular?(file)
    assert {%{}, []} = Repos.entries()
  end

  # ------------------------------------------------------------------
  # Consumers: Worktrees and Autonomic against the registry
  # ------------------------------------------------------------------

  test "Worktrees provisions through the legacy env form (compat law)", %{
    base: base,
    repo: repo,
    sha: sha
  } do
    Application.put_env(:xaas, :ultracode_repos, %{"demo" => repo})
    Application.put_env(:xaas, :ultracode_worktree_root, Path.join(base, "runs"))

    assert {:ok, path} = Worktrees.provision("demo", sha, "wt-legacy")
    assert Path.dirname(path) == Path.join(base, "runs")
    Worktrees.cleanup("demo", path)
  end

  test "Worktrees honors a per-entry worktree root (under no global root)", %{
    base: base,
    repo: repo,
    sha: sha
  } do
    entry_root = Path.join(base, "entry-runs")

    Application.put_env(:xaas, :ultracode_repos, %{
      "demo" => %{"path" => repo, "worktree_root" => entry_root}
    })

    assert {:ok, path} = Worktrees.provision("demo", sha, "wt-entry")
    assert Path.dirname(path) == entry_root
    Worktrees.cleanup("demo", path)
  end

  test "Worktrees preserves its established typed refusals", %{base: base, repo: repo, sha: sha} do
    Application.put_env(:xaas, :ultracode_repos, %{"demo" => repo, "plain" => base})
    Application.put_env(:xaas, :ultracode_worktree_root, Path.join(base, "runs"))

    assert {:error, :unknown_repo_alias} = Worktrees.provision("nope", sha, "wt-x")
    assert {:error, :repo_is_not_a_git_checkout} = Worktrees.provision("plain", sha, "wt-x")
  end

  test "Autonomic.new_ctx refuses an unregistered alias with a typed raise" do
    assert_raise ArgumentError, ~r/unknown_repo_alias/, fn ->
      Autonomic.new_ctx(repo: "no-such-repo")
    end
  end

  test "a FILE-registered target is provisionable through Worktrees (composed law)", %{
    base: base,
    repo: repo,
    sha: sha
  } do
    # The durable file is the ONLY place this target exists -- proving the
    # Worktrees raw-entry lookup reads the merged sources.
    file = Path.join(base, "registry.json")
    Application.put_env(:xaas, :ultracode_repos_file, file)
    Application.put_env(:xaas, :ultracode_repos, %{})
    Application.put_env(:xaas, :ultracode_worktree_root, Path.join(base, "runs"))

    assert {:ok, _} = Repos.register(%{"filed" => %{"path" => repo}}, file: file)
    assert {:ok, path} = Worktrees.provision("filed", sha, "wt-filed")
    assert Path.dirname(path) == Path.join(base, "runs")
    Worktrees.cleanup("filed", path)
  end

  test "registered entries never write explicit nils (Worktrees entry law)", %{
    base: base,
    repo: repo
  } do
    file = Path.join(base, "registry.json")

    assert {:ok, _} =
             Repos.register(
               %{"bt" => %{"path" => repo, "worktree_root" => nil, "canonical_suite" => nil}},
               file: file
             )

    body = File.read!(file)
    refute body =~ "null"
    assert body =~ "path"
  end

  # ------------------------------------------------------------------
  # Fixtures: real git, real tmp
  # ------------------------------------------------------------------

  defp mktmp(label) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "xaas-repos-test-#{label}-#{System.unique_integer([:positive])}"
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

    File.mkdir_p!(repo)

    {_, 0} = System.cmd("git", ["init", "-q", "-b", "main"], env: env, cd: repo)
    File.write!(Path.join(repo, "hello.txt"), "hello\n")
    {_, 0} = System.cmd("git", ["add", "."], env: env, cd: repo)
    {_, 0} = System.cmd("git", ["commit", "-q", "-m", "init"], env: env, cd: repo)

    {out, 0} = System.cmd("git", ["rev-parse", "HEAD"], env: env, cd: repo)
    String.trim(out)
  end
end
