defmodule Xaas.Trimtab.Provider do
  @enforce_keys [:id,:module]; defstruct [:id,:module,capabilities: MapSet.new(),priority: 100]
  def new(id,m,c,p \\ 100), do: %__MODULE__{id: id,module: m,capabilities: MapSet.new(c),priority: p}
  def supports?(p,c), do: MapSet.member?(p.capabilities,c)
end