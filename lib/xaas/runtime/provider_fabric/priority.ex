defmodule Xaas.Runtime.ProviderFabric.Priority do
  @moduledoc "Provider fabric priority primitive."
  defstruct direction: :desc
  def order(_p,es), do: Enum.sort_by(es,&{-Map.get(&1,:priority,0),inspect(Map.get(&1,:id))})
end
