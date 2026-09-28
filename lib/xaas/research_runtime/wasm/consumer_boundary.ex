defmodule Xaas.ResearchRuntime.ConsumerBoundary do
  @moduledoc false
  def admit(required, offered) when MapSet.subset?(MapSet.new(required), MapSet.new(offered)), do: {:ok, :portable_consumer}
  def admit(required, offered), do: {:refused, :boundary_violation}
end
