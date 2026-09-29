defmodule Xaas.Runtime.FOND.State do
  defstruct graph: nil, circuit: nil, trace: nil, attempts: 0

  def new(g),
    do: %__MODULE__{
      graph: g,
      circuit: Xaas.Runtime.FOND.Circuit.new(),
      trace: %Xaas.Runtime.FOND.Trace{}
    }
end
