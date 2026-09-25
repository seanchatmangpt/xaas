defmodule Xaas.Ultracode.LearnTest do
  @moduledoc """
  Qualification for `Xaas.Ultracode.Learn` -- the learning loop's core that
  turns VALIDATED OCEL 2.0 run logs plus the campaign ledger into the
  deterministic facts the projection side consumes.

  Chicago-style, per this repo's discipline: every fact flows through REAL
  production surfaces -- Runs/Epochs/Receipts written through real Ash
  actions into the sandboxed Postgres (`Run :create`/`:start`,
  `Epoch :start`/`:complete`/`:mark_failed`, `Receipt :seal`), real campaign
  ledgers written as ndjson files in a real tmp dir, and the REAL
  `OcelEgress.export_run/2` + `Ocel.Validator.validate_file/1` path for the
  fail-closed gate. The one seam is `campaign_facts/2`'s documented `:export`
  fault-injection opt, used by exactly one test to hand the REAL validator a
  corrupt "export" and prove the court refuses the whole analysis.
  """

  use ExUnit.Case, async: true

  require Ash.Query

  @moduletag :ultracode

  alias Xaas.Ultracode.{Learn, OcelEgress, Receipt, Run}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  # ------------------------------------------------------------------
  # The OCEL gate: valid campaign -> full facts; invalid OCEL -> refused
  # ------------------------------------------------------------------

  test "campaign_facts: a valid campaign yields the full contract facts" do
    dir = tmp_dir()

    # item-alpha: one attempt, closes alive.
    {run_a, epoch_a} = closed_run!("aps-autonomic:item-alpha#1:learn-run-a", :alive)

    # item-beta: attempt 1 is rate-limited (refused receipt), attempt 2 is
    # accepted via partial_alive.
    {run_b1, epoch_b1} =
      failed_run!("aps-autonomic:item-beta#1:learn-run-b1", :refused, %{
        "refusal_reason" => "provider_rate_limited"
      })

    {run_b2, epoch_b2} =
      closed_run!("aps-autonomic:item-beta#2:learn-run-b2", :partial_alive, %{
        "fabric_verifier" => %{"status" => "error"}
      })

    ledger =
      write_ledger!(dir, [
        campaign_start_event(),
        attempt_start("item-alpha", 1, run_a.id, epoch_a.id, ~U[2026-09-22T10:00:00Z]),
        attempt_start("item-beta", 1, run_b1.id, epoch_b1.id, ~U[2026-09-22T10:00:00Z]),
        worker_returned("item-alpha", 1, epoch_a.id, ":ok", ~U[2026-09-22T10:01:00Z]),
        worker_returned("item-beta", 1, epoch_b1.id, ":rate_limited", ~U[2026-09-22T10:00:30Z]),
        attempt_start("item-beta", 2, run_b2.id, epoch_b2.id, ~U[2026-09-22T10:02:00Z]),
        worker_returned("item-beta", 2, epoch_b2.id, ":ok", ~U[2026-09-22T10:03:30Z]),
        item_done("item-alpha", 1, epoch_a.id, "alive"),
        item_done("item-beta", 2, epoch_b2.id, "partial_alive"),
        reap(epoch_b1.id, ~U[2026-09-22T10:03:40Z]),
        final_event()
      ])

    assert {:ok,
            %{
              campaign_id: campaign_id,
              generated_at: %DateTime{} = _generated_at,
              ocel_valid: true,
              items: items,
              aggregate: aggregate,
              hints: hints
            }} = Learn.campaign_facts("learn-campaign-a", ledger: ledger)

    assert campaign_id == "learn-campaign-a"

    # Every item key, asserted (the contract surface E4 compiles against).
    assert [%{} = alpha, %{} = beta] = items

    assert %{
             item_id: "item-alpha",
             attempts: 1,
             final: :alive,
             court_verdicts: [:alive],
             failure_fingerprints: []
           } = alpha

    assert %{
             item_id: "item-beta",
             attempts: 2,
             final: :partial_alive,
             court_verdicts: [:refused, :partial_alive],
             failure_fingerprints: ["refused provider_rate_limited"]
           } = beta

    assert aggregate == %{
             attempts_total: 3,
             rate_limits: 1,
             reaps: 1,
             median_attempt_seconds: 60.0
           }

    # Hints ONLY for non-alive items.
    assert Map.keys(hints) == ["item-beta"]

    hint = Map.fetch!(hints, "item-beta")
    assert hint =~ "item=item-beta attempts=2 final=partial_alive"
    assert hint =~ "outcomes=rate_limited->ok"
    assert hint =~ "verdicts=refused,partial_alive"
    assert hint =~ "failures=refused provider_rate_limited"
    # Deterministic text: no wall-clock in the hint.
    refute hint =~ "2026-"
  end

  test "campaign_facts: one invalid OCEL export refuses the WHOLE analysis" do
    dir = tmp_dir()
    {run, epoch_c} = closed_run!("aps-autonomic:item-corrupt#1:learn-run-corrupt", :alive)

    ledger =
      write_ledger!(dir, [
        campaign_start_event(),
        attempt_start("item-corrupt", 1, run.id, epoch_c.id, ~U[2026-09-22T10:00:00Z]),
        worker_returned("item-corrupt", 1, epoch_c.id, ":ok", ~U[2026-09-22T10:00:10Z]),
        item_done("item-corrupt", 1, epoch_c.id, "alive")
      ])

    # The documented fault-injection seam: the REAL validator receives a
    # corrupt "export" (an undeclared event type).
    corrupt = fn run_id, tmp_dir ->
      with {:ok, path} <- OcelEgress.export_run(run_id, tmp_dir) do
        doc =
          path
          |> File.read!()
          |> JSON.decode!()
          |> Map.update!("ocel:events", fn events ->
            [
              %{
                "id" => "worker_launched:#{run_id}",
                "type" => "worker_launched",
                "time" => "2026-09-22T10:00:00Z",
                "attributes" => %{},
                "relationships" => []
              }
              | events
            ]
          end)

        File.write!(path, JSON.encode!(doc))
        {:ok, path}
      end
    end

    assert {:error, :ocel_invalid, violations} =
             Learn.campaign_facts("learn-campaign-corrupt", ledger: ledger, export: corrupt)

    assert [%{path: path, reason: reason} | _] = violations
    assert path =~ ~r{ocel:events\[\d+\]\.type}
    assert reason == "'worker_launched' not declared in ocel:eventTypes"
  end

  test "campaign_facts: a blocked item gets a hint carrying its fingerprints" do
    dir = tmp_dir()
    {run, epoch} = failed_run!("aps-autonomic:item-bravo#1:learn-run-bravo", :refused)

    rate_limit_error =
      "{:error, {:dispatch_failed, 1, \"ProviderBusinessError: [1302][Rate limit reached for requests]\"}}"

    ledger =
      write_ledger!(dir, [
        campaign_start_event(),
        attempt_start("item-bravo", 1, run.id, epoch.id, ~U[2026-09-22T11:00:00Z]),
        worker_returned("item-bravo", 1, epoch.id, rate_limit_error, ~U[2026-09-22T11:00:45Z]),
        reap(epoch.id, ~U[2026-09-22T11:00:46Z]),
        attempt_failed("item-bravo", 1, "worker ended without closing the lease"),
        item_blocked("item-bravo", 1)
      ])

    assert {:ok, facts} = Learn.campaign_facts("learn-campaign-bravo", ledger: ledger)

    assert [%{item_id: "item-bravo"} = item] = facts.items
    assert item.attempts == 1
    assert item.final == :blocked
    assert item.court_verdicts == [:refused]

    assert item.failure_fingerprints == [
             "refused worker_no_close",
             "worker ended without closing the lease"
           ]

    hint = Map.fetch!(facts.hints, "item-bravo")
    assert hint =~ "final=blocked"
    assert hint =~ "outcomes=rate_limited"
    assert hint =~ "verdicts=refused"
    assert hint =~ "refused worker_no_close"
    assert hint =~ "worker ended without closing the lease"
  end

  test "campaign_facts: an attempted item with no terminal ledger fact is :blocked" do
    dir = tmp_dir()
    {run, epoch} = closed_run!("aps-autonomic:item-nofinal#1:learn-run-nofinal", :alive)

    ledger =
      write_ledger!(dir, [
        campaign_start_event(),
        attempt_start("item-nofinal", 1, run.id, epoch.id, ~U[2026-09-22T10:00:00Z]),
        worker_returned("item-nofinal", 1, epoch.id, ":ok", ~U[2026-09-22T10:00:05Z])
      ])

    assert {:ok, facts} = Learn.campaign_facts("learn-campaign-nf", ledger: ledger)
    assert [%{final: :blocked, attempts: 1}] = facts.items
    assert facts.aggregate.attempts_total == 1
    assert facts.aggregate.median_attempt_seconds == 5.0
    # Nothing was proven not-standing for it beyond the missing terminal
    # fact, so it earns a hint (non-alive) with an empty failures segment.
    hint = Map.fetch!(facts.hints, "item-nofinal")
    assert hint == "item=item-nofinal attempts=1 final=blocked outcomes=ok verdicts=alive"
  end

  test "campaign_facts: fail-closed on a missing ledger, an empty ledger, and a corrupt line" do
    assert {:error, {:ledger_not_found, missing}} =
             Learn.campaign_facts("learn-campaign-missing",
               ledger: Path.join(tmp_dir(), "absent.ndjson")
             )

    assert missing =~ "absent.ndjson"

    # A ledger with no attempt_start events has nothing to learn from.
    empty = write_ledger!(tmp_dir(), [campaign_start_event()])
    assert {:error, :no_attempts} = Learn.campaign_facts("learn-campaign-empty", ledger: empty)

    # A corrupt line refuses the whole ledger (fail-closed, with location).
    # No DB rows are needed: the ledger is parsed before any export.
    path = Path.join(tmp_dir(), "corrupt.ndjson")
    File.mkdir_p!(Path.dirname(path))

    File.write!(
      path,
      Jason.encode!(campaign_start_event()) <> "\n" <> "{not json at all" <> "\n"
    )

    assert {:error, {:ledger_corrupt, 2, "{not json at all"}} =
             Learn.campaign_facts("learn-campaign-cl", ledger: path)
  end

  test "hints are deterministic: same input, byte-identical text" do
    dir = tmp_dir()
    {run, epoch} = failed_run!("aps-autonomic:item-delta#1:learn-run-delta", :refused)

    ledger =
      write_ledger!(dir, [
        campaign_start_event(),
        attempt_start("item-delta", 1, run.id, epoch.id, ~U[2026-09-22T12:00:00Z]),
        worker_returned("item-delta", 1, epoch.id, ":ok", ~U[2026-09-22T12:00:20Z]),
        attempt_failed("item-delta", 1, "worker ended without closing the lease"),
        item_blocked("item-delta", 1)
      ])

    assert {:ok, facts1} = Learn.campaign_facts("learn-campaign-delta", ledger: ledger)
    assert {:ok, facts2} = Learn.campaign_facts("learn-campaign-delta", ledger: ledger)

    assert facts1.hints == facts2.hints
    assert facts1.hints != %{}
    # generated_at is the only moment in the map, and it never enters a hint.
    assert DateTime.compare(facts1.generated_at, facts2.generated_at) != :eq
  end

  # ------------------------------------------------------------------
  # Single-run shape
  # ------------------------------------------------------------------

  test "run_facts: single-run shape with court diagnostics from the valid log's receipts" do
    subject = "aps-autonomic:item-gamma#1:learn-run-gamma"

    {_run, _epoch} =
      closed_run!(subject, :build_broken, %{
        "fabric_verifier" => %{
          "status" => "fail",
          "court_receipt" => %{
            "observation" => %{
              "failures" => [%{"id" => "CHI-ASSERT", "kind" => "fail"}],
              "gates" => [
                %{"id" => "CHI-MUTATION", "pass" => false},
                %{"id" => "CHI-ASSERT", "pass" => true}
              ]
            }
          }
        }
      })

    {:ok, [epoch]} = epochs_by_subject(subject)

    assert {:ok,
            %{
              campaign_id: run_id,
              ocel_valid: true,
              items: [item],
              aggregate: aggregate,
              hints: hints
            }} = Learn.run_facts(epoch.run_id)

    assert run_id == epoch.run_id

    assert %{
             item_id: "item-gamma",
             attempts: 1,
             final: :blocked,
             court_verdicts: [:build_broken],
             failure_fingerprints: ["CHI-ASSERT fail", "CHI-MUTATION fail"]
           } = item

    assert aggregate.attempts_total == 1
    assert aggregate.rate_limits == 0
    assert aggregate.reaps == 0
    assert is_float(aggregate.median_attempt_seconds)
    assert aggregate.median_attempt_seconds >= 0.0

    assert Map.keys(hints) == ["item-gamma"]
    assert Map.fetch!(hints, "item-gamma") =~ "failures=CHI-ASSERT fail | CHI-MUTATION fail"
  end

  test "run_facts: refuses a run that does not exist" do
    assert {:error, :run_not_found} =
             Learn.run_facts("00000000-0000-4000-8000-00000000dead")
  end

  # ------------------------------------------------------------------
  # Fingerprint normalization
  # ------------------------------------------------------------------

  test "fingerprint/1 strips paths and keeps gate, test name and reason class" do
    line =
      "court verdict fail (receipt outcome build_broken): CHI-ASSERT: " <>
        "tests/test_contract_actuation_intent.py::ActuationIntentContractTest." <>
        "test_schema_is_valid_draft202012: vacuous (no assertion)"

    assert Learn.fingerprint(line) ==
             "court verdict fail (receipt outcome build_broken): CHI-ASSERT: " <>
               "ActuationIntentContractTest.test_schema_is_valid_draft202012: " <>
               "vacuous (no assertion)"

    assert Learn.fingerprint(
             "failed: /Users/sac/xaas/worktrees/runs/aps-item-x-9d049f/ledger.ndjson: boom"
           ) == "failed: boom"

    # Same failure with a different worktree prefix -> same fingerprint.
    assert Learn.fingerprint("failed: /other/worktree/z/ledger.ndjson: boom") ==
             Learn.fingerprint("failed: /Users/sac/xaas/worktrees/runs/y/ledger.ndjson: boom")
  end

  # ------------------------------------------------------------------
  # Fixtures: real rows through real Ash actions, real ndjson ledgers
  # ------------------------------------------------------------------

  defp closed_run!(subject, outcome, evidence \\ alive_evidence()) do
    {run, epoch} = new_run!(subject)

    epoch =
      epoch
      |> Ash.Changeset.for_update(:start, %{}, authorize?: false)
      |> Ash.update!()

    epoch =
      epoch
      |> Ash.Changeset.for_update(:complete, %{final_head: "learn-final-head"}, authorize?: false)
      |> Ash.update!()

    _receipt = seal!(epoch, outcome, evidence)
    {run, epoch}
  end

  defp failed_run!(subject, outcome, evidence \\ %{"refusal_reason" => "worker_no_close"}) do
    {run, epoch} = new_run!(subject)

    epoch =
      epoch
      |> Ash.Changeset.for_update(:start, %{}, authorize?: false)
      |> Ash.update!()
      |> Ash.Changeset.for_update(:mark_failed, %{}, authorize?: false)
      |> Ash.update!()

    _receipt = seal!(epoch, outcome, evidence)
    {run, epoch}
  end

  # :alive requires the qualifying court (`AliveRequiresCourt` on `:seal`).
  defp alive_evidence,
    do: %{"head_verified" => true, "fabric_verifier" => %{"status" => "pass"}}

  defp seal!(epoch, outcome, evidence) do
    Receipt
    |> Ash.Changeset.for_create(
      :seal,
      %{
        epoch_id: epoch.id,
        subject: epoch.exact_subject,
        outcome: outcome,
        evidence: evidence,
        sealed_at: DateTime.utc_now()
      },
      authorize?: false
    )
    |> Ash.create!()
  end

  defp new_run!(subject) do
    run =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "Learn qualification.", provider: "zcode-learn-e2e"},
        authorize?: false
      )
      |> Ash.create!()

    run =
      run
      |> Ash.Changeset.for_update(:start, %{exact_subject: subject}, authorize?: false)
      |> Ash.update!()

    {:ok, [epoch]} = epochs_by_subject(subject)
    {run, epoch}
  end

  defp epochs_by_subject(subject) do
    Xaas.Ultracode.Epoch
    |> Ash.Query.for_read(:read_unscoped)
    |> Ash.Query.filter(exact_subject == ^subject)
    |> Ash.read(authorize?: false)
  end

  defp tmp_dir do
    dir = Path.join(System.tmp_dir!(), "xaas-learn-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    ExUnit.Callbacks.on_exit({__MODULE__, dir}, fn -> File.rm_rf(dir) end)
    dir
  end

  # Ledger event builders -- the exact shapes the campaign loop appends
  # (attempt-life events wrapped in "data"; campaign-level events flat).

  defp write_ledger!(dir, events) do
    path = Path.join(dir, "ledger.ndjson")
    File.mkdir_p!(dir)
    File.write!(path, Enum.map_join(events, "\n", &Jason.encode!/1) <> "\n")
    path
  end

  defp campaign_start_event do
    %{"event" => "campaign_start", "ts" => iso(~U[2026-09-22T09:59:00Z]), "repo" => "aps"}
  end

  defp attempt_start(item, attempt, run_id, epoch_id, ts) do
    %{
      "event" => "attempt_start",
      "ts" => iso(ts),
      "data" => %{
        "item" => item,
        "attempt" => attempt,
        "run_id" => run_id,
        "epoch_id" => epoch_id
      }
    }
  end

  defp worker_returned(item, attempt, epoch_id, result, ts) do
    %{
      "event" => "worker_returned",
      "ts" => iso(ts),
      "data" => %{
        "item" => item,
        "attempt" => attempt,
        "epoch_id" => epoch_id,
        "result" => result
      }
    }
  end

  defp item_done(item, attempt, epoch_id, accepted_via) do
    %{
      "event" => "item_done",
      "ts" => iso(~U[2026-09-22T10:05:00Z]),
      "data" => %{
        "item" => item,
        "attempt" => attempt,
        "epoch_id" => epoch_id,
        "accepted_via" => accepted_via
      }
    }
  end

  defp attempt_failed(item, attempt, failure) do
    %{
      "event" => "attempt_failed",
      "ts" => iso(~U[2026-09-22T11:00:50Z]),
      "data" => %{"item" => item, "attempt" => attempt, "failure" => failure}
    }
  end

  defp item_blocked(item, attempts) do
    %{
      "event" => "item_blocked",
      "ts" => iso(~U[2026-09-22T11:00:51Z]),
      "data" => %{"item" => item, "attempts" => attempts}
    }
  end

  defp reap(epoch_id, ts) do
    %{"event" => "reap", "ts" => iso(ts), "epoch_id" => epoch_id, "leased" => true}
  end

  defp final_event do
    %{"event" => "final", "ts" => iso(~U[2026-09-22T10:06:00Z]), "standing" => "PARTIAL_ALIVE"}
  end

  defp iso(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
end
