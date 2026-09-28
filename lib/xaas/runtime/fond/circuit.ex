defmodule Xaas.Runtime.FOND.Circuit do
 defstruct failures: %{}, threshold: 3
 def new(t \\ 3), do: %__MODULE__{threshold:t}
 def fail(c,id), do: %{c|failures:Map.update(c.failures,id,1,&(&1+1))}
 def open?(c,id), do: Map.get(c.failures,id,0)>=c.threshold
 def reset(c,id), do: %{c|failures:Map.delete(c.failures,id)}
end
