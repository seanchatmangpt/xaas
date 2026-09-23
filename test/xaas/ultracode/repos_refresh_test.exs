defmodule Xaas.Ultracode.ReposRefreshTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Chicago-style qualification of the registry's refresh law
  (`Xaas.Ultracode.Repos.refresh/1` and the `refresh` entry field): real git
  repositories, real `git clone --local` clones (the way the operator targets
  are provisioned), real fetches and fast-forwards, real registry-file
  writes. Nothing mocked -- every assertion is on resulting git state.
  """

  alias Xaas.Ultracode.Repos

  @git_env [
    {"GIT_AUTHOR_NAME", "refresh-test"},
    {"GIT_AUTHOR_EMAIL", "refresh-test@xaas.local"},
    {"GIT_COMMITTER_NAME", "refresh-test"},
    {"GIT_COMMITTER_EMAIL", "refresh-test@xaas.local"}
  ]

  setup do
    original =
      for key <- [:ultracode_repos, :ultracode_repos_file, :ultracode_worktree_root],
          into: %{},
          do: {key, Application.get_env(:xaas, key)}

    base =
      Path.join(
        System.tmp_dir!(),
        "repos-refresh-#{:crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)}"
      )

    File.mkdir_p!(base)
    source = Path.join(base, "source")
    clone = Path.join(base, "clone")

    init_source(source)
    {_, 0} = System.cmd("git", ["clone", "--local", "-q", source, clone], stderr_to_stdout: true)

    Application.put_env(:xaas, :ultracode_repos, %{
      "fix" => %{
        path: clone,
        sensing: "fix-jira",
        suite: "fix-dod",
        canonical_suite: nil,
        refresh: true
      }
    })

    Application.delete_env(:xaas, :ultracode_repos_file)
    Application.delete_env(:xaas, :ultracode_worktree_root)

    on_exit(fn ->
      for {key, value} <- original do
        if is_nil(value),
          do: Application.delete_env(:xaas, key),
          else: Application.put_env(:xaas, key, value)
      end

      File.rm_rf!(base)
    end)

    %{base: base, source: source, clone: clone}
  end

  # ------------------------------------------------------------------
  # refresh/1: the state machine over real git
  # ------------------------------------------------------------------

  test "a stale git clone --local clone is fast-forwarded to its source head", %{
    source: source,
    clone: clone
  } do
    stale = git!(clone, ["rev-parse", "HEAD"])
    new_head = commit!(source, "docs/jira/002.md", "# two\n", "second")
    refute stale == new_head

    assert {:ok, result} = Repos.refresh("fix")

    assert %{status: :advanced, branch: "main", upstream: "origin/main"} = result
    assert result.from == stale
    assert result.head == new_head
    # Resulting state, not the call: the clone's checked-out branch and work
    # tree really moved, and base_sha (the new head) now resolves in it.
    assert git!(clone, ["rev-parse", "HEAD"]) == new_head
    assert File.read!(Path.join(clone, "docs/jira/002.md")) == "# two\n"
    assert git!(clone, ["status", "--porcelain"]) == ""
  end

  test "a clone already at its upstream head is :current and unchanged", %{clone: clone} do
    head = git!(clone, ["rev-parse", "HEAD"])

    assert {:ok, %{status: :current, from: ^head, head: ^head}} = Repos.refresh("fix")
    assert git!(clone, ["rev-parse", "HEAD"]) == head
  end

  test "a clone AHEAD of its upstream is left untouched (:ahead)", %{clone: clone} do
    local = commit!(clone, "local.txt", "local\n", "clone-local commit")

    assert {:ok, %{status: :ahead, from: ^local, head: ^local}} = Repos.refresh("fix")
    assert git!(clone, ["rev-parse", "HEAD"]) == local
  end

  test "a DIVERGED clone is a typed refusal and its head and tree are untouched", %{
    source: source,
    clone: clone
  } do
    local = commit!(clone, "local.txt", "local\n", "clone-local commit")
    upstream = commit!(source, "upstream.txt", "upstream\n", "source commit")

    assert {:error, {:refresh_diverged, ^local, ^upstream}} = Repos.refresh("fix")

    assert git!(clone, ["rev-parse", "HEAD"]) == local
    refute File.exists?(Path.join(clone, "upstream.txt"))
    assert git!(clone, ["status", "--porcelain"]) == ""
  end

  test "refresh never moves any local branch but the checked-out one", %{
    source: source,
    clone: clone
  } do
    # The integration branch is where court-approved work lands: it must be
    # invisible to refresh.
    integration = "ultracode/integration-fix"
    {_, 0} = System.cmd("git", ["-C", clone, "branch", integration], stderr_to_stdout: true)
    before = git!(clone, ["rev-parse", integration])
    _ = commit!(source, "docs/jira/002.md", "# two\n", "second")

    assert {:ok, %{status: :advanced}} = Repos.refresh("fix")

    assert git!(clone, ["rev-parse", integration]) == before
    refute git!(clone, ["rev-parse", "HEAD"]) == before
  end

  test "a repo with no upstream refuses :refresh_no_upstream", %{base: base} do
    lonely = Path.join(base, "lonely")
    init_source(lonely)

    Application.put_env(:xaas, :ultracode_repos, %{
      "lonely" => %{path: lonely, sensing: "x", suite: "lonely-dod", canonical_suite: nil}
    })

    assert {:error, :refresh_no_upstream} = Repos.refresh("lonely")
  end

  test "a detached HEAD refuses :refresh_detached_head", %{clone: clone} do
    head = git!(clone, ["rev-parse", "HEAD"])
    {_, 0} = System.cmd("git", ["-C", clone, "checkout", "-q", "--detach", head])

    assert {:error, :refresh_detached_head} = Repos.refresh("fix")
    assert git!(clone, ["rev-parse", "HEAD"]) == head
  end

  test "an unreachable remote is a typed fetch refusal, not a crash", %{
    base: base,
    clone: clone
  } do
    {_, 0} =
      System.cmd("git", ["-C", clone, "remote", "set-url", "origin", Path.join(base, "gone")])

    assert {:error, {:refresh_fetch_failed, code, _output}} = Repos.refresh("fix")
    assert is_integer(code) and code != 0
  end

  test "an unregistered alias is the registry's typed refusal" do
    assert {:error, {:unknown_repo_alias, "nope"}} = Repos.refresh("nope")
  end

  # ------------------------------------------------------------------
  # The `refresh` entry field
  # ------------------------------------------------------------------

  test "refresh defaults to false and is validated as a boolean", %{clone: clone} do
    raw = %{"path" => clone, "sensing" => "x", "suite" => "fix-dod", "canonical_suite" => nil}

    assert {:ok, %{refresh: false}} = Repos.validate("fix", raw)
    assert {:ok, %{refresh: true}} = Repos.validate("fix", Map.put(raw, "refresh", true))
    assert {:ok, %{refresh: false}} = Repos.validate("fix", Map.put(raw, "refresh", false))

    assert {:error, {:invalid_repo_entry, "fix", {:bad_refresh, "yes"}}} =
             Repos.validate("fix", Map.put(raw, "refresh", "yes"))

    # The legacy path-string form never refreshes.
    assert {:ok, %{refresh: false}} = Repos.validate("fix", clone)
  end

  test "register persists refresh and the durable file resolves it", %{base: base, clone: clone} do
    file = Path.join(base, "registry.json")
    Application.put_env(:xaas, :ultracode_repos, %{})
    Application.put_env(:xaas, :ultracode_repos_file, file)

    additions = %{
      "durable" => %{
        "path" => clone,
        "sensing" => "durable-jira",
        "suite" => "durable-dod",
        "canonical_suite" => "durable-canonical",
        "refresh" => true
      }
    }

    assert {:ok, [%{alias: "durable", refresh: true}]} = Repos.register(additions)

    assert %{"durable" => %{"refresh" => true, "suite" => "durable-dod"}} =
             file |> File.read!() |> Jason.decode!()

    assert {:ok, entry} = Repos.resolve("durable")
    assert entry.refresh
    assert entry.canonical_suite == "durable-canonical"
    # A registered-but-unimplemented suite is a visible gap, never a refusal.
    # the ERRC sensing law (ba76798) adds the profile-registration gap for a
    # sensing name that maps to no implemented profile
    assert Repos.gaps(entry) == [
             :suite_not_registered,
             :canonical_suite_not_registered,
             :sensing_profile_not_registered
           ]

    assert {:ok, %{status: :current}} = Repos.refresh("durable")
  end

  # ------------------------------------------------------------------
  # The operator surface: mix xaas.ultracode.repos
  # ------------------------------------------------------------------

  describe "mix xaas.ultracode.repos" do
    setup %{base: base, clone: clone} do
      previous = Mix.shell()
      Mix.shell(Mix.Shell.Process)
      on_exit(fn -> Mix.shell(previous) end)

      # The task runs `loadconfig` (re-reading config/*.exs, which resets the
      # env-seeded `:ultracode_repos`), so the entries under test live in the
      # durable registry FILE -- the operator's real registration path, which
      # config loading never touches.
      file = Path.join(base, "task-registry.json")

      assert {:ok, _} =
               Repos.register(
                 %{
                   "fix" => %{
                     "path" => clone,
                     "sensing" => "x",
                     "suite" => "fix-dod",
                     "canonical_suite" => nil,
                     "refresh" => true
                   }
                 },
                 file: file
               )

      Application.put_env(:xaas, :ultracode_repos, %{})
      Application.put_env(:xaas, :ultracode_repos_file, file)
      %{registry_file: file}
    end

    test "--refresh ALIAS fast-forwards the clone and reports it", %{
      source: source,
      clone: clone
    } do
      new_head = commit!(source, "docs/jira/002.md", "# two\n", "second")

      Mix.Tasks.Xaas.Ultracode.Repos.run(["--refresh", "fix"])

      assert_received {:mix_shell, :info, [line]}
      assert line =~ "fix  refresh=advanced  upstream=origin/main"
      assert line =~ String.slice(new_head, 0, 12)
      assert git!(clone, ["rev-parse", "HEAD"]) == new_head
    end

    test "--refresh all touches only the entries that opted in", %{
      source: source,
      clone: clone,
      registry_file: registry_file
    } do
      other = Path.join(Path.dirname(clone), "other-clone")

      {_, 0} =
        System.cmd("git", ["clone", "--local", "-q", source, other], stderr_to_stdout: true)

      assert {:ok, _} =
               Repos.register(
                 %{
                   "other" => %{
                     "path" => other,
                     "sensing" => "x",
                     "suite" => "other-dod",
                     "canonical_suite" => nil
                   }
                 },
                 file: registry_file
               )

      other_before = git!(other, ["rev-parse", "HEAD"])
      new_head = commit!(source, "docs/jira/002.md", "# two\n", "second")

      Mix.Tasks.Xaas.Ultracode.Repos.run(["--refresh", "all"])

      assert git!(clone, ["rev-parse", "HEAD"]) == new_head
      # `other` never opted in: untouched even though its upstream moved.
      assert git!(other, ["rev-parse", "HEAD"]) == other_before
    end

    test "--refresh all attempts every opted-in clone, then fails naming each refusal", %{
      source: source,
      clone: clone,
      registry_file: registry_file
    } do
      # "aaa" sorts first and is diverged; "fix" must still be refreshed.
      diverged = Path.join(Path.dirname(clone), "diverged-clone")

      {_, 0} =
        System.cmd("git", ["clone", "--local", "-q", source, diverged], stderr_to_stdout: true)

      assert {:ok, _} =
               Repos.register(
                 %{
                   "aaa" => %{
                     "path" => diverged,
                     "sensing" => "x",
                     "suite" => "aaa-dod",
                     "canonical_suite" => nil,
                     "refresh" => true
                   }
                 },
                 file: registry_file
               )

      _ = commit!(diverged, "local.txt", "local\n", "diverged-local")
      new_head = commit!(source, "docs/jira/002.md", "# two\n", "second")

      assert_raise Mix.Error, ~r/refresh refused aaa: refresh_diverged/, fn ->
        Mix.Tasks.Xaas.Ultracode.Repos.run(["--refresh", "all"])
      end

      assert git!(clone, ["rev-parse", "HEAD"]) == new_head
    end

    test "--refresh of a diverged clone raises the typed refusal", %{source: source, clone: clone} do
      _ = commit!(clone, "local.txt", "local\n", "local")
      _ = commit!(source, "upstream.txt", "upstream\n", "upstream")

      assert_raise Mix.Error, ~r/refresh refused fix: refresh_diverged/, fn ->
        Mix.Tasks.Xaas.Ultracode.Repos.run(["--refresh", "fix"])
      end
    end

    test "--register --refresh-before-sense records refresh in the durable file", %{
      base: base,
      clone: clone
    } do
      file = Path.join(base, "task-registry.json")

      Mix.Tasks.Xaas.Ultracode.Repos.run([
        "--register",
        "taskreg",
        "--path",
        clone,
        "--sensing",
        "taskreg-jira",
        "--suite",
        "taskreg-dod",
        "--canonical-suite",
        "taskreg-canonical",
        "--refresh-before-sense",
        "--file",
        file
      ])

      assert %{"taskreg" => %{"refresh" => true, "sensing" => "taskreg-jira"}} =
               file |> File.read!() |> Jason.decode!()

      # Omitting the flag writes no refresh key at all (absent = default false).
      Mix.Tasks.Xaas.Ultracode.Repos.run([
        "--register",
        "plainreg",
        "--path",
        clone,
        "--file",
        file
      ])

      decoded = file |> File.read!() |> Jason.decode!()
      refute Map.has_key?(decoded["plainreg"], "refresh")
    end
  end

  # ------------------------------------------------------------------
  # Helpers (real git only)
  # ------------------------------------------------------------------

  defp init_source(dir) do
    File.mkdir_p!(dir)
    {_, 0} = System.cmd("git", ["init", "-q", "-b", "main", dir], stderr_to_stdout: true)
    commit!(dir, "docs/jira/001.md", "# one\n", "first")
  end

  defp commit!(dir, rel, content, message) do
    path = Path.join(dir, rel)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
    git!(dir, ["add", "-A"])
    git!(dir, ["commit", "-q", "-m", message])
    git!(dir, ["rev-parse", "HEAD"])
  end

  defp git!(dir, args) do
    {out, 0} = System.cmd("git", ["-C", dir | args], stderr_to_stdout: true, env: @git_env)
    String.trim(out)
  end
end
