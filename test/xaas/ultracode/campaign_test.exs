defmodule Xaas.Ultracode.CampaignTest do
  @moduledoc """
  Chicago-style qualification of the 8-hour campaign launch path
  (`Xaas.Ultracode.Campaign` + `mix xaas.ultracode.start/status/stop`) over
  real sandboxed Postgres: real `Run` rows, real state-machine transitions
  (only edges `RunTransitionAllowed` admits), a real append-only campaign
  ledger, and real budget discharge. Every collaborator real except the
  wave runner, which is captured/substituted through a function seam -- the
  real default runner (`Xaas.Ultracode.Autonomic` via
  `config :xaas, :ultracode_wave_runner`) is subprocess-qualified separately
  in `Xaas.Ultracode.AutonomicTest`.
  """

  use Xaas.DataCase, async: false

  require Ash.Query

  alias Xaas.Ultracode.{Campaign, Epoch, Run}

  @suite "aps-dod"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)

    # Campaign admission names a verifier suite on the Run row, so the
    # resource's real VerifierSuiteRegistered validation needs the suite
    # registered, exactly as dev.exs does for the operator.
    Application.put_env(:xaas, :ultracode_verifier_suites, %{
      @suite => %{steps: []}
    })

    on_exit(fn ->
      Application.delete_env(:xaas, :ultracode_verifier_suites)
      Application.delete_env(:xaas, :ultracode_wave_runner)
    end)

    # PERMANENT TRIPWIRE (observed falsifier 2026-09-19, wave-8 flake hunt):
    # this ledger path used to be `System.unique_integer()`-qualified only.
    # unique_integer restarts per BEAM while $TMPDIR is shared by EVERY
    # concurrently running `mix test` VM on the machine, so two VMs picked the
    # SAME path (evidence: 114 of 444 on-disk ledger files contained events
    # from 2-5 distinct campaign_run_ids) and appended each other's campaign
    # events -- a foreign campaign_wave_done inflated `stub_calls()` ("left:
    # 3/4") and a foreign campaign_start's run id 404'd in this test's own
    # sandbox ("record not found" in the stop-during-wave test). Qualify every
    # per-run artifact path with wall clock + unique_integer (the
    # dispatch_test `run_uid` convention) so cross-VM collision is impossible,
    # and remove the directory afterwards.
    ledger_dir =
      Path.join(
        System.tmp_dir!(),
        "xaas-campaign-test-#{System.system_time(:millisecond)}-#{System.unique_integer([:positive])}"
      )

    ledger = Path.join(ledger_dir, "ledger.ndjson")

    Process.put(:campaign_ledger, ledger)

    on_exit(fn ->
      File.rm_rf!(ledger_dir)
    end)

    {:ok, ledger: ledger}
  end

  defp ledger, do: Process.get(:campaign_ledger)

  defp no_sleep(_ms), do: :ok

  defp stub_runner!(ref, standing \\ "ALIVE") do
    fn opts ->
      Agent.update(ref, fn calls -> [opts | calls] end)
      {:ok, %{"standing" => standing, "receipt_path" => "/tmp/fake-wave-receipt.json"}}
    end
  end

  defp runner_ref do
    {:ok, ref} = Agent.start_link(fn -> [] end)
    ref
  end

  defp wave_capacities(ref) do
    ref
    |> Agent.get(& &1)
    |> Enum.map(&Keyword.fetch!(&1, :capacity))
  end

  test "start creates the campaign row with the budget law and discharges it wave by wave" do
    ref = runner_ref()

    {:ok, summary} =
      Campaign.start(
        capacity: 3,
        duration: "2h",
        wave_interval: "1s",
        max_waves: 2,
        ledger: ledger(),
        runner: stub_runner!(ref),
        sleeper: &no_sleep/1
      )

    assert summary.status == :completed
    assert summary.waves_executed == 2
    assert summary.standing == "admitted"
    assert length(summary.waves) == 2
    assert Enum.map(summary.waves, & &1.standing) == ["ALIVE", "ALIVE"]
    assert Enum.all?(summary.waves, &(&1.receipt == "/tmp/fake-wave-receipt.json"))

    campaign = Ash.get!(Run, summary.run_id, action: :read_unscoped, authorize?: false)
    assert campaign.state == :completed
    assert campaign.standing == :admitted
    assert campaign.cycle == 2
    assert campaign.max_cycles == 2
    assert campaign.provider == "zcode"
    assert campaign.verifier_suite == @suite
    assert String.starts_with?(campaign.goal, Campaign.goal_marker())
    # Wall-clock budget persisted at admission: ~2h from creation.
    assert DateTime.diff(campaign.deadline_at, campaign.inserted_at, :second) in 7190..7210

    # Every wave really got the capacity budget and the campaign ledger.
    assert stub_calls() == 2
    assert wave_capacities(ref) == [3, 3]

    # The ledger is the durable record: start + one done-line per wave + end.
    events = ledger_events(summary.ledger)

    assert %{"event" => "campaign_start", "capacity" => 3, "wave_budget" => 2} = hd(events)

    assert Enum.count(events, &(&1["event"] == "campaign_wave_done")) == 2
    assert List.last(events)["event"] == "campaign_end"
  end

  test "start refuses an unregistered verifier suite at admission (typed, runner never called)" do
    {:ok, ref} = Agent.start_link(fn -> :never end)

    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             Campaign.start(
               suite: "no-such-suite",
               duration: "1h",
               wave_interval: "10m",
               ledger: ledger(),
               runner: stub_runner!(ref),
               sleeper: &no_sleep/1
             )

    assert Exception.message(hd(errors)) =~ "unknown_verifier_suite"
    assert Agent.get(ref, & &1) == :never
  end

  test "start refuses a second campaign while one is running" do
    running = running_campaign_fixture!(max_cycles: 4)
    running_id = running.id
    ref = runner_ref()

    assert {:error, {:campaign_already_running, ^running_id}} =
             Campaign.start(
               duration: "1h",
               wave_interval: "10m",
               ledger: ledger(),
               runner: stub_runner!(ref),
               sleeper: &no_sleep/1
             )

    assert Agent.get(ref, & &1) == []
  end

  test "stop during a wave makes the loop exit at the next poll without further waves" do
    test = self()

    runner = fn _opts ->
      assert {:ok, _} = Campaign.stop(campaign_id())
      send(test, :wave_ran)
      {:ok, %{"standing" => "ALIVE", "receipt_path" => "/tmp/fake-wave-receipt.json"}}
    end

    {:ok, summary} =
      Campaign.start(
        duration: "1h",
        wave_interval: "1s",
        max_waves: 5,
        ledger: ledger(),
        runner: runner,
        sleeper: &no_sleep/1
      )

    assert_received :wave_ran
    assert summary.status == :stopped
    assert summary.waves_executed == 1
    assert summary.standing == "ALIVE"

    campaign = Ash.get!(Run, summary.run_id, action: :read_unscoped, authorize?: false)
    assert campaign.state == :abandoned
    assert campaign.cycle == 1
  end

  test "stop/1 abandons the most recent running campaign; repeats are typed errors" do
    running = running_campaign_fixture!(max_cycles: 4)

    {:ok, stopped} = Campaign.stop(nil)
    assert stopped.id == running.id
    assert stopped.state == :abandoned

    assert {:error, :no_campaign_found} = Campaign.stop(nil)
    assert {:error, {:campaign_not_running, _, :abandoned}} = Campaign.stop(running.id)
  end

  test "stop/1 refuses a non-campaign run (typed)" do
    plain =
      Run
      |> Ash.Changeset.for_create(:create, %{goal: "not a campaign"}, authorize?: false)
      |> Ash.create!()

    plain_id = plain.id

    assert {:error, {:not_a_campaign, ^plain_id}} = Campaign.stop(plain.id)
  end

  test "start --run resumes an in-flight campaign without repeating discharged waves" do
    campaign = running_campaign_fixture!(max_cycles: 2)
    # One wave already discharged before the restart.
    campaign = advance_cycle!(campaign)

    ref = runner_ref()

    {:ok, summary} =
      Campaign.start(
        run_id: campaign.id,
        wave_interval: "1s",
        ledger: ledger(),
        runner: stub_runner!(ref),
        sleeper: &no_sleep/1
      )

    assert summary.status == :completed
    assert summary.waves_executed == 2
    assert length(Agent.get(ref, & &1)) == 1

    reloaded = Ash.get!(Run, campaign.id, action: :read_unscoped, authorize?: false)
    assert reloaded.cycle == 2
    assert reloaded.state == :completed
    # Resume keeps the ORIGINAL admission deadline; it does not re-arm it.
    assert DateTime.compare(reloaded.deadline_at, campaign.deadline_at) == :eq
  end

  test "status reports the budget, the ledger digest, and fabric in-flight epochs" do
    campaign = running_campaign_fixture!(max_cycles: 4)
    campaign = advance_cycle!(campaign)

    # status/1 reads the campaign's CANONICAL ledger path (under
    # :ultracode_ticket_dir in dev; the tmp fallback in tests) -- write it there.
    ledger_path = Path.join(Campaign.campaign_dir(campaign.id), "ledger.ndjson")
    File.mkdir_p!(Path.dirname(ledger_path))

    File.write!(ledger_path, """
    {"ts": "2026-09-19T00:00:00Z", "event": "campaign_start", "capacity": 5}
    {"ts": "2026-09-19T00:01:00Z", "event": "campaign_wave_done", "wave": 1, "standing": "ALIVE", "receipt": "/tmp/r1.json", "items": []}
    {"ts": "2026-09-19T00:02:00Z", "event": "campaign_wave_failed", "wave": 2, "error": "backlog_failed boom"}
    """)

    epoch_run =
      Run
      |> Ash.Changeset.for_create(:create, %{goal: "status epoch host", provider: "zcode"},
        authorize?: false
      )
      |> Ash.create!()

    # The in-flight count is fabric-wide by design (that is the number the
    # keep-alive top-up compares against capacity), so the test DB's real
    # leftover :running epochs are visible. Assert the fixture's DELTA.
    {:ok, running_epochs_before} =
      Epoch
      |> Ash.Query.for_read(:read_unscoped)
      |> Ash.Query.filter(state == :running)
      |> Ash.read(authorize?: false)

    Epoch
    |> Ash.Changeset.for_create(
      :create,
      %{
        run_id: epoch_run.id,
        cycle: 0,
        exact_subject: "campaign-status-fixture",
        state: :running
      },
      authorize?: false
    )
    |> Ash.create!()

    {:ok, s} = Campaign.status(campaign.id)

    assert s.state == :running
    assert s.waves_executed == 1
    assert s.wave_budget == 4
    assert s.seconds_remaining > 0
    assert [%{wave: 1, standing: "ALIVE"}, %{wave: 2, standing: nil, error: err}] = s.waves
    assert err =~ "backlog_failed"
    assert s.in_flight.total == length(running_epochs_before) + 1
    assert s.in_flight.unleased >= 1
    assert s.ledger == ledger_path
    assert s.ledger_present
  end

  test "status/stop with no campaigns in the DB is a typed error, never a guess" do
    assert {:error, :no_campaign_found} = Campaign.status(nil)
    assert {:error, :no_campaign_found} = Campaign.stop(nil)
  end

  test "the canonical court follows the waved repo, never another repo's gates" do
    ref = runner_ref()

    Application.put_env(:xaas, :ultracode_verifier_suites, %{
      @suite => %{steps: []},
      "spr-dod" => %{steps: []}
    })

    # A non-default repo waves its OWN suite at the integration head: falling
    # back to the Autonomic default (`aps-canonical`) would judge an SPR merge
    # with APS's five gates -- a court that was never its definition of done.
    {:ok, summary} =
      Campaign.start(
        capacity: 1,
        duration: "1h",
        wave_interval: "1s",
        max_waves: 1,
        repo: "spr",
        suite: "spr-dod",
        ledger: ledger(),
        runner: stub_runner!(ref),
        sleeper: &no_sleep/1
      )

    assert summary.status == :completed
    assert [spr_opts] = Agent.get(ref, & &1)
    assert spr_opts[:repo] == "spr"
    assert spr_opts[:suite] == "spr-dod"
    assert spr_opts[:canonical_suite] == "spr-dod"

    ref2 = runner_ref()

    # The default repo keeps its separate canonical suite (unchanged law).
    {:ok, _} =
      Campaign.start(
        capacity: 1,
        duration: "1h",
        wave_interval: "1s",
        max_waves: 1,
        ledger: ledger(),
        runner: stub_runner!(ref2),
        sleeper: &no_sleep/1
      )

    assert [aps_opts] = Agent.get(ref2, & &1)
    assert aps_opts[:repo] == "aps"
    assert aps_opts[:canonical_suite] == "aps-canonical"

    ref3 = runner_ref()

    # An explicit operator override always wins.
    {:ok, _} =
      Campaign.start(
        capacity: 1,
        duration: "1h",
        wave_interval: "1s",
        max_waves: 1,
        repo: "spr",
        suite: "spr-dod",
        canonical_suite: "aps-canonical",
        ledger: ledger(),
        runner: stub_runner!(ref3),
        sleeper: &no_sleep/1
      )

    assert [override_opts] = Agent.get(ref3, & &1)
    assert override_opts[:canonical_suite] == "aps-canonical"
  end

  test "a multi-repo spec launches spec-carrying waves without single-repo suite overrides" do
    ref = runner_ref()

    {:ok, summary} =
      Campaign.start(
        capacity: 5,
        duration: "1h",
        wave_interval: "1s",
        max_waves: 2,
        repo: "nounverb,eds,aps",
        ledger: ledger(),
        runner: stub_runner!(ref),
        sleeper: &no_sleep/1
      )

    assert summary.status == :completed
    assert summary.waves_executed == 2

    waves = Agent.get(ref, & &1)

    # The SPEC rides into every wave verbatim; the loop (not the campaign)
    # resolves registry membership per wave.
    assert Enum.all?(waves, &(&1[:repo] == "nounverb,eds,aps"))

    # One suite override would be AMBIGUOUS across repos: multi-repo waves
    # carry no --suite/--canonical-suite; each repo is judged by its own
    # registry suites inside the loop.
    assert Enum.all?(waves, &(&1[:suite] == nil and &1[:canonical_suite] == nil))

    # The admission-time facts are on the ledger: the campaign_start event
    # names the spec's repos.
    start = Enum.find(ledger_events(ledger()), &(&1["event"] == "campaign_start"))
    assert start["repo"] == "nounverb,eds,aps"
    assert start["repos"] == ["aps", "eds", "nounverb"]

    campaign = Ash.get!(Run, summary.run_id, action: :read_unscoped, authorize?: false)
    # The row's suite is admission metadata: the FIRST sorted alias's registry
    # suite (unresolvable in this test env -> the historical default).
    assert campaign.verifier_suite == @suite
  end

  test "a malformed repo spec is refused at admission (typed, before any campaign row exists)" do
    ref = runner_ref()

    assert {:error, {:bad_repo_spec, "aps,"}} =
             Campaign.start(
               capacity: 5,
               duration: "1h",
               wave_interval: "1s",
               repo: "aps,",
               ledger: ledger(),
               runner: stub_runner!(ref),
               sleeper: &no_sleep/1
             )

    assert [] = Agent.get(ref, & &1)

    assert {:error, :no_campaign_found} = Campaign.status(nil)
  end

  describe "parse_duration/1" do
    test "accepts strict <n>h|m|s" do
      assert Campaign.parse_duration("8h") == {:ok, 28_800}
      assert Campaign.parse_duration("30m") == {:ok, 1_800}
      assert Campaign.parse_duration("600s") == {:ok, 600}
    end

    test "refuses anything else (typed)" do
      assert {:error, {:bad_duration, "8H"}} = Campaign.parse_duration("8H")
      assert {:error, {:bad_duration, "8"}} = Campaign.parse_duration("8")
      assert {:error, {:bad_duration, "0m"}} = Campaign.parse_duration("0m")
      assert {:error, {:bad_duration, "-5m"}} = Campaign.parse_duration("-5m")
      assert {:error, {:bad_duration, nil}} = Campaign.parse_duration(nil)
    end
  end

  describe "past?/2 (the Kernel->= on DateTime tripwire)" do
    test "the exact observed falsifier: earlier wall clock with larger microsecond is NOT past a later deadline" do
      # 2026-09-20 smoke: campaign finished instantly because
      # `07:57:43.809677 >= 07:59:43.721198` structurally compared the
      # microsecond tuples first. Pin the chronological answer.
      now = ~U[2026-09-20 07:57:43.809677Z]
      deadline = ~U[2026-09-20 07:59:43.721198Z]

      refute Campaign.past?(now, deadline)
      assert Campaign.past?(deadline, now)
      assert Campaign.past?(now, now)
    end

    test "a campaign with future budget runs its waves (deterministic now that compare is used)" do
      ref = runner_ref()

      {:ok, summary} =
        Campaign.start(
          capacity: 1,
          duration: "1h",
          wave_interval: "1s",
          max_waves: 1,
          ledger: ledger(),
          runner: stub_runner!(ref, "ALIVE"),
          sleeper: &no_sleep/1
        )

      # Not the microsecond coin flip: wave 1 must actually run.
      assert summary.waves_executed == 1
      assert summary.standing == "admitted"
    end
  end

  # ------------------------------------------------------------------
  # fixtures + helpers
  # ------------------------------------------------------------------

  defp running_campaign_fixture!(max_cycles: max_cycles) do
    run =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{
          goal: "#{Campaign.goal_marker()} test campaign",
          provider: "zcode",
          verifier_suite: @suite,
          max_cycles: max_cycles,
          deadline_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        },
        authorize?: false
      )
      |> Ash.create!()

    run
    |> Ash.Changeset.for_update(:transition_state, %{state: :running}, authorize?: false)
    |> Ash.update!()
  end

  defp advance_cycle!(run) do
    run
    |> Ash.Changeset.for_update(:advance_cycle, %{}, authorize?: false)
    |> Ash.update!()
  end

  defp ledger_events(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end

  # The stop-during-wave test needs the campaign row id inside the runner,
  # but the id only exists after admission; the runner reads it from the
  # campaign ledger the loop writes right before calling it -- the same
  # file-based session state the law prefers over conversational memory.
  defp campaign_id do
    ledger_events(ledger())
    |> Enum.find(&(&1["event"] == "campaign_start"))
    |> Map.fetch!("campaign_run_id")
  end

  defp stub_calls,
    do: ledger_events(ledger()) |> Enum.count(&(&1["event"] == "campaign_wave_done"))
end
