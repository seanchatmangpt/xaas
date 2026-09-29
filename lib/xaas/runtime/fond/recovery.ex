defmodule Xaas.Runtime.FOND.Recovery do
  def route({:local, _}), do: :repair_local
  def route({k, _}) when k in [:timeout, :rate_limit, :auth_missing, :refused], do: :exclude_edge
  def route(_), do: :exclude_edge
end
