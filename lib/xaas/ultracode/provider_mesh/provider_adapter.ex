defmodule Xaas.Ultracode.ProviderMesh.ProviderAdapter do
@moduledoc "Provider mesh runtime primitive."
def invoke(m,c,p,o \\ []), do: if(function_exported?(m,:invoke,3),do:m.invoke(c,p,o),else:{:error,:unsupported_provider})
end
