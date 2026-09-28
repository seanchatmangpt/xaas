defmodule Xaas.ResearchRuntime.PowlTrace do
  @moduledoc false
  def append(trace, event) when is_list(trace), do: {:ok, trace ++ [event]}
  def append(trace, event), do: {:refused, :boundary_violation}
end
