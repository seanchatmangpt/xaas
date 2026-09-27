defmodule Xaas.Ultracode.ProviderMesh.Router do
@moduledoc "Provider mesh runtime primitive."
alias Xaas.Ultracode.ProviderMesh.{Selector,Outcome,Failure}
def route(cs,cap,p,o \\ []), do: cs |> Selector.for_capability(cap) |> try_candidates(cap,p,o,[])
defp try_candidates([],cap,_,_,ex), do: {:error,{:providers_exhausted,cap,Enum.reverse(ex)}}
defp try_candidates([c|rest],cap,p,o,ex) do
case Outcome.normalize(c.module.invoke(cap,p,o)) do
{:ok,v} -> {:ok,%{provider:c.id,value:v,excluded:Enum.reverse(ex)}}
{:error,r} -> try_candidates(rest,cap,p,o,[{c.id,Failure.class(r),r}|ex])
end
end
end
