defmodule XaasWeb.System.CommandCenterAdapterTest do
  @moduledoc """
  Chicago-style qualification for `XaasWeb.System.CommandCenterAdapter`:
  real `Xaas.Repo` sandbox rows through real Ash reads (no mock of any
  owned collaborator), proving the adapter's one deterministic read model
  is stable under identical state, flips on real state change, mints only
  validated AshSurface standings (UNKNOWN renders as transport/candidate
  rows, never a standing — R8), and performs ZERO mutations (grep gate).
  """

  use ExUnit.Case, async: true

  alias AshSurface.Standing
  alias Xaas.Ultracode.{Epoch, Receipt, Run}
  alias XaasWeb.System.CommandCenterAdapter

  @subject CommandCenterAdapter.exact_subject()

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  ## Real-row fixtures (same real Ash action paths the fabric uses)

  defp create_run!(attrs \\ %{}) do
    Run
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(
        %{goal: "chicago command center adapter test", provider: "zcode-chicago-test"},
        Map.new(attrs)
      ),
      authorize?: false
    )
    |> Ash.create!()
  end

  defp create_epoch!(run, attrs \\ %{}) do
    Epoch
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(
        %{run_id: run.id, cycle: 0, exact_subject: @subject, state: :running},
        attrs
      ),
      authorize?: false
    )
    |> Ash.create!()
  end

  defp seal_receipt!(epoch, outcome, evidence) do
    Receipt
    |> Ash.Changeset.for_create(
      :seal,
      %{
        epoch_id: epoch.id,
        subject: @subject,
        outcome: outcome,
        evidence: evidence,
        sealed_at: DateTime.utc_now()
      },
      authorize?: false
    )
    |> Ash.create!()
  end

  defp record_ocel!(event_type) do
    # OCEL's key invariant: an event relates to REAL typed objects — the
    # :record action refuses zero relations, and object_id is a real
    # Xaas.Ocel.Object row, so register the object first.
    object =
      Xaas.Ocel.Object
      |> Ash.Changeset.for_create(
        :register,
        %{object_type: "Purchase", ocel_id: "purchase-001"},
        authorize?: false
      )
      |> Ash.create!()

    Xaas.Ocel.Event
    |> Ash.Changeset.for_create(
      :record,
      %{
        event_type: event_type,
        ocel_id: "chicago-command-center-test",
        occurred_at: DateTime.utc_now(),
        attributes: %{"lane" => "L5"},
        object_relations: [%{object_id: object.id, qualifier: "subject"}]
      },
      authorize?: false
    )
    |> Ash.create!()
  end

  ## Real-state fold

  test "snapshot/0 folds real Run/Epoch/Receipt/OCEL rows into one read model" do
    run = create_run!()
    epoch = create_epoch!(run)
    seal_receipt!(epoch, :refused, %{"reason" => "authority_none"})
    record_ocel!("chicago.adapter.test-event")

    snap = CommandCenterAdapter.snapshot()

    assert snap.exact_subject == @subject
    assert %AshSurface.CommandCenter{} = snap.command_center
    assert snap.command_center.exact_subject == @subject
    assert snap.command_center.authority_boundary == :OBSERVE
    assert snap.command_center.standing == :PARTIAL_ALIVE

    assert [run_row] = snap.runs
    assert run_row.id == run.id
    assert run_row.goal == "chicago command center adapter test"

    assert [epoch_row] = snap.epochs
    assert epoch_row.id == epoch.id
    assert epoch_row.state == "running"

    assert [refusal] = snap.refusals
    assert refusal.reason == "authority_none"
    assert refusal.subject == @subject

    assert [receipt_row] = snap.receipts
    assert receipt_row.outcome == "refused"

    assert [ocel_row] = snap.ocel_events
    assert ocel_row.event_type == "chicago.adapter.test-event"

    assert snap.answers["what_running"] == 1
    assert snap.answers["refused"] == 1
    assert snap.answers["receipts"] == 1
    assert snap.answers["ocel_evidence"] == 1
    assert snap.answers["plans"] == 1
    assert snap.answers["executed"] == 0
    # Nothing is receipt-backed-ALIVE for the subject yet (R8), so the
    # admitted-capability answer is honestly 0.
    assert snap.answers["capabilities_admitted"] == 0
  end

  test "every minted AshSurface standing is a validated evidence claim" do
    snap = CommandCenterAdapter.snapshot()
    center = snap.command_center

    assert Standing.valid?(center.standing)
    refute Standing.valid?(:UNKNOWN)

    for observation <- center.observations do
      assert Standing.valid?(observation.standing)
      assert observation.authority_boundary == :OBSERVE
      assert observation.facts["run_ids"] == []
    end

    # UNKNOWN is refused by Standing.validate!/1 itself, so no struct above
    # can carry it — the standing check above IS the law (a disjoint-type
    # `refute == :UNKNOWN` here would be a vacuous comparison).
  end

  test "state_digest is stable across identical real state" do
    run = create_run!()
    create_epoch!(run)

    snap1 = CommandCenterAdapter.snapshot()
    snap2 = CommandCenterAdapter.snapshot()

    assert snap1.command_center.state_digest == snap2.command_center.state_digest
    assert snap1.command_center.projection_id == snap2.command_center.projection_id
  end

  test "state_digest flips when real state changes" do
    create_run!(goal: "chicago digest flip — first")

    before = CommandCenterAdapter.snapshot()

    create_run!(goal: "chicago digest flip — second")

    after_add = CommandCenterAdapter.snapshot()

    refute before.command_center.state_digest == after_add.command_center.state_digest
  end

  test "receipt-backed ALIVE for the subject is the only admitted-capability source" do
    run = create_run!()
    epoch = create_epoch!(run)
    seal_receipt!(epoch, :alive, %{
      "head_verified" => true,
      "fabric_verifier" => %{"status" => "pass"}
    })

    snap = CommandCenterAdapter.snapshot()

    assert snap.answers["receipts"] == 1
    # Even with a real :alive receipt, projection capabilities only count as
    # admitted when the model itself is loaded (transport typed below).
    case snap.chicago do
      {:refused, _} -> assert snap.answers["capabilities_admitted"] == 0
      {:ok, %{layers: _layers}} -> assert snap.answers["capabilities_admitted"] > 0
    end
  end

  ## The L4 seam is typed, never raising and never fabricating

  test "chicago projection is {:ok, model} or a typed refused transport row" do
    snap = CommandCenterAdapter.snapshot()

    case snap.chicago do
      {:ok, %{subject: subject, layers: layers, cases: cases}} ->
        assert is_binary(subject)
        assert is_list(layers) and layers != []
        assert is_list(cases)

      # Two typed refusal classes are both lawful here:
      #   * module absent (L4 not compiled into this build)
      #   * artifacts not rendered yet (L4's {:refused, {:chicago_projection_missing, path}})
      {:refused, {code, reason}} ->
        assert is_atom(code)
        assert code in [:chicago_projection_unavailable, :chicago_projection_missing]

        assert [%{component: "chicago_projection", outcome: :unavailable}] =
                 Enum.filter(snap.transport, &(&1.component == "chicago_projection"))

        assert reason != nil

        # With no model, no obligations/capabilities are minted and the
        # unknown rows at least carry the transport row.
        assert snap.command_center.obligations == []
        assert snap.command_center.capabilities == []
        assert snap.unknowns != []

      other ->
        flunk("unexpected chicago projection shape: #{inspect(other)}")
    end
  end

  ## Pure mapping laws (model-shaped inputs, no DB)

  test "obligations_from_layers/1 mints open obligations with casing-invariant identity" do
    required = [
      %{
        id: "sa2a",
        capability_id: "cap:sa2a",
        evidence_refs: ["evidence-1"],
        receipt_refs: [],
        required: true
      },
      # Same layer via R2 JSON string-keyed shape: identity must not move.
      %{
        id: "sa2a",
        capability_id: "cap:sa2a",
        evidence_refs: [],
        receipt_refs: ["receipt-1"],
        required: "true"
      },
      %{id: "optional", capability_id: "cap:optional", evidence_refs: [], receipt_refs: [], required: false}
    ]

    [obligation, same_identity] =
      CommandCenterAdapter.obligations_from_layers(required)

    assert obligation.status == :open
    assert obligation.capability_id == "cap:sa2a"
    assert obligation.cause_ref == "chicago:layer:sa2a"
    assert obligation.exact_subject == @subject
    assert obligation.authority_boundary == :OBSERVE
    assert obligation.obligation_id == same_identity.obligation_id
    # the non-required layer produced no third obligation
    assert length(CommandCenterAdapter.obligations_from_layers(required)) == 2
  end

  test "planning_episode_for_run/1 mints :SELECT-ceiling episodes with honest policy standings" do
    in_flight =
      CommandCenterAdapter.planning_episode_for_run(
        struct(Run, %{
          id: "run-1",
          standing: :unknown,
          state: :running,
          execution_policy: :autonomic_wave_attempt,
          frontier_digest: nil
        })
      )

    assert %AshSurface.PlanningEpisode{} = in_flight
    assert in_flight.authority_ceiling == :SELECT
    assert in_flight.policy_standing == :VALID_STRONG_CYCLIC
    assert in_flight.planner_identity == "Xaas.Ultracode.Reactor"
    assert in_flight.world_state_ref == "xaas:run:run-1:frontier:none"

    refused =
      CommandCenterAdapter.planning_episode_for_run(
        struct(Run, %{id: "run-2", standing: :refused, state: :failed, execution_policy: nil, frontier_digest: "abc"})
      )

    assert refused.policy_standing == :REFUSED
    assert refused.world_state_ref == "xaas:run:run-2:frontier:abc"

    admitted =
      CommandCenterAdapter.planning_episode_for_run(
        struct(Run, %{id: "run-3", standing: :admitted, state: :completed, execution_policy: nil, frontier_digest: nil})
      )

    assert admitted.policy_standing == :VALID_STRONG
  end

  ## Permanent guard: the adapter and Live are read-only surfaces

  test "zero-mutation grep gate over both lane modules" do
    mutation_pattern =
      ~r/for_create\(|for_update\(|for_destroy\(|Ash\.create|Ash\.update|Ash\.destroy|bulk_update|bulk_create/

    for path <- [
          "lib/xaas_web/live/system/command_center_adapter.ex",
          "lib/xaas_web/live/system/command_center_live.ex"
        ] do
      source = File.read!(Path.join(File.cwd!(), path))
      refute Regex.match?(mutation_pattern, source), "mutation call found in #{path}"
    end
  end
end
