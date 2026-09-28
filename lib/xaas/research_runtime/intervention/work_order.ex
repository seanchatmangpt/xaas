defmodule Xaas.ResearchRuntime.WorkOrder do
  @moduledoc false
  def new(id, subject, budget) when budget >= 0, do: {:ok, %{id: id, subject: subject, remaining: budget}}
  def new(id, subject, budget), do: {:refused, :boundary_violation}
end
