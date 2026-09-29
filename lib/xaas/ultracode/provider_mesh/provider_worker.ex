defmodule Xaas.Ultracode.ProviderMesh.ProviderWorker do
  @moduledoc "Provider mesh runtime primitive."
  use GenServer
  def start_link(o), do: GenServer.start_link(__MODULE__, o)

  def invoke(pid, cap, payload, o \\ []),
    do: GenServer.call(pid, {:invoke, cap, payload, o}, Keyword.get(o, :timeout, 30_000))

  def init(o), do: {:ok, o}
  def handle_call({:invoke, c, p, o}, _, s), do: {:reply, s[:module].invoke(c, p, o), s}
end
