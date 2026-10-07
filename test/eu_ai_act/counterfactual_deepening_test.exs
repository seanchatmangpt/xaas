defmodule Xaas.EuAiAct.CounterfactualDeepeningTest do
  @moduledoc """
  Lane W692 — Pearl counterfactual calculus deepening (Art. 14(4) /
  dissertation ch. 9) over the REAL landed modules:

    * `Xaas.Semantics.Counterfactual` — deterministic replay (Theorem 7.1)
    * `Xaas.Semantics.AdmissionAttribution` — exact Shapley (Def. 5.2)
    * `Xaas.Semantics.AutomationBiasCountermeasure` — briefing composition

  Sections:

    (a) abduction-action-prediction three-step on a multi-candidate refusal,
        seeded x3 determinism.
    (b) Shapley symmetry / efficiency / dummy properties on the real
        attribution module.
    (c) composed chain: counterfactual verdict -> attribution ->
        AutomationBiasCountermeasure.briefing/2 consumes both.

  Chicago-style: real modules, exact values/atoms, no mocks.
  """

  use ExUnit.Case, async: true

  @moduletag :eu_ai_act

  alias Xaas.Semantics.AdmissionAttribution
  alias Xaas.Semantics.AutomationBiasCountermeasure
  alias Xaas.Semantics.Counterfactual

  @interpretability "counterfactual replay + exact Shapley attribution — deterministic, receipt-backed"

  # -- shared real check-list --------------------------------------------------
  # Deterministic admission pipeline with three named checks over one intent
  # map. The SAME decision functions serve both surfaces via thin adapters:
  # Counterfactual expects `:ok | {:refused, atom}` (W506 contract),
  # AdmissionAttribution expects `:pass | {:refuse, atom}` (W505 contract).
  # Both fun families below call the same `verdict/2` — one causal model.

  @checks [:scope, :bias, :margin]

  defp verdict(:scope, intent), do: if(intent.kind in [:routine, :high_stakes], do: :pass, else: {:refuse, :REFUSED_SCOPE})
  defp verdict(:bias, intent), do: if(intent.bias_risk <= 0.3, do: :pass, else: {:refuse, :REFUSED_BIAS_THRESHOLD})
  defp verdict(:margin, intent), do: if(intent.margin >= 0.7, do: :pass, else: {:refuse, :REFUSED_ROBUST_MARGIN})

  defp cf_checks do
    for name <- @checks do
      {name, fn intent -> case verdict(name, intent) do
        :pass -> :ok
        {:refuse, reason} -> {:refused, reason}
      end end}
    end
  end

  defp shapley_checks do
    for name <- @checks do
      {name, fn intent -> verdict(name, intent) end}
    end
  end

  # The refused candidate: fails TWO checks (multi-candidate refusal — both
  # :bias and :margin fire; :scope passes).
  @refused_intent %{kind: :routine, bias_risk: 0.9, margin: 0.4}

  # Counterfactual x': fix the bias risk only. :bias flips to pass; :margin
  # still fails — the refusal CAUSE migrates from :bias to :margin.
  @x_prime_bias_fixed %{kind: :routine, bias_risk: 0.1, margin: 0.4}

  # Counterfactual x'': fix both failing attributes -> full admit.
  @x_prime_both_fixed %{kind: :routine, bias_risk: 0.1, margin: 0.9}

  defp record_for(intent) do
    %{outcome: outcome, checks: checks} = Counterfactual.run(intent, cf_checks())

    case outcome do
      :admitted ->
        %{input: intent, admitted?: true, refusal: nil, checks: checks}

      {:refused, reason} ->
        %{input: intent, admitted?: false, refusal: reason, checks: checks}
    end
  end

  # -- (a) abduction-action-prediction, multi-candidate refusal, seeded x3 ----

  describe "Pearl three-step on a multi-candidate refusal" do
    test "abduction recovers the full ordered U; action substitutes x'; prediction is exact" do
      record = record_for(@refused_intent)

      # ABDUCTION: the recorded per-check log IS the recovered structural
      # recourse variable set U — exact, ordered, all three checks witnessed.
      assert record.admitted? == false
      assert record.refusal == :REFUSED_BIAS_THRESHOLD
      assert [%{name: :scope, verdict: :pass, refusal: nil},
              %{name: :bias, verdict: :fail, refusal: :REFUSED_BIAS_THRESHOLD},
              %{name: :margin, verdict: :fail, refusal: :REFUSED_ROBUST_MARGIN}] = record.checks

      # ACTION: do-intervention — substitute x' (fix bias_risk only).
      {:ok, result} = Counterfactual.evaluate(record, @x_prime_bias_fixed, cf_checks())

      # PREDICTION: exact outcome, probability 1 (Theorem 7.1) — the refusal
      # survives but its CAUSE migrates from :bias to :margin.
      assert result.outcome == {:refused, :REFUSED_ROBUST_MARGIN}
      # the refusal SURVIVES but its reason migrates, so the outcome value differs
      assert result.changed? == true
      assert result.explanation ==
               "Counterfactual outcome is refused (REFUSED_ROBUST_MARGIN); caused by check " <>
                 "`bias` flipping verdict."

      assert [%{name: :scope, verdict: :pass},
              %{name: :bias, verdict: :pass},
              %{name: :margin, verdict: :fail, refusal: :REFUSED_ROBUST_MARGIN}] = result.checks
    end

    test "flipping all failing checks flips the decision to :admitted" do
      record = record_for(@refused_intent)
      {:ok, result} = Counterfactual.evaluate(record, @x_prime_both_fixed, cf_checks())

      assert result.outcome == :admitted
      assert result.changed? == true
      assert result.explanation ==
               "Counterfactual outcome is admitted; caused by check `bias`, `margin` (multi-check flip) " <>
                 "flipping verdict."
    end

    test "an unfaithful record is refused, not silently counterfactualed" do
      record = record_for(@refused_intent)
      bad = %{record | admitted?: true, refusal: nil}

      assert {:error, {:record_outcome_mismatch,
                       {:expected, {true, nil}, :got, {:refused, :REFUSED_BIAS_THRESHOLD}}}} =
               Counterfactual.evaluate(bad, @x_prime_both_fixed, cf_checks())
    end

    test "seeded x3 determinism: identical abduction, action, prediction across seeds" do
      results =
        for seed <- 1..3 do
          # The "seed" deterministically selects the intervention target order
          # (no randomness anywhere in the pipeline — seeded repetition asserts
          # the full three-step is a pure function of (record, x', checks)).
          x_prime =
            case seed do
              1 -> @x_prime_bias_fixed
              2 -> @x_prime_both_fixed
              3 -> @x_prime_bias_fixed
            end

          record = record_for(@refused_intent)
          cf1 = Counterfactual.run(@refused_intent, cf_checks())
          {:ok, cf2} = Counterfactual.evaluate(record, x_prime, cf_checks())
          # re-run the whole step chain; byte-identical
          {:ok, cf2_again} = Counterfactual.evaluate(record, x_prime, cf_checks())

          {cf1, cf2, cf2_again}
        end

      assert [s1, s2, s3] = results
      assert s1 == s3
      # seeds 1 and 3 use the same x': the prediction is identical
      assert elem(s1, 1) == elem(s3, 1)
      # every prediction carries the exact same factual U (step 1)
      assert elem(s1, 0) == elem(s2, 0) and elem(s2, 0) == elem(s3, 0)
      assert %{outcome: {:refused, :REFUSED_BIAS_THRESHOLD}, checks: [%{name: :scope}, %{name: :bias}, %{name: :margin}]} =
               elem(s1, 0)
    end
  end

  # -- (b) exact Shapley properties --------------------------------------------

  describe "AdmissionAttribution exact Shapley properties" do
    test "efficiency: sum(phi) == v(N) - v(empty) exactly (-1 for a refusal)" do
      phis = AdmissionAttribution.shapley(@refused_intent, shapley_checks())

      assert is_map(phis) and map_size(phis) == 3
      # v(empty) = 1 (vacuous admit), v(N) = 0 (refused): efficiency target -1
      sum = phis |> Map.values() |> Enum.sum()
      assert_in_delta sum, -1.0, 1.0e-9

      # the two refusing checks share the blame equally; the passing check is a dummy
      assert_in_delta phis.bias, -0.5, 1.0e-9
      assert_in_delta phis.margin, -0.5, 1.0e-9
      assert phis.scope === 0.0
    end

    test "efficiency on a full admit: sum(phi) == 0 and every phi == 0.0" do
      admitted_intent = %{kind: :routine, bias_risk: 0.1, margin: 0.9}
      phis = AdmissionAttribution.shapley(admitted_intent, shapley_checks())

      assert %{scope: 0.0, bias: 0.0, margin: 0.0} = phis
      assert Enum.sum(Map.values(phis)) === 0.0
    end

    test "symmetry: relabeling (permuting) candidates permutes phi values consistently" do
      phis = AdmissionAttribution.shapley(@refused_intent, shapley_checks())

      # Same causal model, reversed candidate order — the phi value follows
      # the candidate NAME, not its position.
      reversed = Enum.reverse(shapley_checks())
      phis_rev = AdmissionAttribution.shapley(@refused_intent, reversed)

      assert phis_rev == phis

      # rotation: [scope, bias, margin] -> [margin, scope, bias]
      rotated = tl(shapley_checks()) ++ [hd(shapley_checks())]
      phis_rot = AdmissionAttribution.shapley(@refused_intent, rotated)
      assert phis_rot == phis

      # symmetry axiom directly: two candidates with identical causal
      # behaviour get identical phi.
      twin_checks = [
        {:a, fn _ -> {:refuse, :x} end},
        {:b, fn _ -> {:refuse, :x} end},
        {:c, fn _ -> :pass end}
      ]

      twin_phis = AdmissionAttribution.shapley(%{}, twin_checks)
      assert twin_phis.a == twin_phis.b
      assert_in_delta twin_phis.a, -0.5, 1.0e-9
      assert twin_phis.c === 0.0
    end

    test "dummy candidate: a never-refusing candidate has phi == 0 under any coalition structure" do
      # one refusing candidate + one dummy; the dummy contributes nothing
      checks = [
        {:gate, fn intent -> if(intent.blocked, do: {:refuse, :BLOCKED}, else: :pass) end},
        {:spectator, fn _intent -> :pass end}
      ]

      phis = AdmissionAttribution.shapley(%{blocked: true}, checks)
      assert_in_delta phis.gate, -1.0, 1.0e-9
      assert phis.spectator === 0.0

      phis_open = AdmissionAttribution.shapley(%{blocked: false}, checks)
      assert phis_open.gate === 0.0
      assert phis_open.spectator === 0.0
    end

    test "oversized lattice gets the typed COALITION_LIMIT refusal" do
      big = for i <- 1..21, do: {:"c#{i}", fn _ -> :pass end}
      assert AdmissionAttribution.shapley(%{}, big) == {:error, :COALITION_LIMIT}
    end
  end

  # -- (c) composed chain -------------------------------------------------------

  describe "composed chain: counterfactual -> attribution -> briefing" do
    test "briefing/2 consumes the counterfactual verdict and the Shapley map" do
      record = record_for(@refused_intent)

      # step 1: counterfactual verdict (Art. 86 replay)
      {:ok, cf} = Counterfactual.evaluate(record, @x_prime_bias_fixed, cf_checks())
      assert cf.outcome == {:refused, :REFUSED_ROBUST_MARGIN}

      # step 2: exact attribution over the same causal model (Art. 13)
      attributions = AdmissionAttribution.shapley(@refused_intent, shapley_checks())
      assert attributions.scope === 0.0

      # step 3: briefing consumes BOTH (record+cf U, attribution map)
      {:ok, briefing} = AutomationBiasCountermeasure.briefing(record, attributions)

      assert briefing.verdict == :refuse
      assert briefing.counterfactual_available == true
      assert briefing.interpretability == @interpretability

      assert [
               %{name: :scope, verdict: :pass, refusal: nil, shapley: 0.0},
               %{name: :bias, verdict: :fail, refusal: :REFUSED_BIAS_THRESHOLD, shapley: bias_phi},
               %{name: :margin, verdict: :fail, refusal: :REFUSED_ROBUST_MARGIN, shapley: margin_phi}
             ] = briefing.per_check_causes

      assert_in_delta bias_phi, -0.5, 1.0e-9
      assert_in_delta margin_phi, -0.5, 1.0e-9

      assert briefing.refusal_anatomy == [
               %{name: :bias, refusal: :REFUSED_BIAS_THRESHOLD},
               %{name: :margin, refusal: :REFUSED_ROBUST_MARGIN}
             ]

      # determinism: same record + attributions => byte-identical briefing
      {:ok, briefing_again} = AutomationBiasCountermeasure.briefing(record, attributions)
      assert briefing_again == briefing
    end

    test "briefing for a full admit: empty anatomy, every check green with zero phi" do
      admitted = record_for(%{kind: :routine, bias_risk: 0.1, margin: 0.9})
      attributions = AdmissionAttribution.shapley(%{kind: :routine, bias_risk: 0.1, margin: 0.9}, shapley_checks())

      {:ok, briefing} = AutomationBiasCountermeasure.briefing(admitted, attributions)

      assert briefing.verdict == :admit
      assert briefing.refusal_anatomy == []
      assert Enum.all?(briefing.per_check_causes, &(&1.verdict == :pass and &1.shapley === 0.0))
      assert briefing.counterfactual_available == true
    end

    test "briefing refuses an attribution map that does not cover the recorded candidates" do
      record = record_for(@refused_intent)

      assert {:error, {:record_outcome_mismatch, _}} =
               Counterfactual.evaluate(%{record | refusal: :WRONG}, @x_prime_both_fixed, cf_checks())

      # briefing-level: attribution missing a recorded candidate name drops
      # counterfactual availability (typed field, not a silent default true)
      partial = Map.drop(AdmissionAttribution.shapley(@refused_intent, shapley_checks()), [:margin])
      {:ok, briefing} = AutomationBiasCountermeasure.briefing(record, partial)

      assert briefing.counterfactual_available == false
      assert %{name: :margin, shapley: 0.0} =
               Enum.find(briefing.per_check_causes, &(&1.name == :margin))
    end
  end
end
