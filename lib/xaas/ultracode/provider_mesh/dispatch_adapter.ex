defmodule Xaas.Ultracode.ProviderMesh.DispatchAdapter do
@moduledoc "Provider mesh runtime primitive."
def invoke(d,e,o \\ []) do
case d.dispatch(e,o) do
{:ok,%{status: :ok}=r} -> {:ok,r}
{:ok,%{status:s}=r} -> {:error,{s,r}}
{:error,r} -> {:error,r}
end
end
end
