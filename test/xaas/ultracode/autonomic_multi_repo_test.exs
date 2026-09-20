defmodule Xaas.Ultracode.AutonomicMultiRepoTest do
  use Xaas.DataCase, async: false

  @moduledoc """
  Chicago-style qualification of the MULTI-REPO planning law through the
  real wave path (`Xaas.Ultracode.Autonomic.run/1` and, via the wave-runner
  seam, `Xaas.Ultracode.Campaign`): real sandboxed Postgres, real registered
  repositories (tiny local git clones), real worktrees, real leases, and the
  real fabric verifier (a `steps: []` suite -- the court still checks head
  and tree, it just has no steps to run). The only stand-ins are the model
  (a scripted lease-protocol worker) and the backlog senser (a scripted
  deterministic profile -- generic sensing profiles are their own work
  stream; the plan law treats any `{:ok, items}` senser as interchangeable).

  Assertions are on the wave receipt, the campaign ledger, sealed state,
  ticket files, Run goals (the OCEL-exported dispatch goal), and git state.

  The single-repo regression test pins the artifact shapes at the byte
  level: a single-alias wave emits exactly the historical keys, no repo
  tags anywhere.
  """

  alias Xaas.Ultracode.{Autonomic, Campaign, Epoch, Lease, OcelEgress, Run}

  @provider "zcode-multi-test"
  @suite "trivial"
  @repos ["alpha", "beta", "gamma"]

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    original =
      for key <- [
            :ultracode_verifier_suites,
            :ultracode_worktree_root,
            :ultracode_ticket_dir,
            :ultracode_repos,
            :ultracode_wave_repo_caps,
            :ultracode_wave_runner
          ],
          into: %{},
          do: {key, Application.get_env(:xaas, key)}

    base = mktmp("multi")
    repos = Map.new(@repos, fn name -> {name, init_repo(Path.join(base, name))} end)

    Application.put_env(:xaas, :ultracode_worktree_root, Path.join(base, "runs"))
    Application.put_env(:xaas, :ultracode_ticket_dir, Path.join(base, "tickets"))
    Application.put_env(:xaas, :ultracode_repos, repos)
    Application.put_env(:xaas, :ultracode_verifier_suites, %{@suite => %{steps: []}})

    Process.put(:multi_campaign_ledger, Path.join(base, "campaign-ledger.ndjson"))

    on_exit(fn ->
      for {key, value} <- original, do: Application.put_env(:xaas, key, value)
    end)

    :ok
  end

  # ------------------------------------------------------------------
  # The planning law, end to end
  # ------------------------------------------------------------------

  test "a multi-repo wave draws round-robin, tags every artifact with its repo, and integrates per repo" do
    senser = profile_senser(%{"alpha" => ["a1", "a2"], "beta" => ["b1", "b2"], "gamma" => ["g1"]})

    assert {:ok, report} = run_loop(repo: "alpha,beta,gamma", senser: senser, capacity: 3)

    assert report["standing"] == "ALIVE"
    assert report["human_inputs"] == 0
    assert report["repo"] == "alpha,beta,gamma"
    assert report["repos"] == ["alpha", "beta", "gamma"]

    # The plan: round-robin over sorted aliases -- alpha, beta, gamma each
    # get their first item before alpha gets its second.
    assert report["backlog"] == [
             %{"item" => "a1", "repo" => "alpha"},
             %{"item" => "b1", "repo" => "beta"},
             %{"item" => "g1", "repo" => "gamma"},
             %{"item" => "a2", "repo" => "alpha"},
             %{"item" => "b2", "repo" => "beta"}
           ]

    assert length(report["items"]) == 5
    assert Enum.all?(report["items"], &(&1["status"] == "done"))
    assert Enum.all?(report["items"], &is_binary(&1["repo"]))

    # Per-repo integration: one worktree/branch per repo, tagged by name.
    assert report["integration"] == nil

    for repo <- @repos do
      integ = report["integrations"][repo]
      assert integ["branch"] =~ ~r/^#{repo}-autonomic-[0-9a-f]{6}$/
      assert integ["head"] != report["base_shas"][repo]
      assert Path.basename(integ["worktree"]) =~ ~r/^#{repo}-integration-/
      assert report["canonical"][repo]["status"] == "pass"
    end

    assert Enum.sort(Enum.map(report["merged"], &{&1["repo"], &1["item"]})) ==
             Enum.sort([
               {"alpha", "a1"},
               {"alpha", "a2"},
               {"beta", "b1"},
               {"beta", "b2"},
               {"gamma", "g1"}
             ])

    # End-to-end tags in the DISPATCH payloads: each wave Run's goal (the
    # OCEL-exported dispatch goal) and ticket name the repo; each epoch's
    # worktree is provisioned from that repo.
    runs =
      Run
      |> Ash.read!(action: :read_unscoped, authorize?: false)
      |> Enum.filter(&(&1.provider == @provider))

    assert length(runs) == 5

    for run <- runs do
      [repo_tag] = Regex.run(~r/^\[repo: ([a-z]+)\]/, run.goal, capture: :all_but_first)

      # The DB ground-truth tag: the run binds its execution repo (the
      # Worktrees lookup key -- OCEL derives the Repo object from it).
      assert run.execution_repo_alias == repo_tag

      ticket = run |> ticket_path() |> File.read!() |> Jason.decode!()
      assert ticket["repo"] == repo_tag

      epoch =
        Epoch
        |> Ash.read!(action: :read_unscoped, authorize?: false)
        |> Enum.find(&(&1.run_id == run.id))

      # The subject convention: "<repo>-autonomic:<item>#<attempt>:<run>".
      assert epoch.exact_subject == "#{repo_tag}-autonomic:#{ticket["item"]}#1:#{run.id}"

      assert Path.basename(epoch.worktree) |> String.starts_with?("#{repo_tag}-")
    end

    tagged_repos =
      MapSet.new(runs, fn run ->
        Regex.run(~r/^\[repo: ([a-z]+)\]/, run.goal, capture: :all_but_first) |> hd()
      end)

    assert MapSet.size(tagged_repos) == 3

    # The OCEL projection carries the repo tag in the Run goal and the
    # epoch worktree path -- no OCEL code was changed; the tags flow.
    assert {:ok, doc} = OcelEgress.derive_run(hd(runs))

    run_object = Enum.find(doc["ocel:objects"], &(&1["type"] == "Run"))
    assert run_object["attributes"]["goal"] =~ ~r/^\[repo: [a-z]+\]/

    epoch_object = Enum.find(doc["ocel:objects"], &(&1["type"] == "Epoch"))
    assert Path.basename(epoch_object["attributes"]["worktree"]) =~ ~r/^[a-z]+-/

    # The wave ledger is tagged: start carries the selection, sensed the
    # per-item repo, worktree events the repo.
    lines = ledger_lines(report)
    start = find_event(lines, "start")
    assert %{"repos" => ["alpha", "beta", "gamma"], "base_shas" => base_shas} = start["data"]
    assert map_size(base_shas) == 3

    assert find_event(lines, "sensed")["data"]["items"] == report["backlog"]

    for wt <- Enum.filter(lines, &(&1["event"] == "worktree")) do
      assert is_binary(wt["data"]["repo"])
    end
  end

  test "rotation fairness across waves: every wave gives each repo at least one item" do
    senser = profile_senser(%{"alpha" => ["a1", "a2"], "beta" => ["b1", "b2"], "gamma" => ["g1"]})

    runner = fn wave_opts ->
      Autonomic.run(
        Keyword.merge(wave_opts,
          provider: @provider,
          canonical_suite: @suite,
          worker: scripted_worker(),
          senser: senser
        )
      )
    end

    {:ok, summary} =
      Campaign.start(
        repo: "all",
        suite: @suite,
        capacity: 3,
        duration: "1h",
        wave_interval: "1s",
        max_waves: 3,
        ledger: campaign_ledger(),
        runner: runner,
        sleeper: &no_sleep/1
      )

    assert summary.status == :completed
    assert summary.waves_executed == 3
    assert summary.standing == "admitted"

    waves =
      campaign_ledger()
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.map(&Jason.decode!/1)
      |> Enum.filter(&(&1["event"] == "campaign_wave_done"))

    assert length(waves) == 3

    # FAIRNESS: each wave draws at least one item from every repo with
    # ready items. DETERMINISM: each wave draws the identical sequence.
    expected_sequence = [
      {"alpha", "a1"},
      {"beta", "b1"},
      {"gamma", "g1"},
      {"alpha", "a2"},
      {"beta", "b2"}
    ]

    for wave <- waves do
      assert Enum.map(wave["items"], &{&1["repo"], &1["item"]}) == expected_sequence
      assert Enum.uniq(Enum.map(wave["items"], & &1["repo"])) == ["alpha", "beta", "gamma"]
    end
  end

  test "a per-repo cap bounds one repo's draw without starving the others" do
    senser = profile_senser(%{"alpha" => ["a1", "a2", "a3"], "beta" => ["b1", "b2"]})

    assert {:ok, report} =
             run_loop(repo: "alpha,beta", senser: senser, repo_caps: %{"alpha" => 1}, capacity: 2)

    # alpha capped to 1 item this wave; beta uncapped; round-robin order.
    assert report["backlog"] == [
             %{"item" => "a1", "repo" => "alpha"},
             %{"item" => "b1", "repo" => "beta"},
             %{"item" => "b2", "repo" => "beta"}
           ]

    assert report["standing"] == "ALIVE"
    assert length(report["merged"]) == 3
  end

  test "SINGLE-REPO REGRESSION: a one-alias wave emits the historical artifact shapes (no repo tags)" do
    # Re-register ONLY aps, exactly as every pre-multi-repo test saw it.
    Application.put_env(:xaas, :ultracode_repos, %{
      "aps" => init_repo(Path.join(mktmp("aps"), "aps"))
    })

    senser = profile_senser(%{"aps" => ["s1"]})

    assert {:ok, report} = run_loop(senser: senser, capacity: 1)

    # Historical report shape: no multi-repo keys, no per-item tags.
    refute Map.has_key?(report, "repos")
    refute Map.has_key?(report, "integrations")
    refute Map.has_key?(report, "base_shas")
    assert report["repo"] == "aps"
    assert report["backlog"] == ["s1"]

    assert [%{"status" => "done"} = item] = report["items"]
    refute Map.has_key?(item, "repo")

    assert report["integration"]["branch"] =~ ~r/^aps-autonomic-[0-9a-f]{6}$/
    assert Path.basename(report["integration"]["worktree"]) =~ ~r/^aps-integration-/
    assert report["canonical"]["status"] == "pass"
    assert report["standing"] == "ALIVE"

    # Historical ledger shapes: start carries exactly repo/base_sha/capacity;
    # sensed is the plain id list; worktree events carry no repo.
    lines = ledger_lines(report)

    assert MapSet.new(Map.keys(find_event(lines, "start")["data"])) ==
             MapSet.new(["repo", "base_sha", "capacity"])

    assert find_event(lines, "sensed")["data"] == %{"items" => ["s1"]}

    for wt <- Enum.filter(lines, &(&1["event"] == "worktree")) do
      refute Map.has_key?(wt["data"], "repo")
      assert Path.basename(wt["data"]["path"]) |> String.starts_with?("aps-")
    end

    # Historical dispatch surface: no repo tag on any Run, no repo in
    # tickets, no execution_repo_alias, historical subject prefix.
    for run <- Run |> Ash.read!(action: :read_unscoped, authorize?: false),
        run.provider == @provider do
      refute run.goal =~ "[repo:"
      refute Map.has_key?(run |> ticket_path() |> File.read!() |> Jason.decode!(), "repo")
      assert is_nil(run.execution_repo_alias)

      epoch =
        Epoch
        |> Ash.read!(action: :read_unscoped, authorize?: false)
        |> Enum.find(&(&1.run_id == run.id))

      assert epoch.exact_subject |> String.starts_with?("aps-autonomic:")
    end
  end

  test "typed refusals: unknown alias, empty-registry all, multi-repo base_sha, bad caps" do
    assert {:error, {:unknown_repo_alias, "ghost"}} = run_loop(repo: "ghost")

    assert {:error, {:bad_repo_caps, %{"alpha" => -1}}} =
             run_loop(repo: "alpha", repo_caps: %{"alpha" => -1})

    assert {:error, {:base_sha_requires_single_repo, sha}} =
             run_loop(repo: "alpha,beta", base_sha: String.duplicate("a", 40))

    assert is_binary(sha)

    Application.put_env(:xaas, :ultracode_repos, %{})
    assert {:error, :no_registered_repos} = run_loop(repo: "all")
  end

  test "determinism: the same registry state plans the identical sequence on every wave" do
    senser = profile_senser(%{"alpha" => ["a1", "a2"], "beta" => ["b1"]})

    assert {:ok, report1} = run_loop(repo: "alpha,beta", senser: senser)
    assert {:ok, report2} = run_loop(repo: "alpha,beta", senser: senser)

    assert report1["backlog"] == report2["backlog"]

    assert report1["backlog"] == [
             %{"item" => "a1", "repo" => "alpha"},
             %{"item" => "b1", "repo" => "beta"},
             %{"item" => "a2", "repo" => "alpha"}
           ]
  end

  # ------------------------------------------------------------------
  # Scripted collaborators
  # ------------------------------------------------------------------

  # A deterministic sensing profile: repo alias -> item ids, in that
  # repo's own stable order.
  defp profile_senser(spec) do
    fn repo, _worktree ->
      ids = Map.fetch!(spec, repo)
      {:ok, Enum.map(ids, fn id -> %{"id" => id, "goal" => "Resolve #{id} in #{repo}"} end)}
    end
  end

  # The scripted protocol client: really claims, edits, commits, and
  # closes through Xaas.Ultracode.Lease. Works on ANY repo because the
  # epoch carries its own worktree.
  defp scripted_worker do
    fn epoch, _ctx ->
      {:ok, claimed, token, _run} =
        Lease.claim_next(@provider, "scripted-#{String.slice(epoch.id, 0, 8)}",
          epoch_id: epoch.id
        )

      file = Path.join(claimed.worktree, "note-#{String.slice(epoch.id, 0, 8)}.txt")
      File.write!(file, "done\n")

      {_, 0} = System.cmd("git", ["-C", claimed.worktree, "add", "."], env: git_env())

      {_, 0} =
        System.cmd("git", ["-C", claimed.worktree, "commit", "-q", "-m", "work"], env: git_env())

      head = git(claimed.worktree, ["rev-parse", "HEAD"])

      {:ok, _epoch, _receipt} = Lease.close(token, head, :alive, %{"note" => "scripted"})

      :ok
    end
  end

  defp run_loop(opts) do
    Autonomic.run(
      Keyword.merge(
        [
          provider: @provider,
          suite: @suite,
          canonical_suite: @suite,
          worker: scripted_worker(),
          capacity: 3,
          max_attempts: 2
        ],
        opts
      )
    )
  end

  # ------------------------------------------------------------------
  # Evidence readers
  # ------------------------------------------------------------------

  defp ticket_path(run) do
    Path.join(Application.fetch_env!(:xaas, :ultracode_ticket_dir), "#{run.id}.json")
  end

  defp find_event(lines, event), do: Enum.find(lines, &(&1["event"] == event))

  defp ledger_lines(report) do
    report["receipt_path"]
    |> Path.dirname()
    |> Path.join("ledger.ndjson")
    |> File.stream!()
    |> Enum.map(&Jason.decode!/1)
  end

  defp campaign_ledger, do: Process.get(:multi_campaign_ledger)

  # ------------------------------------------------------------------
  # Fixtures
  # ------------------------------------------------------------------

  defp init_repo(dir) do
    File.mkdir_p!(dir)
    {_, 0} = System.cmd("git", ["-C", dir, "init", "-q"])
    File.write!(Path.join(dir, "README.md"), "seed #{Path.basename(dir)}\n")
    {_, 0} = System.cmd("git", ["-C", dir, "add", "."], env: git_env())
    {_, 0} = System.cmd("git", ["-C", dir, "commit", "-q", "-m", "seed"], env: git_env())
    dir
  end

  defp git_env do
    [
      {"GIT_AUTHOR_NAME", "scripted"},
      {"GIT_AUTHOR_EMAIL", "s@s"},
      {"GIT_COMMITTER_NAME", "scripted"},
      {"GIT_COMMITTER_EMAIL", "s@s"}
    ]
  end

  defp git(dir, args) do
    {out, 0} = System.cmd("git", ["-C", dir | args], stderr_to_stdout: true)
    String.trim(out)
  end

  defp mktmp(label) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "xaas-multi-repo-test-#{label}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)

    {out, 0} = System.cmd("sh", ["-c", ~s(cd "$1" && pwd -P), "sh", dir])
    String.trim(out)
  end

  defp no_sleep(_ms), do: :ok
end
