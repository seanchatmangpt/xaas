defmodule Xaas.Ultracode.RecoveryPolicyTest do
  # Chicago-style: the real ash_pplan FOND validator/synthesizer over the
  # real admitted domain; no doubles.
  use ExUnit.Case, async: true

  alias AshPPlan.FOND
  alias AshPPlan.FOND.Synthesis
  alias Xaas.Ultracode.{RecoveryPolicy, WaveLoop}

  # The pre-FOND chain law (v26.9.26), kept verbatim as the regression oracle.
  defp legacy_chain?(outcome, state_owes?, overloaded?) do
    outcome in [:worker_completed] and state_owes? and not overloaded?
  end

  test "the FOND policy decision is equivalent to the legacy chain law over every outcome" do
    outcomes = RecoveryPolicy.tick_outcomes() ++ [:some_unmodelled_outcome]

    for outcome <- outcomes, owes <- [true, false], overloaded <- [true, false] do
      assert WaveLoop.chain_decision(outcome, owes, overloaded) ==
               legacy_chain?(outcome, owes, overloaded),
             "divergence at #{inspect({outcome, owes, overloaded})}"
    end
  end

  test "the declared policy is strong-cyclic admissible and synthesis agrees it is solvable" do
    domain = RecoveryPolicy.domain()

    assert {:ok, report} =
             FOND.validate_policy(domain, RecoveryPolicy.policy(), :ready, :strong_cyclic)

    assert {:ok, synthesized} = Synthesis.synthesize(domain, :ready, :strong_cyclic)
    assert Map.fetch!(synthesized, :ready) == :dispatch
    assert is_map(report)
  end

  test "the admission receipt binds the exact policy digest" do
    receipt = RecoveryPolicy.receipt()
    assert receipt.mode == :strong_cyclic
    assert "sha256:" <> hex = receipt.policy_digest
    assert byte_size(hex) == 64
    assert receipt.validation
  end

  test "observe: overload dominates completion, unknown outcomes fail safe, complete halts" do
    assert RecoveryPolicy.decide(:worker_completed, true) == :backoff
    assert RecoveryPolicy.decide(:worker_completed, false) == :chain
    assert RecoveryPolicy.decide(:requeued, false) == :await_cron
    assert RecoveryPolicy.decide(:never_seen_before, false) == :await_cron
    assert RecoveryPolicy.decide(:complete, true) == :halt
  end

  describe "anti-vacuity: the admission gate refuses broken laws" do
    test "a policy missing a reachable outcome decision is refused" do
      broken = Map.delete(RecoveryPolicy.policy(), :requeued)

      assert {:error, _refusal} =
               FOND.validate_policy(RecoveryPolicy.domain(), broken, :ready, :strong_cyclic)
    end

    test "a policy naming an action the domain does not admit is refused" do
      broken = Map.put(RecoveryPolicy.policy(), :provider_open, :chain_anyway)

      assert {:error, _refusal} =
               FOND.validate_policy(RecoveryPolicy.domain(), broken, :ready, :strong_cyclic)
    end

    test "a domain whose recovery edge never returns to :ready is unsolvable" do
      {:ok, dead_end} =
        FOND.new(
          %{
            ready: %{dispatch: [:complete, :requeued]},
            requeued: %{await_cron: [:requeued]},
            complete: %{}
          },
          [:complete]
        )

      assert {:error, {:unsolvable, :strong_cyclic, witnesses}} =
               Synthesis.synthesize(dead_end, :ready, :strong_cyclic)

      assert :ready in witnesses
    end
  end
end
