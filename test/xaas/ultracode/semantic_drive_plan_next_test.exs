defmodule Xaas.Ultracode.SemanticDrivePlanNextTest do
  @moduledoc """
  Chicago qualification of plan-next (lane X3): the standing-progression
  FOND domain, the one real `AshA2A.Replan.Loop` run and its journaled
  PolicyCandidate.

  Every collaborator is real: the real `AshA2A.Replan.Loop` over the real
  `AshA2A.Replan.Port.AshPPlan` owner adapter and the real `AshPPlan`
  FOND synthesis/validation. Nothing is written anywhere -- `PlanNext` is
  pure, so the tests need no Postgres, no fabric and no graph side; the
  purity falsifier asserts that.
  """

  use ExUnit.Case, async: true

  alias Xaas.Ultracode.Ocel.Validator
  alias Xaas.Ultracode.SemanticDrive
  alias Xaas.Ultracode.SemanticDrive.Ocel
  alias Xaas.Ultracode.SemanticDrive.PlanNext

  @ports [{"ash_pplan", AshA2A.Replan.Port.AshPPlan}]

  # A full real-shape standing-transition event (the shape the drive's
  # plan_next_event/1 builds from ctx.transition + the sealed receipt).
  @event %{
    "identity" => "EP-A",
    "definition_digest" => "sha256:" <> String.duplicate("a", 64),
    "snapshot_digest" => "sha256:" <> String.duplicate("b", 64),
    "from" => "UNKNOWN",
    "to" => "PARTIAL_ALIVE",
    "receipt_digest" => "sha256:" <> String.duplicate("c", 64),
    "transition_digest" => "sha256:" <> String.duplicate("d", 64),
    "authority" => "NONE",
    "event_digest" => "sha256:" <> String.duplicate("e", 64)
  }

  describe "domain/1 -- the standing-progression projection" do
    test "UNKNOWN -> PARTIAL_ALIVE: the promote may stick (states, transitions, goals)" do
      assert {:ok, %AshPPlan.FOND{} = domain} =
               PlanNext.domain(%{"from" => "UNKNOWN", "to" => "PARTIAL_ALIVE"})

      assert domain.states == MapSet.new([:PARTIAL_ALIVE, :ALIVE])
      assert domain.goals == MapSet.new([:ALIVE])

      # promote may stick: [next(S), S]
      assert domain.transitions == %{PARTIAL_ALIVE: %{promote: [:ALIVE, :PARTIAL_ALIVE]}}
      assert :ok == AshPPlan.FOND.check(domain)
    end

    test "PARTIAL_ALIVE -> ALIVE: the initial state is the goal (empty policy domain)" do
      assert {:ok, %AshPPlan.FOND{} = domain} =
               PlanNext.domain(%{"from" => "PARTIAL_ALIVE", "to" => "ALIVE"})

      assert domain.states == MapSet.new([:ALIVE])
      assert domain.goals == MapSet.new([:ALIVE])
      assert domain.transitions == %{}
      assert :ok == AshPPlan.FOND.check(domain)
    end

    test "terminal `to` standings refuse: standing_not_progressable" do
      for to <- ["BLOCKED", "BUILD_BROKEN", "UNSUPPORTED"] do
        assert {:refused, :standing_not_progressable} =
                 PlanNext.domain(%{"from" => "PARTIAL_ALIVE", "to" => to})
      end
    end

    test "bogus standing strings refuse, never crash" do
      assert {:refused, :standing_not_progressable} =
               PlanNext.domain(%{"from" => "UNKNOWN", "to" => "TOTALLY_NOT_A_STANDING"})

      assert {:refused, :standing_not_progressable} =
               PlanNext.domain(%{"from" => "junk", "to" => "PARTIAL_ALIVE"})

      assert {:refused, :standing_not_progressable} = PlanNext.domain(%{"from" => "UNKNOWN"})
      assert {:refused, :standing_not_progressable} = PlanNext.domain(%{})
    end
  end

  describe "plan/2 -- one real replan loop, journaled as CANDIDATE" do
    test "emits the full candidate over the real Loop (promote-stick case, strong_cyclic)" do
      assert {:ok, doc} = PlanNext.plan(@event)

      assert doc["schema"] == "xaas/semantic-drive-plan-next/v1"
      assert doc["domain_source"] == "standing_progression_projection/1"
      assert doc["standing"] == "CANDIDATE"
      assert doc["emitted"] == true

      # source event fields ride the doc
      for field <- ~w(identity definition_digest snapshot_digest from to receipt_digest
                      transition_digest authority event_digest) do
        assert doc[field] == @event[field]
      end

      # rendered domain, JSON-able strings
      assert doc["domain"]["transitions"] == %{
               "PARTIAL_ALIVE" => %{"promote" => ["ALIVE", "PARTIAL_ALIVE"]}
             }

      assert doc["domain"]["initial"] == "PARTIAL_ALIVE"
      assert doc["domain"]["goals"] == ["ALIVE"]

      # the loop result: provider, FULL candidate, attempt, excluded, replay_key
      Code.ensure_loaded?(AshA2A.Replan.Port.AshPPlan)
      loop = doc["loop"]
      assert loop["provider"] == "ash_pplan"
      assert loop["attempt"] == 0
      assert loop["excluded"] == []
      assert is_binary(loop["replay_key"])

      candidate = loop["candidate"]
      assert candidate["formalism"] == "fond"
      assert candidate["authority"] == "none"
      assert candidate["standing"] == "candidate"
      assert candidate["subject"] == @event["identity"]
      # F-1: the promote-stick domain must validate strong_cyclic, never strong
      assert candidate["mode"] == "strong_cyclic"
      assert candidate["policy"] == %{"PARTIAL_ALIVE" => "promote"}
      assert candidate["validation"]["reachable_states"] == ["ALIVE", "PARTIAL_ALIVE"]
      assert is_binary(candidate["planner_subject"]["id"])
    end

    test "ALIVE case: the empty policy is :strong and the doc still journals a candidate" do
      assert {:ok, doc} = PlanNext.plan(%{@event | "from" => "PARTIAL_ALIVE", "to" => "ALIVE"})

      assert doc["emitted"] == true
      assert doc["domain"]["initial"] == "ALIVE"
      assert doc["domain"]["transitions"] == %{}
      assert doc["loop"]["candidate"]["mode"] == "strong"
      assert doc["loop"]["candidate"]["policy"] == %{}
      assert doc["loop"]["candidate"]["subject"] == @event["identity"]
    end

    test "replay_key recomputes (subject, provider, attempt)" do
      assert {:ok, doc} = PlanNext.plan(@event)
      loop = doc["loop"]

      expected =
        :crypto.hash(:sha256, :erlang.term_to_binary({@event["identity"], "ash_pplan", 0}))
        |> Base.encode16(case: :lower)

      assert loop["replay_key"] == expected
    end

    test "policy_binding_digest recomputes over the full binding (no-drift)" do
      assert {:ok, doc} = PlanNext.plan(@event)

      # Re-derive the same binding through the real collaborators: the same
      # domain, the same initial, the same Loop run -> an equal candidate.
      Code.ensure_loaded?(AshA2A.Replan.Port.AshPPlan)
      {:ok, %AshPPlan.FOND{} = domain} = PlanNext.domain(@event)
      initial = :PARTIAL_ALIVE

      {:ok, result} =
        AshA2A.Replan.Loop.run(
          @event["identity"],
          %{formalism: :fond, domain: domain, initial: initial},
          @ports,
          max_attempts: 3
        )

      binding = {@event, domain.transitions, initial, [:ALIVE], result.candidate}

      expected =
        :sha256
        |> :crypto.hash(:erlang.term_to_binary(binding, [:deterministic]))
        |> Base.encode16(case: :lower)

      assert doc["policy_binding_digest"] == expected
    end

    @tag :purity
    test "purity falsifier: plan/2 touches no file" do
      cwd = File.cwd!()
      before = cwd |> File.ls!() |> Enum.sort()

      assert {:ok, _doc} = PlanNext.plan(@event)
      assert {:ok, _doc} = PlanNext.plan(%{@event | "to" => "BLOCKED"})

      after_ls = cwd |> File.ls!() |> Enum.sort()
      assert after_ls == before
    end
  end

  describe "refusal journal path" do
    test "records the refusal as an observation, with no OCEL claim" do
      assert {:ok, doc} = PlanNext.plan(%{@event | "to" => "BLOCKED"})

      assert doc["standing"] == "REFUSED(standing_not_progressable)"
      assert doc["reason"] == "standing_not_progressable"
      assert doc["broken_term"] == "mu_on_O"
      assert doc["emitted"] == false
      assert doc["identity"] == @event["identity"]
      refute Map.has_key?(doc, "loop")
      refute Map.has_key?(doc, "candidate")
      refute Map.has_key?(doc, "policy_binding_digest")
    end

    test "bogus standing string journals the refusal without crashing" do
      assert {:ok, doc} = PlanNext.plan(%{@event | "to" => "gibberish"})
      assert doc["standing"] == "REFUSED(standing_not_progressable)"
      assert doc["emitted"] == false
    end
  end

  describe "drive surface (lane X3 falsifiers F-5/F-6)" do
    test "flag-off preservation: steps/0 carries no plan_next step" do
      assert SemanticDrive.steps() ==
               ~w(guard frontier_before order resolve sa2a descriptor contract materialize
                  actuate seal verify project reconcile frontier_after)a

      refute :plan_next in SemanticDrive.steps()
    end

    test "F-6: the PolicyCandidateEmitted class is declared and its court form validates" do
      assert "PolicyCandidateEmitted" in Ocel.extension_classes()

      event = %{
        type: "PolicyCandidateEmitted",
        time: DateTime.utc_now(),
        attributes: %{"identity" => "EP-A", "provider" => "ash_pplan"},
        relationships: [{"workorder:EP-A", "work-order"}, {"receipt:r1", "receipt"}]
      }

      observations =
        {[event],
         %{
           "workorder:EP-A" => %{type: "WorkOrder", attributes: %{}, relationships: []},
           "receipt:r1" => %{type: "Receipt", attributes: %{}, relationships: []}
         }}
      court = Ocel.court_form(observations, Ocel.event_classes() ++ ["PolicyCandidateEmitted"])
      standard = Ocel.standard_form(observations, Ocel.event_classes() ++ ["PolicyCandidateEmitted"])

      assert {:ok, %{"status" => "valid"}} = Validator.validate(court)
      assert Ocel.equivalent?(court, standard)

      # and the validator refuses the same event when the drive did NOT
      # declare the extension class (fail-closed, undeclared event type)
      undeclared = Ocel.court_form(observations)
      assert {:error, violations} = Validator.validate(undeclared)
      assert Enum.any?(violations, &String.contains?(&1.reason, "PolicyCandidateEmitted"))
    end
  end
end
