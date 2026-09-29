defmodule XaaS.Trimtab.ContextBudgetTest do
  use ExUnit.Case, async: true
  alias XaaS.Trimtab.ContextBudget
  test "budget rejects overflow" do
    assert ContextBudget.admit(%ContextBudget{max_tokens: 8}, 9) == {:error, :context_budget_exceeded}
  end
end
