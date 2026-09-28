defmodule Xaas.ResearchRuntime.RacapPair do
  @moduledoc false
  def compare(control, candidate) when is_number(control) and is_number(candidate), do: {:ok, %{delta: candidate - control, promote: candidate > control}}
  def compare(control, candidate), do: {:refused, :boundary_violation}
end
