defmodule Xaas.Trimtab.WasmAdapter do
  alias Xaas.Trimtab.Hash
  def envelope(c,s,p) when is_binary(c) do b=%{component_id:c,subject_digest:s,payload:p}; {:ok,Map.put(b,:digest,Hash.sha256(b))} end
  def envelope(_,_,_), do: {:error,:invalid_component}
end