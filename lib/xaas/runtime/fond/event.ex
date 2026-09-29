defmodule Xaas.Runtime.FOND.Event do
  def observed(t, a \\ %{}), do: %{type: t, at: System.system_time(:microsecond), attrs: a}
end
