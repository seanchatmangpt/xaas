defmodule Xaas.Ultracode.ProviderMesh.IdempotencyKey do
@moduledoc "Provider-mesh runtime primitive."
def derive(c,s,p), do: :crypto.hash(:sha256,:erlang.term_to_binary({c,s,p})) |> Base.encode16(case: :lower)
end
