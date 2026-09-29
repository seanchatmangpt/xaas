defmodule Xaas.Runtime.FOND.Receipt do
  def new(s, e, o),
    do: %{subject: s, edge: e, outcome: o, observed_at: System.system_time(:microsecond)}

  def replay_key(r),
    do: :crypto.hash(:sha256, :erlang.term_to_binary(r)) |> Base.encode16(case: :lower)
end
