defmodule Xaas.Ultracode.ProviderMesh.Capability do
  @moduledoc "Provider-mesh runtime primitive."
  def supported?(p, c) when is_atom(c), do: c in p.capabilities()
  def supported?(_, _), do: false
end
