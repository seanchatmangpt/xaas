defmodule Xaas.Runtime.FOND.Attempt do
 defstruct [:edge_id,:started_at,:finished_at,:outcome]
 def start(id), do: %__MODULE__{edge_id: id,started_at: System.monotonic_time(:microsecond)}
 def finish(a,o), do: %{a|finished_at: System.monotonic_time(:microsecond),outcome: o}
end
