defmodule Xaas.ResearchRuntime.Steering do
  @moduledoc false
  def steer(context, observation) when context != nil and observation != nil, do: {:ok, %{context: context, observation: observation, select: false, do: false}}
  def steer(context, observation), do: {:refused, :boundary_violation}
end
