defmodule Xaas.EuAiAct.Art13xCounterfactualDeepeningTest do
  @moduledoc """
  Lane W984ew — Art. 13.x corpus deepening (courts for the court-free
  evidenced 13.x lines flagged by W984ec's receipt) over the REAL modules:

    * `Xaas.Semantics.Counterfactual` — deterministic replay (Theorem 7.1)
    * `Xaas.Semantics.AdmissionAttribution` — exact Shapley (Def. 5.2)
    * `Xaas.Semantics.RobustMargin` — Art.15 margin gate (Theorem 5.3)

  Line mapping:

    * **13.1** — output interpretability by design: the counterfactual
      explanation artifact is deterministic (byte-identical on identical
      record + x') and precisely tracks the causal delta (names exactly the
      checks that flipped, only those).
    * **13.3.b.iv / 13.3.f** — output-explanation capabilities: the
      explanation and the exact Shapley attribution AGREE on the cause of a
      refusal for the same decision (the named flip is the largest-magnitude
      phi), and the explanation's outcome clause matches the real counter-
      factual outcome.
    * **13.3.b.ii** — accuracy/robustness metrics tested: the real margin
      gate consumes a MEASURED empirical Lipschitz constant (exact value for
      a linear scorer), admits exactly at the margin == penalty boundary,
      refuses one notch below with the real typed refusal, and fails closed
      on missing calibration data.

  Chicago-style: real module executions over in-test fixtures, assertions on
  final returned state only; zero mocks, zero application-env knobs.
  """

  use ExUnit.Case, async: true

  @moduletag :eu_ai_act

  alias Xaas.Semantics.AdmissionAttribution
  alias Xaas.Semantics.Counterfactual
  alias Xaas.Semantics.RobustMargin

  # -- shared real pipeline ----------------------------------------------------
  # Ordered admission check-list over one intent map. All three surfaces see
  # the SAME decision functions via their native verdict contracts:
  # Counterfactual `:ok | {:refused, atom}`, Attribution `:pass | {:refuse, atom}`.
  @refused_intent %{age: 17, score: 0.30, region: :eu}
  @admitted_intent %{age: 30, score: 0.90, region: :eu}

  defp cf_checks do
    [
      age: fn i -> if i.age >= 18, do: :ok, else: {:refused, :under_age} end,
      score: fn i -> if i.score >= 0.5, do: :ok, else: {:refused, :low_score} end,
      region: fn i -> if i.region == :eu, do: :ok, else: {:refused, :region_blocked} end
    ]
  end

  defp shapley_checks do
    [
      age: fn i -> if i.age >= 18, do: :pass, else: {:refuse, :under_age} end,
      score: fn i -> if i.score >= 0.5, do: :pass, else: {:refuse, :low_score} end,
      region: fn i -> if i.region == :eu, do: :pass, else: {:refuse, :region_blocked} end
    ]
  end

  defp record_for(intent) do
    cf = Counterfactual.run(intent, cf_checks())

    %{
      input: intent,
      admitted?: cf.outcome == :admitted,
      refusal: elem_or_nil(cf.outcome),
      checks: cf.checks
    }
  end

  defp elem_or_nil(:admitted), do: nil
  defp elem_or_nil({:refused, reason}), do: reason

  # -- 13.1: interpretability by design — deterministic, delta-precise explanation
  describe "13.1 interpretability by design (counterfactual explanation artifact)" do
    test "explanation is deterministic: identical record + x' reproduces the byte-identical explanation" do
      record = record_for(@refused_intent)

      results =
        for _ <- 1..3 do
          {:ok, r} = Counterfactual.evaluate(record, %{age: 25, score: 0.30, region: :eu}, cf_checks())
          r
        end

      # Byte-identical across repeats — Thm 7.1 determinism extends to the
      # explanation artifact itself, not just the outcome.
      assert results |> Enum.uniq_by(& &1.explanation) |> length() == 1

      first = hd(results)
      assert first.changed? == true
      assert first.outcome == {:refused, :low_score}
      # The explanation names exactly the one check whose verdict flipped
      # (age: fail -> pass) and only it.
      assert first.explanation =~ "`age`"
      refute first.explanation =~ "`score`"
      refute first.explanation =~ "`region`"
    end

    test "explanation precisely tracks the causal delta: a downstream flip is named even when the first-refusal decision is unchanged" do
      record = record_for(@refused_intent)

      {:ok, r} = Counterfactual.evaluate(record, %{age: 17, score: 0.80, region: :eu}, cf_checks())
      # age still fails first: the recorded decision itself is reproduced
      # (changed? false) — but the score verdict DID flip, and the explanation
      # witnesses exactly that delta.
      assert r.outcome == {:refused, :under_age}
      assert r.changed? == false
      assert r.explanation =~ "`score`"
      refute r.explanation =~ "`age`"
    end

    test "a counterfactual that changes nothing yields the same-outcome explanation naming no check" do
      record = record_for(@admitted_intent)

      {:ok, r} = Counterfactual.evaluate(record, %{age: 30, score: 0.95, region: :eu}, cf_checks())
      assert r.outcome == :admitted
      assert r.changed? == false
      assert r.explanation =~ "No check verdicts changed"
      refute r.explanation =~ "`"
    end
  end

  # -- 13.3.b.iv / 13.3.f: explanation and attribution AGREE on the cause
  describe "13.3.b.iv + 13.3.f output-explanation capabilities (counterfactual x attribution agreement)" do
    test "the explanation's named flip is exactly the only Shapley-attributed check for the same refusal" do
      # Single-defect intent: only :score fails. The counterfactual fixes it
      # (x' score 0.80) -> admitted; the explanation names `score` alone.
      intent = %{age: 30, score: 0.30, region: :eu}
      record = record_for(intent)

      {:ok, cf} = Counterfactual.evaluate(record, %{age: 30, score: 0.80, region: :eu}, cf_checks())
      assert cf.outcome == :admitted
      assert cf.changed? == true
      assert cf.explanation =~ "`score`"
      refute cf.explanation =~ "multi-check"

      # Exact Shapley over the SAME refusal: only the failing check carries
      # attribution mass (-1 in total, all on `score`), so the flip named in
      # the explanation IS the unique attributed cause.
      phis = AdmissionAttribution.shapley(intent, shapley_checks())
      assert is_map(phis)
      assert phis.age == 0.0
      assert phis.region == 0.0
      assert phis.score == -1.0
      max_phi = phis |> Enum.max_by(fn {_k, v} -> abs(v) end) |> elem(0)
      assert max_phi == :score
    end

    test "explanation outcome clause matches the real counterfactual outcome; full U witnessed in the per-check log" do
      {:ok, cf} =
        Counterfactual.evaluate(
          record_for(@refused_intent),
          %{age: 25, score: 0.80, region: :eu},
          cf_checks()
        )

      assert cf.outcome == :admitted
      assert cf.explanation =~ "admitted"
      assert cf.changed? == true
      # Full ordered U: every check witnessed, including downstream survivors.
      assert length(cf.checks) == 3
      assert %{name: :age, verdict: :pass, refusal: nil} in cf.checks
      assert %{name: :score, verdict: :pass, refusal: nil} in cf.checks
      assert %{name: :region, verdict: :pass, refusal: nil} in cf.checks
    end
  end

  # -- 13.3.b.ii: accuracy/robustness metrics TESTED over the real margin gate
  describe "13.3.b.ii robustness metrics tested (RobustMargin over the measured pipeline)" do
    test "empirical Lipschitz is measured exactly for a linear scorer and feeds a real admit/refuse boundary" do
      # Linear scorer: 4x (slope 4 in 1-D).
      scorer = fn s -> s * 4.0 end

      l_e =
        RobustMargin.estimate_lipschitz(scorer, [
          {0.5, 0.6},
          {0.2, 0.65}
        ])

      assert l_e == 4.0

      # margin = h(E(x)) = 2.0; penalty = l_h * l_e * eps. At eps = 0.1 the
      # margin EQUALS the penalty -> strict >= admits at the boundary.
      assert RobustMargin.admit(2.0, 5.0, l_e, 0.1) == :ADMITTED

      # One notch tighter (eps = 0.1001) -> penalty exceeds margin, typed refusal.
      assert RobustMargin.admit(2.0, 5.0, l_e, 0.1001) == {:error, :REFUSED_ROBUST_MARGIN}
    end

    test "no calibration data fails closed: the typed refusal propagates as the gate verdict" do
      scorer = fn s -> s end
      assert RobustMargin.estimate_lipschitz(scorer, []) == {:error, :REFUSED_NO_CALIBRATION_DATA}

      # Feeding the typed error back as l_h propagates it as the verdict.
      assert RobustMargin.admit(2.0, {:error, :REFUSED_NO_CALIBRATION_DATA}, 1.0, 0.1) ==
               {:error, :REFUSED_NO_CALIBRATION_DATA}
    end

    test "metrics are honest about their sample: a denser sample can only raise the empirical constant" do
      scorer = fn s -> if s >= 0.5, do: 1.0, else: 0.0 end
      coarse = RobustMargin.estimate_lipschitz(scorer, [{0.4, 0.6}])
      denser =
        RobustMargin.estimate_lipschitz(scorer, [
          {0.4, 0.6},
          {0.49, 0.51}
        ])

      assert is_float(coarse) and coarse > 0.0
      assert is_float(denser) and denser >= coarse
    end
  end
end
