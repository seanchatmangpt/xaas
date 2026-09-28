defmodule Xaas.Runtime.ProviderFabric.Scheduler do
  @moduledoc "Provider fabric scheduler primitive."
  defstruct pending: []
  def enqueue(s,x), do: %{s|pending:[x|s.pending]}
end
