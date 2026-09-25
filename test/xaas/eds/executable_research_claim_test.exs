defmodule Xaas.Eds.ExecutableResearchClaimTest do
  @moduledoc """
  Chicago-style qualification for `Xaas.Eds.ExecutableResearchClaim`. No
  mocking: real struct construction, real falsifier execution, real SHA-256
  fingerprinting, real projection into `Xaas.CausalReceipt.ProcessReceipt`'s
  field shape (exercising a real cross-module boundary, not a faked one).
  """

  use ExUnit.Case, async: true

  alias Xaas.CausalReceipt.ProcessReceipt
  alias Xaas.Eds.{ExecutableResearchClaim, Falsifier}

  defp real_falsifier(id \\ "coverage-falsifier") do
    {:ok, f} =
      Falsifier.new(%{
        id: id,
        description: "Method A coverage must exceed Method B under the fixed benchmark",
        predicate: fn evidence ->
          %{coverage_a: a, coverage_b: b} = Map.get(evidence, :observed_output, %{})
          if a > b, do: :survived, else: :falsified
        end
      })

    f
  end

  describe "new/1" do
    test "constructs a real claim with a real falsifier" do
      assert {:ok, %ExecutableResearchClaim{} = claim} =
               ExecutableResearchClaim.new(%{
                 hypothesis:
                   "Method A provides higher nondeterministic branch coverage than Method B",
                 artifact_ref: "git:seanchatmangpt/xaas@d1f7f50:lib/xaas/eds",
                 falsifiers: [real_falsifier()]
               })

      assert claim.hypothesis =~ "Method A"
      assert ExecutableResearchClaim.evidence_state(claim) == :proposed
    end

    test "refuses a claim with zero falsifiers" do
      assert {:error, message} =
               ExecutableResearchClaim.new(%{
                 hypothesis: "some hypothesis",
                 artifact_ref: "git:some/repo@sha",
                 falsifiers: []
               })

      assert message =~ "at least one real"
    end

    test "refuses a claim missing a hypothesis" do
      assert {:error, message} =
               ExecutableResearchClaim.new(%{
                 artifact_ref: "git:some/repo@sha",
                 falsifiers: [real_falsifier()]
               })

      assert message =~ "hypothesis"
    end
  end

  describe "evidence_state/1 and run_falsifiers/1 over a real claim lifecycle" do
    setup do
      {:ok, claim} =
        ExecutableResearchClaim.new(%{
          hypothesis: "Method A provides higher nondeterministic branch coverage than Method B",
          artifact_ref: "git:seanchatmangpt/xaas@d1f7f50:lib/xaas/eds",
          falsifiers: [real_falsifier()]
        })

      %{claim: claim}
    end

    test "a freshly constructed claim is PROPOSED", %{claim: claim} do
      assert ExecutableResearchClaim.evidence_state(claim) == :proposed
    end

    test "adding real observed evidence that survives the falsifier reaches OBSERVED, not VERIFIED",
         %{claim: claim} do
      claim = %{
        claim
        | evidence: %{
            artifact_exists: true,
            executed?: true,
            observed_output: %{coverage_a: 0.91, coverage_b: 0.44}
          }
      }

      assert ExecutableResearchClaim.evidence_state(claim) == :observed

      [{_falsifier, verdict}] = ExecutableResearchClaim.run_falsifiers(claim)
      assert verdict == {:ok, :survived}
    end

    test "real evidence that trips the falsifier is FALSIFIED even if other fields look complete",
         %{claim: claim} do
      claim = %{
        claim
        | evidence: %{
            artifact_exists: true,
            executed?: true,
            observed_output: %{coverage_a: 0.2, coverage_b: 0.8},
            verified?: true,
            falsifier_result: :falsified
          }
      }

      assert ExecutableResearchClaim.evidence_state(claim) == :falsified
    end
  end

  describe "fingerprint/1" do
    test "is deterministic for identical claim content" do
      {:ok, claim1} =
        ExecutableResearchClaim.new(%{
          hypothesis: "H",
          artifact_ref: "git:repo@sha",
          falsifiers: [real_falsifier("f1")]
        })

      {:ok, claim2} =
        ExecutableResearchClaim.new(%{
          hypothesis: "H",
          artifact_ref: "git:repo@sha",
          falsifiers: [real_falsifier("f1")]
        })

      assert ExecutableResearchClaim.fingerprint(claim1) ==
               ExecutableResearchClaim.fingerprint(claim2)
    end

    test "differs for a genuinely different hypothesis" do
      {:ok, claim1} =
        ExecutableResearchClaim.new(%{
          hypothesis: "H1",
          artifact_ref: "git:repo@sha",
          falsifiers: [real_falsifier()]
        })

      {:ok, claim2} =
        ExecutableResearchClaim.new(%{
          hypothesis: "H2",
          artifact_ref: "git:repo@sha",
          falsifiers: [real_falsifier()]
        })

      refute ExecutableResearchClaim.fingerprint(claim1) ==
               ExecutableResearchClaim.fingerprint(claim2)
    end
  end

  describe "to_receipt_binding/1" do
    test "projects real, non-fabricated fields; caller must supply the rest for a valid ProcessReceipt" do
      {:ok, claim} =
        ExecutableResearchClaim.new(%{
          hypothesis: "H",
          artifact_ref: "git:repo@sha",
          falsifiers: [real_falsifier()],
          execution_identity: %{observation_ids: ["obs-1"]},
          evidence: %{artifact_exists: true, executed?: true, observed_output: %{ok: true}}
        })

      binding = ExecutableResearchClaim.to_receipt_binding(claim)

      assert binding.observation_ids == ["obs-1"]
      assert is_binary(binding.admitted_observation_hash)
      assert is_binary(binding.actuation_identity)
      assert is_binary(binding.consequence_identity)

      # Honest incompleteness: ontology_hash/valid_time/observation_time are
      # NOT fabricated by this projection, so feeding it straight into
      # ProcessReceipt.new/1 without supplying them is correctly refused --
      # not silently accepted as a complete receipt.
      assert {:error, {:incomplete_receipt, missing}} = ProcessReceipt.new(binding)
      assert :ontology_hash in missing
      assert :valid_time in missing
      assert :observation_time in missing
    end

    test "a fully supplemented binding produces a real, verifiable ProcessReceipt" do
      {:ok, claim} =
        ExecutableResearchClaim.new(%{
          hypothesis: "H",
          artifact_ref: "git:repo@sha",
          falsifiers: [real_falsifier()],
          execution_identity: %{observation_ids: ["obs-1"]},
          evidence: %{artifact_exists: true, executed?: true, observed_output: %{ok: true}}
        })

      binding =
        claim
        |> ExecutableResearchClaim.to_receipt_binding()
        |> Map.merge(%{
          ontology_hash: "ontology-hash-real",
          valid_time: ~U[2026-09-12 00:00:00Z],
          observation_time: ~U[2026-09-12 00:00:01Z]
        })

      assert {:ok, receipt} = ProcessReceipt.new(binding)
      assert {:ok, signed} = ProcessReceipt.sign(receipt)
      assert ProcessReceipt.verify(signed) == :ok
    end
  end
end
