defmodule Mix.Tasks.Xaas.Ultracode.AuditTest do
  @moduledoc """
  Chicago-style qualification of `mix xaas.ultracode.audit`'s judgment law
  over real sandboxed Postgres campaign state: real campaign/wave `Run`
  rows, real `Epoch` transitions through the resource's admitted edges,
  real sealed `Receipt`s (the alive-requires-court law included), and a
  real campaign ledger on disk -- the audit then reads it all back and
  its verdict is asserted.

  Covered judgment law (eight-hour-run §5, as narrowed by the operator's
  morning-command requirement):

    * terminality census -- non-terminal epochs and non-terminal campaign
      rows are named, per wave, with the exact state;
    * the head_verified requirement -- a delivered item whose receipt
      carries no `head_verified` evidence (or no receipt at all) is named;
    * PARTIAL_ALIVE naming -- exhausted-attempt items, the vacuous-census
      guard, and every failing part named in the standing line;
    * the (c) path runs the REAL `Xaas.Ultracode.OcelEgress` export +
      `Xaas.Ultracode.Ocel.Validator` court over the test rows, and a
      wave run absent from the DB is a refusal to judge
      (`{:error, _}` -> BLOCKED), never a verdict.

  The task's `BLOCKED` print path calls `System.halt(1)`, which is never
  triggered in-process (it would kill this very test VM) -- the same
  convention `Mix.Tasks.Xaas.RunValidateTaskTest` records; the judgment
  layer's `{:error, _}` returns are asserted directly instead.
  """

  use Xaas.DataCase, async: false

  alias Xaas.Ultracode.{Campaign, Epoch, Receipt, Run}
  alias Mix.Tasks.Xaas.Ultracode.Audit

  @suite "aps-dod"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)

    # The campaign row's real VerifierSuiteRegistered validation needs the
    # suite registered, exactly as dev.exs does for the operator.
    Application.put_env(:xaas, :ultracode_verifier_suites, %{
      @suite => %{steps: []}
    })

    # The audit resolves the campaign ledger through the real
    # `Campaign.campaign_dir/1` seam, which reads this env -- point it at a
    # VM-unique directory (the campaign_test tripwire: $TMPDIR is shared
    # across concurrently running `mix test` VMs).
    ticket_dir =
      Path.join(
        System.tmp_dir!(),
        "xaas-ultracode-audit-test-#{System.system_time(:millisecond)}-" <>
          "#{System.unique_integer([:positive])}"
      )

    Application.put_env(:xaas, :ultracode_ticket_dir, ticket_dir)

    on_exit(fn ->
      Application.delete_env(:xaas, :ultracode_verifier_suites)
      Application.delete_env(:xaas, :ultracode_ticket_dir)
      File.rm_rf!(ticket_dir)
    end)

    :ok
  end

  # ------------------------------------------------------------------
  # Fixtures: every write through a real Ash action
  # ------------------------------------------------------------------

  defp campaign!(state, opts \\ []) do
    run =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{
          goal: "#{Campaign.goal_marker()} audit qualification campaign",
          provider: "zcode-audit-test",
          verifier_suite: @suite
        },
        authorize?: false
      )
      |> Ash.create!()

    run =
      case state do
        :pending ->
          run

        :running ->
          run
          |> Ash.Changeset.for_update(:transition_state, %{state: :running}, authorize?: false)
          |> Ash.update!()

        other ->
          run
          |> Ash.Changeset.for_update(:transition_state, %{state: :running}, authorize?: false)
          |> Ash.update!()
          |> Ash.Changeset.for_update(:transition_state, %{state: other}, authorize?: false)
          |> Ash.update!()
      end

    if Keyword.get(opts, :cycle, 0) > 0 do
      run
      |> Ash.Changeset.for_update(:advance_cycle, %{}, authorize?: false)
      |> Ash.update!()
    else
      run
    end
  end

  defp wave_run! do
    Run
    |> Ash.Changeset.for_create(
      :create,
      %{goal: "audit wave item run", provider: "zcode-audit-test"},
      authorize?: false
    )
    |> Ash.create!()
  end

  defp epoch!(run_id, state) do
    initial_state = if state == :expected or state == :missed, do: :expected, else: :running

    epoch =
      Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{
          run_id: run_id,
          cycle: 0,
          exact_subject: "audit:#{run_id}:#{System.unique_integer()}",
          state: initial_state
        },
        authorize?: false
      )
      |> Ash.create!()

    case state do
      s when s in [:running, :expected] ->
        epoch

      :completed ->
        epoch
        |> Ash.Changeset.for_update(:complete, %{final_head: "audit-final-head"},
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
      %{epoch_id: epoch_id, subject: "audit-subject", outcome: outcome, evidence: evidence},
      authorize?: false
    )
    |> Ash.create!()
  end

  defp ledger_path(campaign_id) do
    Path.join(Campaign.campaign_dir(campaign_id), "ledger.ndjson")
  end

  defp write_ledger!(campaign_id, events) do
    path = ledger_path(campaign_id)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Enum.map_join(events, "\n", &Jason.encode!/1) <> "\n")
    path
  end

  defp wave_start(n) do
    %{"event" => "campaign_wave_start", "wave" => n, "ts" => iso()}
  end

  defp wave_done(n, standing) do
    %{"event" => "campaign_wave_done", "wave" => n, "standing" => standing, "ts" => iso()}
  end

  defp attempt_start(item, run, epoch, n \\ 1) do
    %{
      "event" => "attempt_start",
      "ts" => iso(),
      "data" => %{
        "item" => item,
        "attempt" => n,
        "run_id" => run.id,
        "epoch_id" => epoch.id
      }
    }
  end

  defp item_done(item, epoch, receipt, n \\ 1) do
    %{
      "event" => "item_done",
      "ts" => iso(),
      "data" => %{
        "item" => item,
        "attempt" => n,
        "epoch_id" => epoch.id,
        "receipt_id" => receipt.id,
        "accepted_via" => "alive"
      }
    }
  end

  defp item_blocked(item, attempts) do
    %{
      "event" => "item_blocked",
      "ts" => iso(),
      "data" => %{"item" => item, "attempts" => attempts}
    }
  end

  defp iso, do: DateTime.to_iso8601(DateTime.utc_now())

  # ------------------------------------------------------------------
  # ALIVE: (a)+(b)+(c) hold for every wave
  # ------------------------------------------------------------------

  test "an all-alive terminal campaign judges ALIVE, with the real OCEL court passing" do
    campaign = campaign!(:completed)

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

    write_ledger!(campaign.id, [
      wave_start(1),
      attempt_start("item-a", delivered_a, epoch_a),
      attempt_start("item-b", delivered_b, epoch_b),
      attempt_start("item-c", failed_attempt, epoch_failed),
      item_done("item-a", epoch_a, receipt_a),
      item_done("item-b", epoch_b, receipt_b),
      wave_done(1, "ALIVE")
    ])

    assert {:ok, report} = Audit.audit(campaign.id)
    assert report.verdict == :alive
    assert report.missing == []
    assert report.state == :completed

    assert [%{checks: %{a: :ok, b: :ok, c: :ok}} = wave] = report.waves
    assert wave.wave == 1
    assert wave.epochs == %{total: 3, terminal: 3}
    assert wave.items == %{done: 2, blocked: 0}
    assert wave.ocel == %{pass: 3, total: 3}
    assert wave.failures == []
  end

  # ------------------------------------------------------------------
  # (a) terminality census
  # ------------------------------------------------------------------

  test "non-terminal epochs are named per wave with their exact state" do
    campaign = campaign!(:completed)

    running_run = wave_run!()
    expected_run = wave_run!()
    terminal_run = wave_run!()

    epoch_running = epoch!(running_run.id, :running)
    epoch_expected = epoch!(expected_run.id, :expected)
    epoch_ok = epoch!(terminal_run.id, :completed)
    receipt = alive_receipt!(epoch_ok.id)

    write_ledger!(campaign.id, [
      wave_start(1),
      attempt_start("item-running", running_run, epoch_running),
      attempt_start("item-expected", expected_run, epoch_expected),
      attempt_start("item-ok", terminal_run, epoch_ok),
      item_done("item-ok", epoch_ok, receipt),
      wave_done(1, "PARTIAL_ALIVE")
    ])

    assert {:ok, report} = Audit.audit(campaign.id)
    assert {:partial_alive, [only]} = report.verdict
    assert only =~ "wave 1: non-terminal epoch census:"
    assert only =~ "#{epoch_running.id}(running)"
    assert only =~ "#{epoch_expected.id}(expected)"
    refute only =~ epoch_ok.id
    assert hd(report.waves).checks.a == :fail
    assert hd(report.waves).checks.b == :ok
    assert hd(report.waves).checks.c == :ok
  end

  test "a non-terminal campaign row is named" do
    campaign = campaign!(:running)

    run = wave_run!()
    epoch = epoch!(run.id, :completed)
    receipt = alive_receipt!(epoch.id)

    write_ledger!(campaign.id, [
      wave_start(1),
      attempt_start("item-a", run, epoch),
      item_done("item-a", epoch, receipt),
      wave_done(1, "ALIVE")
    ])

    assert {:ok, report} = Audit.audit(campaign.id)
    assert {:partial_alive, [only]} = report.verdict
    assert only == "campaign row not terminal (state=running; expected completed|abandoned)"
  end

  test "a terminal campaign whose waves executed but left no attempt census is named" do
    campaign = campaign!(:completed, cycle: 1)
    write_ledger!(campaign.id, [wave_start(1), wave_done(1, "ALIVE")])

    assert {:ok, report} = Audit.audit(campaign.id)
    assert {:partial_alive, [only]} = report.verdict
    assert only =~ "campaign executed 1 wave(s) but the ledger carries no attempt_start census"
  end

  # ------------------------------------------------------------------
  # (b) the head_verified requirement
  # ------------------------------------------------------------------

  test "a delivered item whose receipt carries no head_verified evidence is named" do
    campaign = campaign!(:completed)

    run = wave_run!()
    unverified_run = wave_run!()

    epoch = epoch!(run.id, :completed)
    unverified_epoch = epoch!(unverified_run.id, :completed)

    receipt = alive_receipt!(epoch.id)
    # A standing-family receipt WITHOUT the court's head verification:
    # exactly the §7 pollution the requirement exists for.
    unverified = seal_receipt!(unverified_epoch.id, :blocked, %{})

    write_ledger!(campaign.id, [
      wave_start(1),
      attempt_start("item-good", run, epoch),
      attempt_start("item-unverified", unverified_run, unverified_epoch),
      item_done("item-good", epoch, receipt),
      item_done("item-unverified", unverified_epoch, unverified),
      wave_done(1, "PARTIAL_ALIVE")
    ])

    assert {:ok, report} = Audit.audit(campaign.id)
    assert {:partial_alive, [only]} = report.verdict

    assert only =~
             "wave 1: item item-unverified: receipt #{unverified.id} carries no " <>
               "head_verified evidence (outcome blocked)"

    assert hd(report.waves).checks.b == :fail
    assert hd(report.waves).checks.a == :ok
    assert hd(report.waves).checks.c == :ok
  end

  test "a delivered item whose recorded receipt is missing from the epoch is named" do
    campaign = campaign!(:completed)

    run = wave_run!()
    epoch = epoch!(run.id, :completed)
    receipt = alive_receipt!(epoch.id)

    phantom = Ecto.UUID.generate()

    write_ledger!(campaign.id, [
      wave_start(1),
      attempt_start("item-a", run, epoch),
      item_done("item-a", epoch, %{id: phantom}),
      item_done("item-real", epoch, receipt),
      wave_done(1, "PARTIAL_ALIVE")
    ])

    assert {:ok, report} = Audit.audit(campaign.id)
    assert {:partial_alive, [only]} = report.verdict
    assert only =~ "wave 1: item item-a: receipt #{phantom} not found on epoch #{epoch.id}"
  end

  test "an item whose attempts were exhausted without an alive close is named" do
    campaign = campaign!(:completed)

    run = wave_run!()
    epoch = epoch!(run.id, :failed)
    _refused = seal_receipt!(epoch.id, :refused, %{"reason" => "worker_no_close"})

    write_ledger!(campaign.id, [
      wave_start(1),
      attempt_start("item-a", run, epoch, 1),
      attempt_start("item-a", run, epoch, 2),
      item_blocked("item-a", 2),
      wave_done(1, "PARTIAL_ALIVE")
    ])

    assert {:ok, report} = Audit.audit(campaign.id)
    assert {:partial_alive, [only]} = report.verdict

    assert only ==
             "wave 1: item item-a exhausted its attempts without an alive close (blocked)"

    assert hd(report.waves).checks.b == :fail
    assert hd(report.waves).checks.a == :ok
    assert hd(report.waves).checks.c == :ok
  end

  # ------------------------------------------------------------------
  # (c) OCEL conformance court wiring
  # ------------------------------------------------------------------

  test "a wave run absent from the DB is a refusal to judge, not a verdict" do
    campaign = campaign!(:completed)
    phantom_run_id = Ecto.UUID.generate()

    write_ledger!(campaign.id, [
      %{
        "event" => "campaign_wave_start",
        "wave" => 1,
        "ts" => iso()
      },
      %{
        "event" => "attempt_start",
        "ts" => iso(),
        "data" => %{
          "item" => "item-phantom",
          "attempt" => 1,
          "run_id" => phantom_run_id,
          "epoch_id" => Ecto.UUID.generate()
        }
      }
    ])

    assert {:error, {:ocel_export_failed, ^phantom_run_id, :run_not_found}} =
             Audit.audit(campaign.id)
  end

  # ------------------------------------------------------------------
  # Campaign resolution and ledger integrity
  # ------------------------------------------------------------------

  test "an unknown campaign id is a typed campaign_not_found" do
    assert {:error, :campaign_not_found} = Audit.audit(Ecto.UUID.generate())
  end

  test "a run row that is not a campaign is a typed not_a_campaign refusal" do
    plain =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "just a run", provider: "zcode-audit-test"},
        authorize?: false
      )
      |> Ash.create!()

    plain_id = plain.id

    assert {:error, {:not_a_campaign, ^plain_id}} = Audit.audit(plain_id)
  end

  test "a malformed ledger line is a typed malformed_ledger, never a silent skip" do
    campaign = campaign!(:completed)
    path = ledger_path(campaign.id)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Jason.encode!(wave_start(1)) <> "\n{not json}\n")

    assert {:error, {:malformed_ledger, ^path, 2, _reason}} = Audit.audit(campaign.id)
  end

  test "audit(nil) resolves the most recent campaign row" do
    older = campaign!(:completed)
    newer = campaign!(:abandoned)

    run = wave_run!()
    epoch = epoch!(run.id, :completed)
    receipt = alive_receipt!(epoch.id)

    write_ledger!(newer.id, [
      wave_start(1),
      attempt_start("item-a", run, epoch),
      item_done("item-a", epoch, receipt),
      wave_done(1, "ALIVE")
    ])

    # The older campaign has no ledger: its (b) items would be vacuous, so
    # a hit on the WRONG row would show up as a census gap, not an ALIVE.
    write_ledger!(older.id, [])

    assert {:ok, report} = Audit.audit(nil)
    assert report.run_id == newer.id
    assert report.verdict == :alive
  end

  # ------------------------------------------------------------------
  # The task surface (in-process; the BLOCKED halt path is observed
  # out-of-process only, per the moduledoc)
  # ------------------------------------------------------------------

  test "mix xaas.ultracode.audit --run prints per-wave (a)(b)(c) lines and the standing" do
    campaign = campaign!(:completed)

    run = wave_run!()
    epoch = epoch!(run.id, :completed)
    receipt = alive_receipt!(epoch.id)

    write_ledger!(campaign.id, [
      wave_start(1),
      attempt_start("item-a", run, epoch),
      item_done("item-a", epoch, receipt),
      wave_done(1, "ALIVE")
    ])

    output =
      ExUnit.CaptureIO.capture_io(:stdio, fn ->
        Mix.Task.rerun("xaas.ultracode.audit", ["--run", campaign.id])
      end)

    assert output =~ "campaign:   #{campaign.id} (state completed"

    assert output =~
             "wave 1:     (a) terminality 1/1 ok (1 run(s)) | (b) alive 1 done, 0 blocked ok | (c) ocel court 1/1 ok"

    assert output =~ "standing:   ALIVE"
  end

  test "the standing line names every failing part on the PARTIAL_ALIVE path" do
    campaign = campaign!(:running, cycle: 1)

    run = wave_run!()
    epoch = epoch!(run.id, :failed)
    _refused = seal_receipt!(epoch.id, :refused, %{})

    write_ledger!(campaign.id, [
      wave_start(1),
      attempt_start("item-a", run, epoch),
      item_blocked("item-a", 2)
    ])

    output =
      ExUnit.CaptureIO.capture_io(:stdio, fn ->
        Mix.Task.rerun("xaas.ultracode.audit", ["--run", campaign.id])
      end)

    assert output =~
             "wave 1:     (a) terminality 1/1 ok (1 run(s)) | (b) alive 0 done, 1 blocked fail | (c) ocel court 1/1 ok"

    assert output =~
             "standing:   PARTIAL_ALIVE (missing: campaign row not terminal " <>
               "(state=running; expected completed|abandoned); wave 1: item item-a exhausted " <>
               "its attempts without an alive close (blocked))"
  end
end
