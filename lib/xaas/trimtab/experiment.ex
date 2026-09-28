defmodule Xaas.Trimtab.Experiment do
  alias Xaas.Trimtab.Hash; @enforce_keys [:id,:subject_digest,:control,:candidate]
  defstruct [:id,:subject_digest,:control,:candidate,:metrics]
  def new(d,c,k), do: %__MODULE__{id: Hash.sha256({d,c,k}),subject_digest: d,control: c,candidate: k,metrics: %{}}
  def record(e,k,v), do: %{e|metrics: Map.put(e.metrics,k,v)}
end