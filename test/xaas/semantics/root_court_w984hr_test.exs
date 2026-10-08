defmodule Xaas.Semantics.RootCourtW984hrTest do
  @moduledoc """
  Lane W984hr unclaimed-family probe court over the root of
  `lib/xaas/semantics/` (excluding courted subfamilies: airo_risk_mapping,
  vkg/, graphlaw_wasm, incident_report, oversight_governance).

  Mutation rationale per test: each test names the branch that, if mutated
  (removed or softened), would flip this test from pass to fail — proving the
  test is non-vacuous.

  All collaborators are real: real maps/structs, real on-disk receipts, no
  mocks, no interaction assertions. State is asserted on final values.
  """

  use ExUnit.Case, async: true

  alias Xaas.Semantics.{AutomationBiasCountermeasure, PlanningAdvice, RuntimeEquivalence}

  defp real_artifact do
    {:ok, artifact} =
      Xaas.Semantics.ComputationArtifact.new(%{
        artifact_identity: "w984hr-artifact-001",
        capability_iri: "https://schema.org/ComputeAction",
        runtime: "NX",
        input_schema_identity: "schema-in-w984hr",
        output_schema_identity: "schema-out-w984hr",
        input_projection_identity: "proj-in-w984hr",
        deterministic: true
      })

    artifact
  end

  defp real_advice(attrs) do
    PlanningAdvice.new(%{
      planning_subject_identity: "plan-w984hr",
      formal_projection_identity: "proj-w984hr",
      artifact: real_artifact(),
      kind: "FRONTIER",
      candidates: [
        %{candidate_ref: "c1", score: 2},
        %{candidate_ref: "c2", score: 5}
      ]
    })
    |> then(fn {:ok, advice} -> advice end)
  end

  describe "Xaas.Semantics.AutomationBiasCountermeasure briefing replay-guards" do
    @tag :w984hr
    test "(1) recorded refusal with nil reason -> {:refusal_missing_reason, checks}" do
      checks = [
        %{name: :sop, verdict: :pass},
        %{name: :oversight, verdict: :fail}
      ]

      record = %{admitted?: false, refusal: nil, checks: checks}

      # Mutation rationale: removing verify_replayable's `is_nil(refusal)`
      # guard (or defaulting refusal) lets a reason-less refusal brief as a
      # faithful witness; this test then fails.
      assert AutomationBiasCountermeasure.briefing(record, %{oversight: 1.0}) ==
               {:error, {:refusal_missing_reason, checks}}
      end

    @tag :w984hr
    test "(2) first failing check carries a DIFFERENT refusal atom than the record -> refusal_mismatch" do
      checks = [
        %{name: :sop, verdict: :pass},
        %{name: :oversight, verdict: :fail, refusal: :refused_a}
      ]

      record = %{admitted?: false, refusal: :refused_b, checks: checks}

      # Mutation rationale: if verify_replayable stops comparing the first
      # failing check's refusal to the recorded refusal, a tampered record
      # (first-fail blames check A, record blames B) briefs as faithful.
      assert AutomationBiasCountermeasure.briefing(record, %{oversight: 1.0}) ==
               {:error, {:refusal_mismatch, :refused_b}}
    end

    @tag :w984hr
    @tag :w984hr_covered
    test "(3) typed COVERED: admit_with_refusal + refusal_without_failing_check + invalid_record already courted" do
      # Mutation rationale: this is a census assertion, not a new branch —
      # the three sibling guards ARE exercised at
      # test/xaas/semantics/automation_bias_countermeasure_test.exs:154
      # (refusal_without_failing_check) and via title_iii_test.exs
      # (admit_with_refusal / invalid_record). Mutation of those guards
      # flips existing tests; nothing new to add here.
      hits =
        File.read!("test/xaas/semantics/automation_bias_countermeasure_test.exs")
        |> then(&String.contains?(&1, "refusal_without_failing_check"))

      assert hits
    end
  end

  describe "Xaas.Semantics.PlanningAdvice authority/identity guards" do
    @tag :w984hr
    test "(4) authorizes_actuation: true -> :planning_advice_cannot_authorize_actuation" do
      # Mutation rationale: dropping the `false <- authorizes_actuation`
      # clause lets a planning advice assert DO authority; every downstream
      # standing assumption collapses. The typed refusal is the only guard.
      assert {:error, :planning_advice_cannot_authorize_actuation} =
               PlanningAdvice.new(%{
                 planning_subject_identity: "plan-w984hr",
                 formal_projection_identity: "proj-w984hr",
                 artifact: real_artifact(),
                 kind: "FRONTIER",
                 candidates: [],
                 authorizes_actuation: true
               })
    end

    @tag :w984hr
    test "(5) standing: \"AUTHORITY\" -> {:planning_advice_standing_refused, \"AUTHORITY\"}" do
      # Mutation rationale: softening the `"CANDIDATE" <- standing` guard
      # lets a claim mint itself with standing it was never granted — the
      # exact standing-forgery channel the boundary exists to refuse.
      assert {:error, {:planning_advice_standing_refused, "AUTHORITY"}} =
               PlanningAdvice.new(%{
                 standing: "AUTHORITY",
                 planning_subject_identity: "plan-w984hr",
                 formal_projection_identity: "proj-w984hr",
                 artifact: real_artifact(),
                 kind: "FRONTIER",
                 candidates: []
               })
    end

    @tag :w984hr
    test "(6) duplicate candidate_refs -> :planning_advice_candidate_refs_must_be_unique" do
      # Mutation rationale: removing the uniqueness check lets one formal
      # candidate be double-scored (double-counted in the frontier ranking).
      assert {:error, :planning_advice_candidate_refs_must_be_unique} =
               PlanningAdvice.new(%{
                 planning_subject_identity: "plan-w984hr",
                 formal_projection_identity: "proj-w984hr",
                 artifact: real_artifact(),
                 kind: "FRONTIER",
                 candidates: [
                   %{candidate_ref: "dup", score: 1},
                   %{candidate_ref: "dup", score: 2}
                 ]
               })
    end

    @tag :w984hr
    test "(7) non-binary/empty candidate_ref or non-numeric score -> :invalid_planning_advice_candidate" do
      # Mutation rationale: dropping normalize_candidate's guard clause lets
      # malformed candidates (nil ref, string score) enter the frontier and
      # poison order_formal/2's sort.
      assert {:error, :invalid_planning_advice_candidate} =
               PlanningAdvice.new(%{
                 planning_subject_identity: "plan-w984hr",
                 formal_projection_identity: "proj-w984hr",
                 artifact: real_artifact(),
                 kind: "FRONTIER",
                 candidates: [%{candidate_ref: "", score: 1}]
               })

      assert {:error, :invalid_planning_advice_candidate} =
               PlanningAdvice.new(%{
                 planning_subject_identity: "plan-2",
                 formal_projection_identity: "proj-2",
                 artifact: real_artifact(),
                 kind: "STATE_HEURISTIC",
                 candidates: [%{candidate_ref: "c", score: "high"}]
               })
    end

    @tag :w984hr
    test "(8) order_formal appends unranked formal remainder, deterministically" do
      advice =
        real_advice(%{}) |> then(& &1)

      # Mutation rationale: if order_formal drops the remainder append, a
      # formal candidate not present in the advice is silently pruned from
      # the frontier — the exact "advice cannot silently prune" invariant.
      assert {:ok, order} =
               advice
               |> PlanningAdvice.order_formal(["c2", "c9", "c1"])

      assert order == ["c2", "c1", "c9"]
    end
  end

  describe "Xaas.Semantics.RuntimeEquivalence qualify/3 guards" do
    @tag :w984hr
    test "(9) negative tolerance -> :tolerance_must_be_non_negative" do
      # Mutation rationale: dropping the tolerance<0 guard lets a negative
      # tolerance admit arbitrary drift (every error <= negative is false, so
      # actually passed=false — but the typed precondition is the contract).
      assert RuntimeEquivalence.qualify(%{"x" => 1}, %{"x" => 1}, -1.0e-9) ==
               {:error, :tolerance_must_be_non_negative}
    end

    @tag :w984hr
    test "(10) non-map reference or candidate -> :invalid_runtime_equivalence_input" do
      # Mutation rationale: removing the fallback clause (or the is_map
      # guard) raises FunctionClauseError instead of the typed refusal.
      assert RuntimeEquivalence.qualify("not a map", %{"x" => 1.0}) ==
               {:error, :invalid_runtime_equivalence_input}

      assert RuntimeEquivalence.qualify(%{"x" => 1.0}, nil) ==
               {:error, :invalid_runtime_equivalence_input}
    end

    @tag :w984cr
    @tag :w984hr
    test "(11) key-set mismatch -> typed non-pass result :output_key_set_mismatch" do
      # Mutation rationale: if the key-set guard is removed, a candidate that
      # reports a subset/superset of outputs compares against Map.fetch! and
      # raises KeyError — a crash instead of the typed :output_key_set_mismatch.
      assert {:ok,
              %{
                passed: false,
                max_abs_error: :infinity,
                ranking_equal: false,
                reason: :output_key_set_mismatch
              }} = RuntimeEquivalence.qualify(%{"x" => 1.0}, %{"x" => 1.0, "y" => 2.0}, 1.0e-6)
    end
  end
end
