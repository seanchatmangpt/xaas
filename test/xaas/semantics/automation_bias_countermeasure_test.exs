defmodule Xaas.Semantics.AutomationBiasCountermeasureTest do
  use ExUnit.Case, async: true

  alias Xaas.Semantics.{AdmissionAttribution, AutomationBiasCountermeasure, Counterfactual}

  # Real ordered admission check list (the W505/W506 shared shape).
  defp checks(:all_pass) do
    [
      {:scope, fn _ -> :ok end},
      {:human_oversight, fn _ -> :ok end},
      {:data_quality, fn _ -> :ok end}
    ]
  end

  defp checks(:one_refuse) do
    [
      {:scope, fn _ -> :ok end},
      {:human_oversight,
       fn input -> if Map.get(input, :oversight, false), do: :ok, else: {:refused, :no_human_oversight} end},
      {:data_quality, fn _ -> :ok end}
      | [{:logging, fn _ -> :ok end}]
    ]
  end

  # W506 pipeline run over the real check list -> recorded decision.
  defp record(input, checks) do
    %{outcome: outcome, checks: log} = Counterfactual.run(input, checks)
    {admitted?, refusal} = outcome_record(outcome)
    %{input: input, admitted?: admitted?, refusal: refusal, checks: log}
  end

  defp outcome_record(:admitted), do: {true, nil}

  defp outcome_record({:refused, reason}), do: {false, reason}

  defp attributions(input, checks) do
    AdmissionAttribution.shapley(input, fn_name_fix(checks))
  end

  # W505 contract is `:pass | {:refuse, atom}`; W506 contract is
  # `:ok | {:refused, atom}` — bridge both real surfaces without duplicating
  # either.
  defp fn_name_fix(checks) do
    Enum.map(checks, fn {name, fun} ->
      {name, fn input ->
         case fun.(input) do
           :ok -> :pass
           {:refused, r} -> {:refuse, r}
         end
       end}
    end)
  end

  describe "briefing/2" do
    test "refuse-case briefing names the flipped check" do
      cks = checks(:one_refuse)
      input = %{}
      rec = record(input, cks)
      {:ok, b} = AutomationBiasCountermeasure.briefing(rec, attributions(input, cks))

      assert b.verdict == :refuse
      assert [%{name: :human_oversight, refusal: :no_human_oversight}] = b.refusal_anatomy

      # the flipped check carries the full negative Shapley blame; passing
      # checks carry zero
      by_name = Map.new(b.per_check_causes, &{&1.name, &1})
      assert by_name[:human_oversight].verdict == :fail
      assert by_name[:human_oversight].shapley == -1.0
      assert by_name[:scope].shapley == 0.0
      assert by_name[:data_quality].shapley == 0.0
      assert by_name[:logging].shapley == 0.0
      assert b.counterfactual_available == true
    end

    test "admit-case briefing lists all checks green" do
      cks = checks(:all_pass)
      input = %{}
      rec = record(input, cks)
      {:ok, b} = AutomationBiasCountermeasure.briefing(rec, attributions(input, cks))

      assert b.verdict == :admit
      # over-reliance countermeasure: admits also show their anatomy
      assert length(b.per_check_causes) == 3

      assert Enum.all?(b.per_check_causes, fn c ->
               c.verdict == :pass and c.shapley == 0.0 and is_nil(c.refusal)
             end)

      assert b.refusal_anatomy == []
      assert b.counterfactual_available == true
    end

    test "interpretability statement is the fixed deterministic string" do
      cks = checks(:all_pass)
      rec = record(%{}, cks)
      {:ok, b} = AutomationBiasCountermeasure.briefing(rec, attributions(%{}, cks))

      assert b.interpretability ==
               "counterfactual replay + exact Shapley attribution — deterministic, receipt-backed"
    end

    test "determinism: same record + attributions => byte-identical briefing" do
      cks = checks(:one_refuse)
      input = %{entity: "e1"}
      rec = record(input, cks)
      attrs = attributions(input, cks)

      {:ok, b1} = AutomationBiasCountermeasure.briefing(rec, attrs)
      {:ok, b2} = AutomationBiasCountermeasure.briefing(rec, attrs)

      assert b1 == b2
      assert :erlang.term_to_binary(b1) == :erlang.term_to_binary(b2)
    end

    test "composes with the real W505/W506 modules over the same check list" do
      cks = checks(:one_refuse)
      input = %{entity: "e2", oversight: false}

      # real W506 run + real W506 counterfactual replay on x' (oversight
      # granted): the flipped-check briefing anatomy matches the replay delta
      rec = record(input, cks)
      x_prime = %{entity: "e2", oversight: true}

      {:ok, cf} = Counterfactual.evaluate(rec, x_prime, cks)
      assert cf.changed? == true

      # the replay's flipped checks: recorded checks whose verdict differs
      # from the counterfactual log with the same name
      cf_by_name = Map.new(cf.checks, fn c -> {c.name, c.verdict} end)

      flipped =
        Enum.filter(rec.checks, fn rc -> Map.fetch!(cf_by_name, rc.name) != rc.verdict end)

      assert Enum.map(flipped, & &1.name) == [:human_oversight]

      {:ok, b} = AutomationBiasCountermeasure.briefing(rec, attributions(input, cks))
      assert Enum.map(b.refusal_anatomy, & &1.name) == Enum.map(flipped, & &1.name)
    end

    test "refuses a record whose admitted? contradicts its refusal field" do
      rec = %{input: %{}, admitted?: true, refusal: :no_human_oversight, checks: []}
      assert {:error, {:admit_with_refusal, :no_human_oversight}} =
               AutomationBiasCountermeasure.briefing(rec, %{})
    end

    test "refuses a refusal record with no failing check" do
      rec = %{
        input: %{},
        admitted?: false,
        refusal: :no_human_oversight,
        checks: [%{name: :scope, verdict: :pass, refusal: nil}]
      }

      assert {:error, {:refusal_without_failing_check, :no_human_oversight}} =
               AutomationBiasCountermeasure.briefing(rec, %{scope: 0.0})
    end

    test "counterfactual_available is false when attribution names don't cover the log" do
      rec = record(%{}, checks(:all_pass))
      {:ok, b} = AutomationBiasCountermeasure.briefing(rec, %{})
      assert b.counterfactual_available == false
    end
  end
end
