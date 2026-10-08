defmodule Xaas.Eds.FamilyCourtW984htTest do
  @moduledoc """
  Lane W984ht unclaimed-family court for `Xaas.Eds` (ERC / EvidenceState /
  Falsifier). The three modules have dedicated qualification suites; this
  court exercises the state-bearing branches those suites leave unexercised.
  Chicago-style: real structs, real predicates, real SHA-256, zero mocks.
  """

  use ExUnit.Case, async: true

  alias Xaas.Eds.{EvidenceState, ExecutableResearchClaim, Falsifier}

  defp falsifier(id, predicate) do
    {:ok, f} =
      Falsifier.new(%{
        id: id,
        description: "family court falsifier #{id}",
        predicate: predicate
      })

    f
  end

  defp coverage_falsifier(id \\ "w984ht-coverage") do
    falsifier(id, fn evidence ->
      %{coverage_a: a, coverage_b: b} = Map.get(evidence, :observed_output, %{})
      if a > b, do: :survived, else: :falsified
    end)
  end

  defp claim(attrs) do
    {:ok, claim} =
      ExecutableResearchClaim.new(%{
        hypothesis: "Method A provides higher branch coverage than Method B",
        artifact_ref: "git:seanchatmangpt/xaas@w984ht:lib/xaas/eds",
        falsifiers: [coverage_falsifier()]
      })

    Map.merge(claim, Map.new(attrs))
  end

  describe "ExecutableResearchClaim.new/1 refusal branches left unexercised" do
    test "mutation rationale: kills mutants that swap require_binary/2 for Map.get/2 " <>
           "returning nil -- a blank artifact_ref must be refused, not silently minted" do
      assert {:error, message} =
               ExecutableResearchClaim.new(%{
                 hypothesis: "H",
                 artifact_ref: "   ",
                 falsifiers: [coverage_falsifier()]
               })

      assert message =~ "artifact_ref"
    end

    test "mutation rationale: kills mutants that drop the Enum.all?/2 Falsifier-struct " <>
           "check -- a non-Falsifier in the list must refuse, not smuggle into the claim" do
      assert {:error, message} =
               ExecutableResearchClaim.new(%{
                 hypothesis: "H",
                 artifact_ref: "git:repo@sha",
                 falsifiers: [%{id: "imposter", description: "not a struct"}]
               })

      assert message =~ "%Xaas.Eds.Falsifier{}"
    end
  end

  describe "claim-level evidence_state/1 lifecycle states the ERC suite never reaches" do
    test "mutation rationale: kills mutants that break the EvidenceState delegation " <>
           "for implemented/executable/verified -- the ERC suite only reaches " <>
           "proposed/observed/falsified through the claim" do
      c = claim(evidence: %{artifact_exists: true})
      assert ExecutableResearchClaim.evidence_state(c) == :implemented

      c = claim(evidence: %{artifact_exists: true, executed?: true})
      assert ExecutableResearchClaim.evidence_state(c) == :executable

      c =
        claim(
          evidence: %{
            artifact_exists: true,
            executed?: true,
            observed_output: %{exit_code: 0},
            verified?: true
          }
        )

      assert ExecutableResearchClaim.evidence_state(c) == :verified
    end

    test "mutation rationale: kills mutants that collapse non-independent reproduction " <>
           "into REPRODUCED at the claim level" do
      c =
        claim(
          evidence: %{
            artifact_exists: true,
            executed?: true,
            observed_output: %{exit_code: 0},
            verified?: true,
            reproduction_attempted?: true,
            reproduction_independent?: false,
            reproduction_result: :matched
          }
        )

      assert ExecutableResearchClaim.evidence_state(c) == :reproducible

      c =
        claim(
          evidence: %{
            artifact_exists: true,
            executed?: true,
            observed_output: %{exit_code: 0},
            verified?: true,
            reproduction_independent?: true,
            reproduction_result: :matched
          }
        )

      assert ExecutableResearchClaim.evidence_state(c) == :reproduced
    end
  end

  describe "fingerprint/1 identity surface" do
    test "mutation rationale: kills mutants that drop :protocol from the fingerprint " <>
           "payload -- a protocol change must move identity" do
      c1 = claim(protocol: "benchmark-v1")
      c2 = claim(protocol: "benchmark-v2")

      refute ExecutableResearchClaim.fingerprint(c1) ==
               ExecutableResearchClaim.fingerprint(c2)
    end

    test "mutation rationale: kills mutants that drop Enum.sort/1 on falsifier_ids -- " <>
           "falsifier order must not change identity" do
      f1 = coverage_falsifier("f-a")
      f2 = coverage_falsifier("f-b")

      c1 = claim(falsifiers: [f1, f2])
      c2 = claim(falsifiers: [f2, f1])

      assert ExecutableResearchClaim.fingerprint(c1) ==
               ExecutableResearchClaim.fingerprint(c2)
    end
  end

  describe "to_receipt_binding/1 honest-non-fabrication branches" do
    test "mutation rationale: kills mutants that fabricate observation_ids/actuation_identity " <>
           "when execution_identity is absent -- absence must project as [], nil, not invented data" do
      binding = claim([]) |> ExecutableResearchClaim.to_receipt_binding()

      assert binding.observation_ids == []
      assert binding.actuation_identity == nil
      assert is_binary(binding.consequence_identity)
    end

    test "mutation rationale: kills mutants that fabricate observation_ids when " <>
           "execution_identity lacks the :observation_ids key (non-list clause)" do
      binding = claim(execution_identity: %{env: "test"}) |> ExecutableResearchClaim.to_receipt_binding()

      assert binding.observation_ids == []
      assert is_binary(binding.actuation_identity)
    end
  end

  describe "run_falsifiers/1 mixed verdicts" do
    test "mutation rationale: kills mutants that short-circuit Enum.map/2 on the first " <>
           "non-:survived verdict -- per-falsifier verdicts must all be returned" do
      c =
        claim(
          falsifiers: [
            coverage_falsifier("passing"),
            falsifier("erroring", fn _ -> :garbage end)
          ],
          evidence: %{observed_output: %{coverage_a: 0.9, coverage_b: 0.1}}
        )

      verdicts = ExecutableResearchClaim.run_falsifiers(c)
      assert length(verdicts) == 2

      assert Enum.any?(verdicts, fn {f, v} -> f.id == "passing" and v == {:ok, :survived} end)
      assert Enum.any?(verdicts, fn {f, v} -> f.id == "erroring" and match?({:error, _}, v) end)
    end
  end

  describe "EvidenceState.classify/1 residual branches" do
    test "mutation rationale: kills mutants that weaken blocked_reason_present?/1 to " <>
           "Map.has_key?/2 -- a nil reason must not classify BLOCKED" do
      evidence = %{artifact_exists: true, blocked?: true, blocked_reason: nil}
      refute EvidenceState.classify(evidence) == :blocked
    end

    test "mutation rationale: pins that a SURVIVED falsifier_result does not override " <>
           "the spine -- falsified is the only overriding verdict" do
      evidence = %{
        artifact_exists: true,
        executed?: true,
        observed_output: %{exit_code: 0},
        falsifier_result: :survived
      }

      assert EvidenceState.classify(evidence) == :observed
    end
  end

  describe "EvidenceState.assert_non_collapse/3 off-spine states" do
    test "mutation rationale: probes the Enum.find miss branch -- :falsified passes the " <>
           "@states guard but has no rank in precedence_order/1; the result must never " <>
           "be :ok (a false admission of non-collapse)" do
      evidence = %{
        artifact_exists: true,
        executed?: true,
        observed_output: %{exit_code: 0},
        falsifier_result: :falsified
      }

      result = EvidenceState.assert_non_collapse(evidence, :falsified, :observed)
      refute result == :ok
    end
  end

  describe "Falsifier degenerate-input branches" do
    test "mutation rationale: kills mutants that drop the catch-all new/1 clause -- " <>
           "a non-map input must be refused, not raise" do
      assert {:error, message} = Falsifier.new("not a map")
      assert message =~ "requires"
    end

    test "mutation rationale: kills mutants that remove the run/2 is_map guard rescue -- " <>
           "non-map evidence must surface as a structured error, never an unrescued raise" do
      {:ok, f} = Falsifier.new(%{id: "f", description: "d", predicate: fn _ -> :survived end})

      assert {:error, "falsifier evidence must be a map"} = Falsifier.run(f, "not a map")
    end
  end
end
