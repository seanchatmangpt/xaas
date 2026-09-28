defmodule Xaas.Ultracode.ProviderMesh.ReconciliationLoop do
@moduledoc "Provider mesh runtime primitive."
use GenServer
def start_link(o), do: GenServer.start_link(__MODULE__,o,name: Keyword.get(o,:name,__MODULE__))
def init(o), do: {:ok,o,Keyword.get(o,:interval_ms,30_000)}
def handle_info(:timeout,s), do: {:noreply,s,Keyword.get(s,:interval_ms,30_000)}
end
