defmodule Xaas.Deepening.Art144bCausalBriefingTest do
  @moduledoc """
  Lane W981t — evidenced-line deepening, corpus line **14.4.b** (Art. 14(4)(b),
  high-risk provider — automation-bias countermeasure).

  `test/xaas/semantics/automation_bias_countermeasure_test.exs` (w539) courts
  `briefing/2` over hand-built records; `art15_deepening_test.exs` courts the
  admission sweeps. The uncovered composition is the REAL causal chain: a
  real `Xaas.Semantics.DatasetAdmission` refusal flows through
  `Xaas.Semantics.Counterfactual` recording + replay and
  `Xaas.Semantics.AdmissionAttribution` exact Shapley blame into the
  operator briefing — and the briefing's refusal anatomy is verified to be
  *causal* (flipping the named check to :pass flips the decision via
  `Counterfactual.evaluate/3`), not merely descriptive.

  Mutation rationale: changing `AutomationBiasCountermeasure.refusal_anatomy/2`
  to return `[]` for refusals (or to name passing checks instead of failing
  ones) makes the anatomy-vs-counterfactual causality assertions fail while
  determinism/shape courts still pass — catching an anatomy that decorates
  rather than explains.

  Chicago discipline: real modules, deterministic seeded data, no mocks.
  """

  use ExUnit.Case, async: true

  # 14.4.b is an evidenced corpus line (w539) — eu_ai_act census.
  @moduletag :eu_ai_act

  alias Xaas.Semantics.AdmissionAttribution
  alias Xaas.Semantics.AutomationBiasCountermeasure
  alias Xaas.Semantics.Counterfactual
  alias Xaas.Semantics.DatasetAdmission

  # Deterministic skewed population: group A=0 at ~0, group A=1 at ~100 —
  # W1_proxy far above any epsilon. (Fixture shape from title_ii_deepening.)
  defp skewed_dataset do
    Enum.map(1..20, fn i ->
      [
        %{features: %{x: 0.0}, label: :ok, sensitive: 0},
        %{features: %{x: 100.0 + i * 0.1}, label: :ok, sensitive: 1}
      ]
    end)
    |> List.flatten()
  end

  # Two-check pipeline mirroring the real DatasetAdmission gate order:
  # completeness first, then the bias gate. Returns Counterfactual-shaped
  # checks (:ok | {:refused, reason}); shapley_checks/2 converts them to the
  # AdmissionAttribution shape (:pass | {:refuse, reason}).
  defp admission_checks(samples, opts) do
    completeness =
      fn _ ->
        if complete?(samples, Keyword.get(opts, :required_fields, [])),
          do: :ok,
          else: {:refused, :REFUSED_INCOMPLETE_DATASET}
      end

    bias = fn _ ->
      case DatasetAdmission.admit(samples, opts) do
        {:ok, :ADMITTED, _} -> :ok
        {:error, :REFUSED_EMPTY_DATASET} -> {:refused, :REFUSED_EMPTY_DATASET}
        {:error, {reason, _}} when is_atom(reason) -> {:refused, reason}
        {:error, reason} when is_atom(reason) -> {:refused, reason}
      end
    end

    [completeness: completeness, bias: bias]
  end

  defp shapley_checks(counterfactual_checks) do
    Enum.map(counterfactual_checks, fn {name, fun} ->
      {name,
       fn i ->
         case fun.(i) do
           :ok -> :pass
           {:refused, reason} -> {:refuse, reason}
         end
       end}
    end)
  end

  defp complete?(samples, []) when is_list(samples), do: samples != []
  defp complete?([], _), do: false

  defp complete?(samples, required) when is_list(required) do
    Enum.all?(samples, fn s ->
      Enum.all?(required, fn f -> Map.has_key?(s.features, f) end)
    end)
  end

  test "a real DatasetAdmission refusal produces a causal, replay-verified operator briefing" do
    samples = skewed_dataset()
    opts = [seed: 691, epsilon_bias: 0.1]
    checks = admission_checks(samples, opts)

    # The recorded decision over the real surface: refused by the bias gate.
    recorded = Counterfactual.run(samples, checks)
    assert {:refused, :REFUSED_BIAS_THRESHOLD} = recorded.outcome

    attributions = AdmissionAttribution.shapley(samples, shapley_checks(checks))
    assert is_map(attributions)
    assert Map.has_key?(attributions, :bias)
    assert Map.has_key?(attributions, :completeness)

    assert {:ok, briefing} =
             AutomationBiasCountermeasure.briefing(
               %{
                 input: samples,
                 admitted?: false,
                 refusal: :REFUSED_BIAS_THRESHOLD,
                 checks: recorded.checks
               },
               attributions
             )

    assert briefing.verdict == :refuse
    assert [%{name: :bias, refusal: :REFUSED_BIAS_THRESHOLD}] = briefing.refusal_anatomy
    assert briefing.counterfactual_available

    # The anatomy is CAUSAL: flipping only the named check to :pass flips the
    # decision. Two real replays witness it:
    # (a) the recorded receipt replays faithfully under the original checks
    #     (same input, same refusal — the record is a faithful witness);
    assert {:ok, faithful} =
             Counterfactual.evaluate(
               %{
                 input: samples,
                 admitted?: false,
                 refusal: :REFUSED_BIAS_THRESHOLD,
                 checks: recorded.checks
               },
               samples,
               checks
             )

    refute faithful.changed?
    assert {:refused, :REFUSED_BIAS_THRESHOLD} = faithful.outcome

    # (b) the same recorded input under the flipped check list admits — the
    # named check is the causal delta, exactly as the briefing's anatomy claims.
    flipped =
      Enum.map(checks, fn {name, fun} ->
        {name, fn i -> if name == :bias, do: :ok, else: fun.(i) end}
      end)

    assert %{outcome: :admitted, checks: flipped_log} = Counterfactual.run(samples, flipped)
    assert Enum.all?(flipped_log, &(&1.verdict == :pass))
  end

  test "an admit decision still carries its full anatomy (the structural countermeasure)" do
    samples =
      Enum.map(1..20, fn i ->
        [
          %{features: %{x: i * 1.0}, label: :ok, sensitive: 0},
          %{features: %{x: i * 1.0}, label: :ok, sensitive: 1}
        ]
      end)
      |> List.flatten()

    checks = admission_checks(samples, seed: 691)
    recorded = Counterfactual.run(samples, checks)
    assert recorded.outcome == :admitted

    attributions = AdmissionAttribution.shapley(samples, shapley_checks(checks))

    assert {:ok, briefing} =
             AutomationBiasCountermeasure.briefing(
               %{input: samples, admitted?: true, refusal: nil, checks: recorded.checks},
               attributions
             )

    assert briefing.verdict == :admit
    assert briefing.refusal_anatomy == []
    # Every check green, each with its attribution present — the operator never
    # sees an unexplained admit.
    assert length(briefing.per_check_causes) == length(recorded.checks)

    Enum.each(briefing.per_check_causes, fn cause ->
      assert cause.verdict == :pass
      assert is_float(cause.shapley)
    end)
  end

  test "briefing refuses an unfaithful record where the anatomy would contradict the replay" do
    samples = skewed_dataset()
    checks = admission_checks(samples, seed: 691, epsilon_bias: 0.1)
    recorded = Counterfactual.run(samples, checks)
    assert {:refused, :REFUSED_BIAS_THRESHOLD} = recorded.outcome

    # Real check log, but a refusal atom that no check produced — the record
    # cannot be a faithful witness of this check list.
    assert {:error, {:record_outcome_mismatch, _}} =
             Counterfactual.evaluate(
               %{
                 input: samples,
                 admitted?: false,
                 refusal: :FABRICATED_REFUSAL,
                 checks: recorded.checks
               },
               samples,
               checks
             )

    assert {:error, {:refusal_mismatch, :FABRICATED_REFUSAL}} =
             AutomationBiasCountermeasure.briefing(
               %{
                 input: samples,
                 admitted?: false,
                 refusal: :FABRICATED_REFUSAL,
                 checks: recorded.checks
               },
               %{bias: 0.0, completeness: 0.0}
             )
  end
end
