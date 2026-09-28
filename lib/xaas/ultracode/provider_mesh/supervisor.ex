defmodule Xaas.Ultracode.ProviderMesh.Supervisor do
@moduledoc "Provider mesh runtime primitive."
use Supervisor
def start_link(o \\ []), do: Supervisor.start_link(__MODULE__,o,name:Keyword.get(o,:name,__MODULE__))
def init(o) do
r=Keyword.get(o,:registry,Xaas.Ultracode.ProviderMesh.Registry)
h=Keyword.get(o,:health_store,Xaas.Ultracode.ProviderMesh.HealthStore)
Supervisor.init([{Xaas.Ultracode.ProviderMesh.Registry,name:r},{Xaas.Ultracode.ProviderMesh.HealthStore,name:h}],strategy: :rest_for_one)
end
end
