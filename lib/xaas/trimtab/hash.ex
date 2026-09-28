defmodule Xaas.Trimtab.Hash do
  def sha256(term), do: :crypto.hash(:sha256,:erlang.term_to_binary(canonical(term))) |> Base.encode16(case: :lower)
  def canonical(m) when is_map(m), do: m |> Enum.map(fn {k,v}->{to_string(k),canonical(v)} end) |> Enum.sort()
  def canonical(l) when is_list(l), do: Enum.map(l,&canonical/1)
  def canonical(v), do: v
end