defmodule Xaas.Runtime.ProviderFabric.Recovery do
  @moduledoc "Provider fabric recovery primitive."
  defstruct local_retries: 1
  def route(:edge_failure), do: :exclude_edge
    def route(:local_failure), do: :repair_local
end
