defmodule Xaas.Eds.EvidenceStateTest do
  @moduledoc """
  Chicago-style qualification for `Xaas.Eds.EvidenceState` -- real pure
  classification over real evidence maps. No mocking: this module has no
  external collaborator to fake. Exercises the paper's central non-collapse
  invariant directly:

      implemented != executed != observed != verified != reproduced
  """

  use ExUnit.Case, async: true

  alias Xaas.Eds.EvidenceState

  describe "classify/1" do
    test "empty evidence is PROPOSED" do
      assert EvidenceState.classify(%{}) == :proposed
    end

    test "artifact exists but never executed is IMPLEMENTED, not EXECUTABLE or stronger" do
      evidence = %{artifact_exists: true}
      assert EvidenceState.classify(evidence) == :implemented
    end

    test "executed but no output captured is EXECUTABLE, not OBSERVED" do
      evidence = %{artifact_exists: true, executed?: true}
      assert EvidenceState.classify(evidence) == :executable
    end

    test "output observed but not verified is OBSERVED, not VERIFIED" do
      evidence = %{artifact_exists: true, executed?: true, observed_output: %{exit_code: 0}}
      assert EvidenceState.classify(evidence) == :observed
    end

    test "verified without any reproduction attempt is VERIFIED, not REPRODUCIBLE/REPRODUCED" do
      evidence = %{
        artifact_exists: true,
        executed?: true,
        observed_output: %{exit_code: 0},
        verified?: true
      }

      assert EvidenceState.classify(evidence) == :verified
    end

    test "reproduction attempted by the SAME party (not independent) is REPRODUCIBLE, not REPRODUCED" do
      evidence = %{
        artifact_exists: true,
        executed?: true,
        observed_output: %{exit_code: 0},
        verified?: true,
        reproduction_attempted?: true,
        reproduction_independent?: false,
        reproduction_result: :matched
      }

      assert EvidenceState.classify(evidence) == :reproducible
    end

    test "independent reproduction that matches is REPRODUCED" do
      evidence = %{
        artifact_exists: true,
        executed?: true,
        observed_output: %{exit_code: 0},
        verified?: true,
        reproduction_attempted?: true,
        reproduction_independent?: true,
        reproduction_result: :matched
      }

      assert EvidenceState.classify(evidence) == :reproduced
    end

    test "a falsifier that actually fired overrides everything else -- FALSIFIED, even with full evidence" do
      evidence = %{
        artifact_exists: true,
        executed?: true,
        observed_output: %{exit_code: 0},
        verified?: true,
        falsifier_result: :falsified
      }

      assert EvidenceState.classify(evidence) == :falsified
    end

    test "a real disclosed blocker with a reason is BLOCKED, regardless of other fields" do
      evidence = %{
        artifact_exists: true,
        blocked?: true,
        blocked_reason: "ex4pm sibling dependency unavailable"
      }

      assert EvidenceState.classify(evidence) == :blocked
    end

    test "blocked? true with an empty/missing reason does NOT get the honest BLOCKED classification" do
      # A caller claiming BLOCKED must actually name why -- this is the
      # mechanical half of "don't collapse an unexplained stall into a
      # named epistemic state."
      evidence = %{artifact_exists: true, blocked?: true, blocked_reason: ""}
      refute EvidenceState.classify(evidence) == :blocked
    end
  end

  describe "assert_non_collapse/3" do
    test "passes when the claim's evidence genuinely supports the stronger state" do
      evidence = %{artifact_exists: true, executed?: true, observed_output: %{}, verified?: true}
      assert EvidenceState.assert_non_collapse(evidence, :verified, :observed) == :ok
    end

    test "fails when evidence only supports a weaker state than asserted -- this is the core invariant" do
      # Evidence only reaches IMPLEMENTED; asserting VERIFIED must be refused.
      evidence = %{artifact_exists: true}

      assert {:error, message} = EvidenceState.assert_non_collapse(evidence, :verified, :observed)
      assert message =~ "only supports :implemented"
    end

    test "fails when the caller's ordering claim is itself wrong (weaker not actually weaker)" do
      evidence = %{artifact_exists: true, executed?: true, observed_output: %{}, verified?: true}
      assert {:error, _} = EvidenceState.assert_non_collapse(evidence, :observed, :verified)
    end
  end
end
