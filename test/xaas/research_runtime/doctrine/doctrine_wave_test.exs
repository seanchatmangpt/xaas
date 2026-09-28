defmodule Xaas.ResearchRuntime.DoctrineWaveTest do
  @moduledoc false
  def case(intent, authority) when intent != nil and authority == :none, do: {:ok, :intent_not_authority}
  def case(intent, authority), do: {:refused, :boundary_violation}
end
