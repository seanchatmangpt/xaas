defmodule Xaas.Runtime.ProviderFabric.Weighted do
  @moduledoc "Provider fabric weighted primitive."
  defstruct seed: 0
  def order(_w,es), do: Enum.sort_by(es,&{-Map.get(&1,:weight,1),inspect(Map.get(&1,:id))})
end
