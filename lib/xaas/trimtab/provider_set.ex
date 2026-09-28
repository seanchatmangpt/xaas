defmodule Xaas.Trimtab.ProviderSet do
  alias Xaas.Trimtab.Provider
  def candidates(ps,c,e \\ MapSet.new()), do: ps |> Enum.filter(&(Provider.supports?(&1,c) and not MapSet.member?(e,&1.id))) |> Enum.sort_by(&{&1.priority,&1.id})
  def select(ps,c,e \\ MapSet.new()), do: List.first(candidates(ps,c,e))
end