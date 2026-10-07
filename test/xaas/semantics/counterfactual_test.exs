defmodule Xaas.Semantics.CounterfactualTest do
  use ExUnit.Case, async: true

  alias Xaas.Semantics.Counterfactual

  # Real check collaborators (Chicago: no mocks). Deterministic pure funs over
  # the input map; same shape the admission surface uses.
  defp checks do
    [
      {:dataset_has_purpose, fn input ->
        if input[:purpose] in [nil, ""], do: {:refused, :purpose_missing}, else: :ok
      end},
      {:lawful_basis_present, fn input ->
        if input[:lawful_basis] in [nil, ""], do: {:refused, :lawful_basis_missing}, else: :ok
      end},
      {:pii_minimized, fn input ->
        if input[:pii_fields] == [] or input[:pii_fields] == nil, do: :ok, else: {:refused, :pii_not_minimized}
      end}
    ]
  end

  defp record_for(input, checks) do
    %{outcome: outcome, checks: check_log} = Counterfactual.run(input, checks)

    {admitted?, refusal} =
      case outcome do
        :admitted -> {true, nil}
        {:refused, reason} -> {false, reason}
      end

    %{
      input: input,
      admitted?: admitted?,
      refusal: refusal,
      checks: check_log
    }
  end

  describe "evaluate/3" do
    test "same-input replay yields identical outcome, changed? false" do
      input = %{purpose: "research", lawful_basis: "consent", pii_fields: [:email]}
      record = record_for(input, checks())

      assert {:ok, result} = Counterfactual.evaluate(record, input, checks())
      assert result.outcome == {:refused, :pii_not_minimized}
      assert result.changed? == false
      assert result.explanation =~ "No check verdicts changed"
      assert result.explanation =~ "pii_not_minimized"
    end

    test "removing the violating field flips refusal to admission, naming the check" do
      input = %{purpose: "research", lawful_basis: "consent", pii_fields: [:email]}
      record = record_for(input, checks())

      x_prime = %{input | pii_fields: []}

      assert {:ok, result} = Counterfactual.evaluate(record, x_prime, checks())
      assert result.outcome == :admitted
      assert result.changed? == true
      assert result.explanation =~ "`pii_minimized`"
      refute result.explanation =~ "dataset_has_purpose"
      refute result.explanation =~ "lawful_basis_present"
    end

    test "input that newly violates flips admission to refusal" do
      input = %{purpose: "research", lawful_basis: "consent", pii_fields: []}
      record = record_for(input, checks())
      assert record.admitted? == true

      x_prime = %{input | purpose: nil}

      assert {:ok, result} = Counterfactual.evaluate(record, x_prime, checks())
      assert result.outcome == {:refused, :purpose_missing}
      assert result.changed? == true
      assert result.explanation =~ "`dataset_has_purpose`"
      assert result.explanation =~ "refused (purpose_missing)"
    end

    test "is deterministic: repeated evaluation gives byte-identical results" do
      input = %{purpose: "research", lawful_basis: nil, pii_fields: [:email]}
      record = record_for(input, checks())
      x_prime = %{input | lawful_basis: "consent"}

      results =
        for _ <- 1..25 do
          Counterfactual.evaluate(record, x_prime, checks())
        end

      assert Enum.uniq(results) == [hd(results)]
      assert {:ok, %{outcome: {:refused, :pii_not_minimized}, changed?: true}} = hd(results)
    end

    test "multi-check flip lists the exact flipped checks in recorded order" do
      input = %{purpose: nil, lawful_basis: nil, pii_fields: [:email]}
      record = record_for(input, checks())
      assert record.refusal == :purpose_missing

      x_prime = %{input | purpose: "research", lawful_basis: "consent", pii_fields: []}

      assert {:ok, result} = Counterfactual.evaluate(record, x_prime, checks())
      assert result.outcome == :admitted
      assert result.changed? == true

      # All three flipped: dataset_has_purpose fail->pass, lawful_basis_present
      # fail->pass, pii_minimized fail->pass; named in recorded order.
      assert result.explanation =~
               "`dataset_has_purpose`, `lawful_basis_present`, `pii_minimized` (multi-check flip)"
    end

    test "short-circuit order is preserved: earlier refusal shadows later violations" do
      input = %{purpose: "research", lawful_basis: "consent", pii_fields: []}
      record = record_for(input, checks())

      # x' violates BOTH purpose and pii; first failing check wins.
      x_prime = %{purpose: nil, lawful_basis: "consent", pii_fields: [:email]}

      assert {:ok, result} = Counterfactual.evaluate(record, x_prime, checks())
      assert result.outcome == {:refused, :purpose_missing}
      assert result.explanation =~ "`dataset_has_purpose`"
    end

    test "typed refusal when the record does not replay under the check-list" do
      input = %{purpose: "research", lawful_basis: "consent", pii_fields: []}

      record = %{
        input: input,
        admitted?: false,
        refusal: :pii_not_minimized,
        checks: [%{name: :pii_minimized, verdict: :fail, refusal: :pii_not_minimized}]
      }

      assert {:error, {:record_outcome_mismatch, {:expected, {false, :pii_not_minimized}, :got, :admitted}}} =
               Counterfactual.evaluate(record, input, checks())
    end
  end

  describe "run/2" do
    test "returns outcome and ordered per-check log" do
      input = %{purpose: "research", lawful_basis: "consent", pii_fields: [:email]}

      assert %{outcome: {:refused, :pii_not_minimized}, checks: checks_log} =
               Counterfactual.run(input, checks())

      assert Enum.map(checks_log, & &1.name) == [:dataset_has_purpose, :lawful_basis_present, :pii_minimized]
      assert Enum.map(checks_log, & &1.verdict) == [:pass, :pass, :fail]
    end

    test "outcome takes the first refusal in order, but every verdict is recorded" do
      input = %{purpose: nil, lawful_basis: nil, pii_fields: [:email]}

      assert %{outcome: {:refused, :purpose_missing}, checks: checks_log} =
               Counterfactual.run(input, checks())

      assert Enum.map(checks_log, & &1.name) == [:dataset_has_purpose, :lawful_basis_present, :pii_minimized]
      assert Enum.map(checks_log, & &1.verdict) == [:fail, :fail, :fail]
    end
  end
end
