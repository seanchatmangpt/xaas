defmodule Xaas.Ultracode.ProviderMesh.Registry do
@moduledoc "Provider mesh runtime primitive."
use GenServer
def start_link(o \\ []), do: GenServer.start_link(__MODULE__,%{},name: Keyword.get(o,:name,__MODULE__))
def register(s \\ __MODULE__,c), do: GenServer.call(s,{:register,c})
def candidates(s \\ __MODULE__), do: GenServer.call(s,:candidates)
def init(s), do: {:ok,s}
def handle_call({:register,c},_,s), do: {:reply,:ok,Map.put(s,c.id,c)}
def handle_call(:candidates,_,s), do: {:reply,Map.values(s),s}
end
