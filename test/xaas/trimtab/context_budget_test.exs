defmodule Xaas.Trimtab.ContextBudgetTest do
  use ExUnit.Case, async: true
  alias Xaas.Trimtab.ContextBudget

  test "budget rejects overflow" do
    budget = %ContextBudget{max_items: 8, max_bytes: 10_000}

    assert ContextBudget.fit?(budget, List.duplicate(:obs, 9)) == false
    assert ContextBudget.fit?(budget, List.duplicate(:obs, 8)) == true
  end

  test "new/2 rejects non-positive budgets" do
    assert ContextBudget.new(0, 100) == {:error, :invalid_budget}
    assert ContextBudget.new(8, 0) == {:error, :invalid_budget}
    assert {:ok, %ContextBudget{}} = ContextBudget.new(8, 10_000)
  end
  test "budget rejects byte overflow" do
    budget = %ContextBudget{max_items: 100, max_bytes: 8}

    assert ContextBudget.fit?(budget, [:oversized]) == false
    assert ContextBudget.fit?(budget, []) == true
  end
end
