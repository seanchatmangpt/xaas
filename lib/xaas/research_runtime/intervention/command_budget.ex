defmodule Xaas.ResearchRuntime.CommandBudget do
  @moduledoc false
  def consume(work, amount) when work.remaining >= amount, do: {:ok, %{work | remaining: work.remaining - amount}}
  def consume(work, amount), do: {:refused, :boundary_violation}
end
