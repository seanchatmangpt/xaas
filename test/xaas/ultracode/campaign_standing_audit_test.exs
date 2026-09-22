defmodule Xaas.Ultracode.CampaignStandingAuditTest do
  @moduledoc """
  Chicago-style qualification of the RAISED campaign-end standing edge:
  the campaign row's terminal `standing` is `Xaas.Ultracode.Audit.judgment/2`'s
  -- the ONE §5 judgment law -- not a second, independent derivation from
  the wave receipts' coarse report standings (the divergence this closes:
  campaign 50762ec9 recorded row-standing `blocked` while its audit said
  PARTIAL_ALIVE with one named gap).

  Real sandboxed Postgres rows, real epochs/receipts through admitted
  edges, a real campaign ledger on disk, and the REAL `Campaign.start/1`
  discharge through the REAL bounded standing-audit worker (the sandbox
  ownership delegation in `Campaign.bounded_judgment/2` included). Only
  the wave runner (evidence-writing stub through the existing runner seam)
  and -- on the failure/timeout paths only -- the audit itself are
  injected.

  Covered law:

    * an all-alive campaign (real delivered items with head_verified
      receipts, all epochs terminal, OCEL court passing) completes ->
      row standing `:admitted`, `standing_source: "audit"`, no gaps on
      the terminal event;
    * a campaign whose EVIDENCE has a blocked item -- even though the
      wave REPORT said ALIVE -- completes -> row standing `:blocked`,
      the named gap carried on the `campaign_end` ledger event as
      `standing_gaps` (the coarse read alone would have said admitted);
    * an audit crash or audit timeout -> fail-OPEN to the coarse
      wave-standing derivation, error ledgered (`standing_audit_error`),
      and the loop is BOUNDED, never hung (wall-clock asserted);
    * ONE law, two faces: the morning-after face names a non-terminal
      row; the closing face (campaign-end) evaluates the row half
      against the `:completed` being certified, with every other half
      byte-identical.
  """

  use Xaas.DataCase, async: false

  alias Xaas.Ultracode.{Audit, Campaign, Epoch, Receipt, Run}

  @suite "aps-dod"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)

    # Campaign admission names a verifier suite on the Run row, so the
    # resource's real VerifierSuiteRegistered validation needs the suite
    # registered, exactly as dev.exs does for the operator.
    Application.put_env(:xaas, :ultracode_verifier_suites, %{
      @suite => %{steps: []}
    })

    # The campaign ledger resolves through the real `Campaign.campaign_dir/1`
    # seam -- point it at a VM-unique directory (the campaign_test tripwire:
    # $TMPDIR is shared across concurrently running `mix test` VMs).
    ticket_dir =
      Path.join(
        System.tmp_dir!(),
        "xaas-campaign-standing-audit-test-#{System.system_time(:millisecond)}-" <>
          "#{System.unique_integer([:positive])}"
      )

    Application.put_env(:xaas, :ultracode_ticket_dir, ticket_dir)

    on_exit(fn ->
      Application.delete_env(:xaas, :ultracode_verifier_suites)
      Application.delete_env(:xaas, :ultracode_ticket_dir)
      Application.delete_env(:xaas, :ultracode_standing_audit)
      Application.delete_env(:xaas, :ultracode_standing_audit_timeout_ms)
      File.rm_rf!(ticket_dir)
    end)

    :ok
  end

  # ------------------------------------------------------------------
  # Injected audits (failure paths only; the default seam is the real
  # `Xaas.Ultracode.Audit.judgment/2`)
  # ------------------------------------------------------------------

  defmodule StandingAuditCrashStub do
    @moduledoc false
    def judgment(_campaign_id, _opts), do: raise("standing audit crash injection")
  end

  defmodule StandingAuditSlowStub do
    @moduledoc false
    def judgment(_campaign_id, _opts), do: Process.sleep(5_000)
  end

  # ------------------------------------------------------------------
  # Fixtures: every write through a real Ash action
  # ------------------------------------------------------------------

  defp no_sleep(_ms), do: :ok

  # The wave runner seam, stubbed the way the REAL Autonomic runner writes:
  # it appends its attempt/item events to the campaign's own ledger
  # (`opts[:ledger]`) before returning its report.
  defp evidence_runner!(events) do
    fn opts ->
      path = Keyword.fetch!(opts, :ledger)

      Enum.each(events, fn event ->
        line = Jason.encode!(Map.put(event, "ts", iso())) <> "\n"
        File.write!(path, line, [:append])
      end)

      {:ok, %{"standing" => "ALIVE", "receipt_path" => "/tmp/fake-wave-receipt.json"}}
    end
  end

  defp wave_run! do
    Run
    |> Ash.Changeset.for_create(
      :create,
      %{goal: "standing-audit wave item run", provider: "zcode-standing-audit-test"},
      authorize?: false
    )
    |> Ash.create!()
  end

  defp epoch!(run_id, state) do
    initial_state = if state == :missed, do: :expected, else: :running

    epoch =
      Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{
          run_id: run_id,
          cycle: 0,
          exact_subject: "standing-audit:#{run_id}:#{System.unique_integer()}",
          state: initial_state
        },
        authorize?: false
      )
      |> Ash.create!()

    case state do
      :running ->
        epoch

      :completed ->
        epoch
        |> Ash.Changeset.for_update(:complete, %{final_head: "standing-audit-final-head"},
          authorize?: false
        )
        |> Ash.update!()

      :failed ->
        epoch
        |> Ash.Changeset.for_update(:mark_failed, %{}, authorize?: false)
        |> Ash.update!()

      :missed ->
        epoch
        |> Ash.Changeset.for_update(:mark_missed, %{}, authorize?: false)
        |> Ash.update!()
    end
  end

  defp alive_receipt!(epoch_id) do
    seal_receipt!(epoch_id, :alive, %{
      "head_verified" => true,
      "fabric_verifier" => %{"status" => "pass"}
    })
  end

  defp seal_receipt!(epoch_id, outcome, evidence) do
    Receipt
    |> Ash.Changeset.for_create(
      :seal,
      %{
        epoch_id: epoch_id,
        subject: "standing-audit-subject",
        outcome: outcome,
        evidence: evidence
      },
      authorize?: false
    )
    |> Ash.create!()
  end

  defp attempt_start(item, run, epoch) do
    %{
      "event" => "attempt_start",
      "data" => %{
        "item" => item,
        "attempt" => 1,
        "run_id" => run.id,
        "epoch_id" => epoch.id
      }
    }
  end

  defp item_done(item, epoch, receipt) do
    %{
      "event" => "item_done",
      "data" => %{
        "item" => item,
        "attempt" => 1,
        "epoch_id" => epoch.id,
        "receipt_id" => receipt.id,
        "accepted_via" => "alive"
      }
    }
  end

  defp item_blocked(item, attempts) do
    %{"event" => "item_blocked", "data" => %{"item" => item, "attempts" => attempts}}
  end

  defp iso, do: DateTime.to_iso8601(DateTime.utc_now())

  defp ledger_events!(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end

  # ------------------------------------------------------------------
  # The raised edge: the row's terminal standing is the audit's judgment
  # ------------------------------------------------------------------

  test "an all-alive campaign completes admitted, judged by the real audit" do
    delivered_a = wave_run!()
    delivered_b = wave_run!()
    # An attempt whose epoch terminal-failed with no item verdict: covered
    # by the (a) terminality census, never fabricated into (b) evidence.
    failed_attempt = wave_run!()

    epoch_a = epoch!(delivered_a.id, :completed)
    epoch_b = epoch!(delivered_b.id, :completed)
    epoch_failed = epoch!(failed_attempt.id, :failed)

    receipt_a = alive_receipt!(epoch_a.id)
    receipt_b = alive_receipt!(epoch_b.id)
    _refused = seal_receipt!(epoch_failed.id, :refused, %{"reason" => "audit"})

    {:ok, summary} =
      Campaign.start(
        capacity: 1,
        duration: "1h",
        wave_interval: "1s",
        max_waves: 1,
        runner:
          evidence_runner!([
            attempt_start("item-a", delivered_a, epoch_a),
            attempt_start("item-b", delivered_b, epoch_b),
            attempt_start("item-c", failed_attempt, epoch_failed),
            item_done("item-a", epoch_a, receipt_a),
            item_done("item-b", epoch_b, receipt_b)
          ]),
        sleeper: &no_sleep/1
      )

    assert summary.status == :completed
    assert summary.standing == "admitted"
    assert summary.standing_source == "audit"
    refute Map.has_key?(summary, :standing_gaps)
    refute Map.has_key?(summary, :standing_audit_error)

    campaign = Ash.get!(Run, summary.run_id, action: :read_unscoped, authorize?: false)
    assert campaign.state == :completed
    assert campaign.standing == :admitted

    end_event = summary.ledger |> ledger_events!() |> List.last()
    assert end_event["event"] == "campaign_end"
    assert end_event["standing"] == "admitted"
    assert end_event["standing_source"] == "audit"
    refute Map.has_key?(end_event, "standing_gaps")
  end

  test "a campaign with a blocked item completes blocked, its gap named on the terminal event" do
    delivered = wave_run!()
    exhausted = wave_run!()

    epoch_ok = epoch!(delivered.id, :completed)
    epoch_failed = epoch!(exhausted.id, :failed)

    receipt = alive_receipt!(epoch_ok.id)
    _refused = seal_receipt!(epoch_failed.id, :refused, %{"reason" => "worker_no_close"})

    # The wave REPORT says ALIVE -- the exact coarse reading that used to
    # become the row's standing on its own. The audit judges the evidence:
    # item-stuck never closed alive, so the row must complete :blocked
    # with the gap NAMED on the terminal event.
    {:ok, summary} =
      Campaign.start(
        capacity: 1,
        duration: "1h",
        wave_interval: "1s",
        max_waves: 1,
        runner:
          evidence_runner!([
            attempt_start("item-good", delivered, epoch_ok),
            item_done("item-good", epoch_ok, receipt),
            attempt_start("item-stuck", exhausted, epoch_failed),
            item_blocked("item-stuck", 2)
          ]),
        sleeper: &no_sleep/1
      )

    assert summary.status == :completed
    assert summary.standing == "blocked"
    assert summary.standing_source == "audit"

    assert summary.standing_gaps == [
             "wave 1: item item-stuck exhausted its attempts without an alive close (blocked)"
           ]

    campaign = Ash.get!(Run, summary.run_id, action: :read_unscoped, authorize?: false)
    assert campaign.state == :completed
    assert campaign.standing == :blocked

    end_event = summary.ledger |> ledger_events!() |> List.last()
    assert end_event["event"] == "campaign_end"
    assert end_event["standing"] == "blocked"

    assert end_event["standing_gaps"] == [
             "wave 1: item item-stuck exhausted its attempts without an alive close (blocked)"
           ]
  end

  # ------------------------------------------------------------------
  # Fail-open: audit crash / timeout -> the coarse derivation, error ledgered
  # ------------------------------------------------------------------

  test "an audit crash fails open to the coarse derivation with the error ledgered" do
    Application.put_env(:xaas, :ultracode_standing_audit, {StandingAuditCrashStub, :judgment})

    {:ok, summary} =
      Campaign.start(
        capacity: 1,
        duration: "1h",
        wave_interval: "1s",
        max_waves: 1,
        runner: evidence_runner!([]),
        sleeper: &no_sleep/1
      )

    # The historical coarse law speaks: every wave reported ALIVE, so the
    # row completes :admitted -- and the fallback is LEDGERED, never silent.
    assert summary.status == :completed
    assert summary.standing == "admitted"
    assert summary.standing_source == "coarse"
    assert summary.standing_audit_error =~ "audit crashed"

    campaign = Ash.get!(Run, summary.run_id, action: :read_unscoped, authorize?: false)
    assert campaign.state == :completed
    assert campaign.standing == :admitted

    end_event = summary.ledger |> ledger_events!() |> List.last()
    assert end_event["event"] == "campaign_end"
    assert end_event["standing_source"] == "coarse"
    assert end_event["standing_audit_error"] =~ "audit crashed"
  end

  test "an audit timeout fails open, bounded, with the error ledgered" do
    Application.put_env(:xaas, :ultracode_standing_audit, {StandingAuditSlowStub, :judgment})
    Application.put_env(:xaas, :ultracode_standing_audit_timeout_ms, 100)

    started_ms = System.monotonic_time(:millisecond)

    {:ok, summary} =
      Campaign.start(
        capacity: 1,
        duration: "1h",
        wave_interval: "1s",
        max_waves: 1,
        runner: evidence_runner!([]),
        sleeper: &no_sleep/1
      )

    elapsed_ms = System.monotonic_time(:millisecond) - started_ms

    # The 5s stub was killed at the 100ms bound: the loop was BOUNDED,
    # never hung on the audit.
    assert elapsed_ms < 5_000
    assert summary.status == :completed
    assert summary.standing == "admitted"
    assert summary.standing_source == "coarse"
    assert summary.standing_audit_error == "audit timed out after 100ms"

    end_event = summary.ledger |> ledger_events!() |> List.last()
    assert end_event["standing_audit_error"] == "audit timed out after 100ms"
  end

  # ------------------------------------------------------------------
  # ONE law, two faces (the :closing boundary lives inside the law module)
  # ------------------------------------------------------------------

  test "the morning-after face names a non-terminal row; the closing face certifies it" do
    campaign =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{
          goal: "#{Campaign.goal_marker()} standing-audit faces campaign",
          provider: "zcode-standing-audit-test",
          verifier_suite: @suite
        },
        authorize?: false
      )
      |> Ash.create!()
      |> Ash.Changeset.for_update(:transition_state, %{state: :running}, authorize?: false)
      |> Ash.update!()

    run = wave_run!()
    epoch = epoch!(run.id, :completed)
    receipt = alive_receipt!(epoch.id)

    path = Path.join(Campaign.campaign_dir(campaign.id), "ledger.ndjson")
    File.mkdir_p!(Path.dirname(path))

    File.write!(
      path,
      Enum.map_join(
        [
          %{"event" => "campaign_wave_start", "wave" => 1},
          attempt_start("item-a", run, epoch),
          item_done("item-a", epoch, receipt)
        ],
        "\n",
        &Jason.encode!/1
      ) <> "\n"
    )

    # Morning-after face (the mix task's): the observed :running row is a
    # named gap -- a non-terminal campaign is PARTIAL_ALIVE, never ALIVE.
    assert {:ok, morning_after} = Audit.judgment(campaign.id)
    assert morning_after.standing == :partial_alive

    assert morning_after.gaps == [
             "campaign row not terminal (state=running; expected completed|abandoned)"
           ]

    # Closing face (the campaign-end edge): the row's :running state is
    # the pre-image of the transition the judgment informs, so the row
    # half evaluates against the :completed being certified -- and with
    # the evidence fully alive, nothing else is a gap.
    assert {:ok, closing} = Audit.judgment(campaign.id, closing: true)
    assert closing.standing == :alive
    assert closing.gaps == []
    assert closing.per_wave != []
  end
end
