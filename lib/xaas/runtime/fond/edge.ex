defmodule Xaas.Runtime.FOND.Edge do
 @enforce_keys [:id,:invoke]
 defstruct [:id,:invoke,capabilities: [],cost: 1]
 def new(id,fun,opts \\ []), do: struct!(__MODULE__,[id:id,invoke:fun]++opts)
 def supports?(e,c), do: c in e.capabilities or :any in e.capabilities
end
