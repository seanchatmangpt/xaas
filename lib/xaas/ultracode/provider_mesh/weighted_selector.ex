defmodule Xaas.Ultracode.ProviderMesh.WeightedSelector do
@moduledoc "Provider-mesh runtime primitive."
def select(cs,seed \\ 0), do: Enum.sort_by(cs,fn c -> {-c.weight,:erlang.phash2({seed,c.id})} end)
end
