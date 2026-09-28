defmodule Xaas.ResearchRuntime.Epoch do
  @moduledoc false
  def advance(current, subject) when is_integer(current) and current >= 0, do: {:ok, %{epoch: current + 1, subject: subject}}
  def advance(current, subject), do: {:refused, :boundary_violation}
end
