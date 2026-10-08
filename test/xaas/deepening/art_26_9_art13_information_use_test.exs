defmodule Xaas.Deepening.Art269Art13InformationUseTest do
  @moduledoc """
  Lane W984p — evidenced-line deepening wave 4, corpus line **26.9**
  (deployer use of the Art. 13 interpretability information, bound per the
  corpus evidence entry (W506/W505) to the counterfactual explanation +
  admission attribution surfaces).

  `counterfactual_test.exs` / `counterfactual_deepening_test.exs` court
  the harness over hand-built records; `art_14_4b` courts the briefing
  composition. The uncovered properties here are the Art. 13
  information-sufficiency laws over a REAL gate refusal: the ordered
  per-check verdict log (the Art. 13 information) must be

    (a) sufficient for EXACT attribution — the Shapley value sums to the
        efficiency identity v(N) − v(∅) over real gate verdicts, and the
        blame disappears exactly when the real refusing gate's input is
        repaired (balanced data ⇒ all φ = 0);
    (b) sufficient for a CAUSAL counterfactual with a FAITHFUL record —
        `evaluate/3` verifies the recorded outcome, and an unfaithful
        record is refused typed (`{:error, {:record_outcome_mismatch, _}}`),
        never silently explained;
    (c) the ordered log must witness downstream checks even after the
        first refusal (both-gates-fail case: the bias gate's verdict is
        recorded even though completeness refused first).

  Mutation rationale: if the Art. 13 per-check log degrades (attribution
  stops summing to the efficiency identity over real verdicts,
  `evaluate/3` stops verifying the recorded outcome, or the log stops
  witnessing downstream checks), these courts fail while shape/determinism
  courts over hand-built records still pass.

  Chicago discipline: real `DatasetAdmission` gates over seeded real
  samples, real deterministic modules — no mocks.
  """

  use ExUnit.Case, async: true

  # 26.9 is an evidenced corpus line (W506/W505 evidence entry) — eu_ai_act
  # census.
  @moduletag :eu_ai_act

  alias Xaas.Semantics.AdmissionAttribution
  alias Xaas.Semantics.Counterfactual
  alias Xaas.Semantics.DatasetAdmission

  @opts [seed: 984, epsilon_bias: 0.5, eta: 0.05]

  # Deterministic skewed population: group A=0 near 0, group A=1 near 100
  # — W1_proxy far above any epsilon (fixture shape from the Title II
  # deepening).
  defp skewed_dataset do
    Enum.map(1..20, fn i ->
      [
        %{features: %{x: 0.0}, label: :ok, sensitive: 0},
        %{features: %{x: 100.0 + i * 0.1}, label: :ok, sensitive: 1}
      ]
    end)
    |> List.flatten()
  end

  # Repaired (balanced-ish) population: both sensitive groups cover the
  # SAME value range (paired samples, tiny 0.25 shift), so the real W1
  # proxy collapses under epsilon and the real gate admits.
  defp balanced_dataset do
    for base <- 0..19, group <- [0, 1] do
      %{
        features: %{x: base * 1.0 + group * 0.25},
        label: :ok,
        sensitive: group
      }
    end
  end

  # The real two-gate admission pipeline in its real order: completeness
  # (real `completeness/2` vs the real eta threshold), then the bias gate
  # (real `admit/2`). Counterfactual check contract: `:ok | {:refused, atom}`.
  defp admission_checks(opts) do
    eta = Keyword.fetch!(opts, :eta)

    completeness = fn samples ->
      c = DatasetAdmission.completeness(samples, Keyword.get(opts, :required_fields, []))

      if c < 1 - eta,
        do: {:refused, :REFUSED_INCOMPLETE_DATASET},
        else: :ok
    end

    bias = fn samples ->
      # The bias gate proper: completeness is upstream, so re-ask admit
      # WITHOUT the required-fields opt (it would refuse incomplete first).
      bias_opts = Keyword.delete(opts, :required_fields)

      case DatasetAdmission.admit(samples, bias_opts) do
        {:ok, :ADMITTED, _} -> :ok
        {:error, reason} when is_atom(reason) -> {:refused, reason}
        {:error, {reason, _detail}} when is_atom(reason) -> {:refused, reason}
      end
    end

    [completeness: completeness, bias: bias]
  end

  # AdmissionAttribution check contract: `:pass | {:refuse, atom}`.
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

  defp recorded_from(samples, outcome, checks) do
    refused? = match?({:refused, _}, outcome)

    %{
      input: samples,
      admitted?: not refused?,
      refusal: (refused? && elem(outcome, 1)) || nil,
      checks: checks
    }
  end

  test "Art. 13 info is sufficient for exact attribution: efficiency identity over real gate verdicts, blame vanishes when the real refusing input is repaired" do
    samples = skewed_dataset()
    checks = admission_checks(@opts)

    # Real refusal: the bias gate refuses the skewed population.
    refused_run = Counterfactual.run(samples, checks)
    assert {:refused, :REFUSED_BIAS_THRESHOLD} = refused_run.outcome

    assert [%{name: :completeness, verdict: :pass}, %{name: :bias, verdict: :fail}] =
             refused_run.checks

    attributions = AdmissionAttribution.shapley(samples, shapley_checks(checks))

    # Efficiency identity over REAL verdicts: Σφ = v(N) − v(∅) = 0 − 1 = −1
    # (v(∅)=1 vacuously; the full coalition refuses because the real bias
    # gate refuses). The module raises internally on violation; asserting
    # the value here makes the axiom load-bearing in this court.
    assert_in_delta Enum.sum(Map.values(attributions)), -1.0, 1.0e-9

    # Exact complement: repairing the real input (balanced data) drives the
    # real bias gate to admit — and the blame vanishes EXACTLY.
    balanced = AdmissionAttribution.shapley(balanced_dataset(), shapley_checks(checks))
    assert Map.values(balanced) |> Enum.all?(&(&1 == 0.0))

    # And the real gate really admits the repaired input.
    assert {:ok, :ADMITTED, _} = DatasetAdmission.admit(balanced_dataset(), @opts)

    # Determinism ×2: identical attribution on re-run.
    assert AdmissionAttribution.shapley(samples, shapley_checks(checks)) == attributions
  end

  test "Art. 13 info supports a causal counterfactual whose record must be faithful" do
    samples = skewed_dataset()
    checks = admission_checks(@opts)

    refused_run = Counterfactual.run(samples, checks)
    assert {:refused, :REFUSED_BIAS_THRESHOLD} = refused_run.outcome

    record = recorded_from(samples, refused_run.outcome, refused_run.checks)

    # Causal counterfactual: substituting the repaired input flips the real
    # gate, `changed?` is witnessed, and the explanation names the check
    # whose verdict flipped.
    assert {:ok, cf} = Counterfactual.evaluate(record, balanced_dataset(), checks)
    assert cf.outcome == :admitted
    assert cf.changed? == true
    assert cf.explanation =~ "bias"
    assert Enum.find(cf.checks, &(&1.name == :bias)).verdict == :pass

    # Same-input counterfactual changes nothing (no spurious causality).
    assert {:ok, same} = Counterfactual.evaluate(record, samples, checks)
    assert same.changed? == false
    assert same.outcome == {:refused, :REFUSED_BIAS_THRESHOLD}

    # Faithful-record law: a record whose recorded decision does NOT
    # reproduce under the cited checks is refused typed — the Art. 13
    # information cannot be silently reinterpreted.
    unfaithful = %{record | admitted?: true, refusal: nil}

    assert {:error, {:record_outcome_mismatch, {:expected, {true, nil}, :got, {:refused, :REFUSED_BIAS_THRESHOLD}}}} =
             Counterfactual.evaluate(unfaithful, samples, checks)
  end

  test "the ordered Art. 13 log witnesses downstream checks past the first refusal" do
    # Both gates fail: completeness refuses (required field :y nil in every
    # sample — a nil feature keeps the W1 vectors observable, per the
    # module's non-number->0.0 vector contract), and the bias gate's
    # verdict must STILL be recorded downstream.
    samples =
      skewed_dataset()
      |> Enum.map(fn s -> put_in(s, [:features, :y], nil) end)

    opts = Keyword.put(@opts, :required_fields, [:y])
    checks = admission_checks(opts)

    assert %{outcome: {:refused, :REFUSED_INCOMPLETE_DATASET}, checks: log} =
             Counterfactual.run(samples, checks)

    # First refusal decides, but the downstream real gate is still witnessed.
    assert [%{name: :completeness, verdict: :fail, refusal: :REFUSED_INCOMPLETE_DATASET},
            %{name: :bias, verdict: :fail, refusal: :REFUSED_BIAS_THRESHOLD}] = log

    # Attribution over the both-fail record: efficiency identity still holds.
    attributions = AdmissionAttribution.shapley(samples, shapley_checks(checks))
    assert_in_delta Enum.sum(Map.values(attributions)), -1.0, 1.0e-9
  end
end
