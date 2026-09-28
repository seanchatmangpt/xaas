defmodule Xaas.Ultracode.ProviderMesh.HealthStore do
@moduledoc "Provider mesh runtime primitive."
use GenServer
def start_link(o \\ []), do: GenServer.start_link(__MODULE__,%{},name: Keyword.get(o,:name,__MODULE__))
def put(s \\ __MODULE__,x), do: GenServer.call(s,{:put,x})
def get(s \\ __MODULE__,id), do: GenServer.call(s,{:get,id})
def init(s), do: {:ok,s}
def handle_call({:put,x},_,s), do: {:reply,:ok,Map.put(s,x.provider_id,x)}
def handle_call({:get,id},_,s), do: {:reply,Map.get(s,id),s}
end
