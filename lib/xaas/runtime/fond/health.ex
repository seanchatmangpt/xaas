defmodule Xaas.Runtime.FOND.Health do
 def normalize(:ok), do: :healthy
 def normalize({:ok,_}), do: :healthy
 def normalize(:degraded), do: :degraded
 def normalize({:error,_}), do: :down
 def normalize(_), do: :unknown
end
