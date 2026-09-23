defmodule Xaas.Ultracode.AutonomicProfileSenseTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  @moduledoc """
  Qualifies the registry-driven sensing seam of `Xaas.Ultracode.Autonomic`:
  a registered repo whose `sensing` NAME resolves to a declared profile
  (`Xaas.Ultracode.Sensing.profile_for/1`) is sensed from its OWN tickets
  through the real `Autonomic.sense/1` -- real `git clone --local` clone, real
  provisioned detached worktree, real `## Status` parsing -- and an entry that
  opts in to `refresh` has its clone fast-forwarded BEFORE `base_sha` is
  pinned, so the wave senses the source's current head, not a stale one.

  Everything is real (git, filesystem, the app's own worktree provisioning);
  nothing is faked.
  """

  alias Xaas.Ultracode.{Autonomic, Sensing}

  @git_env [
    {"GIT_AUTHOR_NAME", "profile-sense-test"},
    {"GIT_AUTHOR_EMAIL", "profile-sense-test@xaas.local"},
    {"GIT_COMMITTER_NAME", "profile-sense-test"},
    {"GIT_COMMITTER_EMAIL", "profile-sense-test@xaas.local"}
  ]

  @keys [
    :ultracode_repos,
    :ultracode_repos_file,
    :ultracode_worktree_root,
    :ultracode_ticket_dir,
    :ultracode_sensing_profiles,
    :ultracode_backlog_scripts
  ]

  setup do
    original = for key <- @keys, into: %{}, do: {key, Application.get_env(:xaas, key)}

    base =
      Path.join(
        System.tmp_dir!(),
        "profile-sense-#{:crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)}"
      )

    File.mkdir_p!(base)
    source = Path.join(base, "source")
    clone = Path.join(base, "clone")

    File.mkdir_p!(source)
    {_, 0} = System.cmd("git", ["init", "-q", "-b", "main", source], stderr_to_stdout: true)

    ticket!(source, "001-open", "PARTIAL_ALIVE -- half done")
    ticket!(source, "002-done", "ALIVE -- shipped")
    ticket!(source, "003-blocked", "BLOCKED: needs a decision")
    File.write!(Path.join(source, "docs/jira/004-no-status.md"), "# 004\n\nno status section\n")
    commit!(source, "seed tickets")

    {_, 0} = System.cmd("git", ["clone", "--local", "-q", source, clone], stderr_to_stdout: true)

    Application.put_env(:xaas, :ultracode_worktree_root, Path.join(base, "runs"))
    Application.put_env(:xaas, :ultracode_ticket_dir, Path.join(base, "tickets"))
    Application.delete_env(:xaas, :ultracode_repos_file)
    Application.put_env(:xaas, :ultracode_backlog_scripts, %{})

    Application.put_env(:xaas, :ultracode_sensing_profiles, %{
      "fix-jira" => %{"type" => "jira_dir", "dir" => "docs/jira"}
    })

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

  defp register(clone, refresh) do
    Application.put_env(:xaas, :ultracode_repos, %{
      "fix" => %{
        path: clone,
        sensing: "fix-jira",
        suite: "fix-dod",
        canonical_suite: nil,
        refresh: refresh
      }
    })
  end

  # ------------------------------------------------------------------
  # Profile resolution
  # ------------------------------------------------------------------

  test "profile_for/1 resolves declared names and refuses everything else" do
    assert {:ok, %{"type" => "jira_dir", "dir" => "docs/jira"}} = Sensing.profile_for("fix-jira")
    assert Sensing.profile_for("aps") == :error
    assert Sensing.profile_for(nil) == :error
    assert Sensing.profile_for(:fix_jira) == :error
    assert Sensing.profile_for(%{}) == :error

    Application.put_env(:xaas, :ultracode_sensing_profiles, nil)
    assert Sensing.profile_for("fix-jira") == :error
  end

  # ------------------------------------------------------------------
  # sense/1 through the named profile
  # ------------------------------------------------------------------

  test "sense/1 derives the not-yet-ALIVE tickets from the clone's own Status sections", %{
    clone: clone
  } do
    register(clone, false)
    ctx = Autonomic.new_ctx(repo: "fix")

    assert {:ok, items} = Autonomic.sense(ctx)

    # Status first word decides: ALIVE is closed; PARTIAL_ALIVE and BLOCKED stay
    # open; a ticket with no Status section is skipped (not silently opened).
    assert Enum.map(items, & &1["source"]["file"]) == [
             "docs/jira/001-open.md",
             "docs/jira/003-blocked.md"
           ]

    for item <- items do
      assert item["id"] =~ ~r/^jira-[a-z0-9-]+-[0-9a-f]{6}$/
      assert item["allowed_paths"] == ["*"]
      assert item["mutants"] == []
      assert item["goal"] =~ "Work the ticket at"
    end

    assert items == Enum.sort_by(items, & &1["id"])

    # The sense worktree was cleaned up.
    refute File.exists?(
             Path.join(
               Application.fetch_env!(:xaas, :ultracode_worktree_root),
               "fix-sense-#{ctx.nonce}"
             )
           )
  end

  test "an unresolvable sensing name does NOT use the profile path", %{clone: clone} do
    Application.put_env(:xaas, :ultracode_repos, %{
      "fix" => %{
        path: clone,
        sensing: "no-such-profile",
        suite: "fix-dod",
        canonical_suite: nil
      }
    })

    ctx = Autonomic.new_ctx(repo: "fix")

    # Falls back to the backlog-script path (aps_backlog.py), which cannot
    # derive anything from this fixture -- the point is that it is NOT the
    # jira_dir items above.
    result =
      try do
        Autonomic.sense(ctx)
      rescue
        error -> {:raised, error}
      end

    refute match?({:ok, [%{"id" => "jira-" <> _} | _]}, result)
  end

  # ------------------------------------------------------------------
  # refresh before base_sha
  # ------------------------------------------------------------------

  test "an opted-in clone is fast-forwarded BEFORE base_sha is pinned", %{
    source: source,
    clone: clone
  } do
    stale = git!(clone, ["rev-parse", "HEAD"])
    ticket!(source, "005-new", "UNKNOWN")
    fresh = commit!(source, "a new ticket lands upstream")

    register(clone, true)
    ctx = Autonomic.new_ctx(repo: "fix")

    assert %{base_sha: ^fresh, refresh: %{status: :advanced, from: ^stale, head: ^fresh}} =
             ctx.repos["fix"]

    assert ctx.base_sha == fresh

    assert {:ok, items} = Autonomic.sense(ctx)
    assert "docs/jira/005-new.md" in Enum.map(items, & &1["source"]["file"])
  end

  test "run/1 ledgers the refresh outcome next to the start event", %{
    source: source,
    clone: clone
  } do
    stale = git!(clone, ["rev-parse", "HEAD"])
    ticket!(source, "005-new", "UNKNOWN")
    fresh = commit!(source, "a new ticket lands upstream")

    register(clone, true)

    # `only` selects no sensed item, so the wave exercises sense + ledger +
    # receipt for real without dispatching a worker.
    assert {:ok, _report} = Autonomic.run(repo: "fix", only: ["no-such-item"], capacity: 1)

    [ledger_path] =
      Application.fetch_env!(:xaas, :ultracode_ticket_dir)
      |> Path.join("autonomic-*/ledger.ndjson")
      |> Path.wildcard()

    events =
      ledger_path
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.map(&Jason.decode!/1)

    assert %{"data" => %{"base_sha" => ^fresh}} = Enum.find(events, &(&1["event"] == "start"))

    assert %{"data" => %{"fix" => refresh}} = Enum.find(events, &(&1["event"] == "refresh"))
    assert %{"status" => "advanced", "from" => ^stale, "head" => ^fresh} = refresh
    assert refresh["upstream"] == "origin/main"
  end

  test "without the opt-in the clone is sensed at its own (stale) head", %{
    source: source,
    clone: clone
  } do
    stale = git!(clone, ["rev-parse", "HEAD"])
    ticket!(source, "005-new", "UNKNOWN")
    _fresh = commit!(source, "a new ticket lands upstream")

    register(clone, false)
    ctx = Autonomic.new_ctx(repo: "fix")

    assert %{base_sha: ^stale, refresh: nil} = ctx.repos["fix"]

    assert {:ok, items} = Autonomic.sense(ctx)
    refute "docs/jira/005-new.md" in Enum.map(items, & &1["source"]["file"])
  end

  test "a refused refresh degrades to the clone's head instead of halting the wave", %{
    source: source,
    clone: clone
  } do
    local = commit!(clone, "diverged clone-local commit")
    upstream = ticket_commit!(source, "005-new", "UNKNOWN")

    register(clone, true)

    log =
      capture_log(fn ->
        ctx = Autonomic.new_ctx(repo: "fix")

        # Typed result recorded on the repo facts; base_sha is the clone's own
        # head (consistent, if older) -- and nothing was reset.
        assert %{base_sha: ^local, refresh: {:error, {:refresh_diverged, ^local, ^upstream}}} =
                 ctx.repos["fix"]
      end)

    assert log =~ "clone refresh refused for fix"
    assert git!(clone, ["rev-parse", "HEAD"]) == local
  end

  # ------------------------------------------------------------------
  # Helpers (real git only)
  # ------------------------------------------------------------------

  defp ticket!(dir, stem, status) do
    path = Path.join(dir, "docs/jira/#{stem}.md")
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, "# #{stem}\n\n## Status\n\n#{status}\n\n## History\n\n- seeded\n")
  end

  defp ticket_commit!(dir, stem, status) do
    ticket!(dir, stem, status)
    commit!(dir, "ticket #{stem}")
  end

  defp commit!(dir, message) do
    File.write!(Path.join(dir, ".touch-#{System.unique_integer([:positive])}"), "x")
    git!(dir, ["add", "-A"])
    git!(dir, ["commit", "-q", "-m", message])
    git!(dir, ["rev-parse", "HEAD"])
  end

  defp git!(dir, args) do
    {out, 0} = System.cmd("git", ["-C", dir | args], stderr_to_stdout: true, env: @git_env)
    String.trim(out)
  end
end
