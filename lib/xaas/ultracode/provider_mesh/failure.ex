defmodule Xaas.Ultracode.ProviderMesh.Failure do
@moduledoc "Provider-mesh runtime primitive."
@transient [:timeout,:rate_limited,:unavailable,:overloaded]
def class(r) when r in @transient, do: :transient
def class({r,_}) when r in @transient, do: :transient
def class(_), do: :terminal
end
