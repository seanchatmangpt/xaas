defmodule Xaas.Runtime.FOND.Trace do
 defstruct events: []
 def add(t,e), do: %{t|events: [e|t.events]}
 def replay(t), do: Enum.reverse(t.events)
end
