defmodule Xaas.Trimtab.Observation do
  alias Xaas.Trimtab.{Hash, Subject}
  @enforce_keys [:subject_digest, :kind, :value, :digest]
  defstruct [:subject_digest, :kind, :value, :source, :digest]

  def new(%Subject{digest: d}, kind, value, source \\ :runtime) do
    c = %{subject_digest: d, kind: kind, value: value, source: source}
    {:ok, struct!(__MODULE__, Map.put(c, :digest, Hash.sha256(c)))}
  end

  def exact?(%__MODULE__{subject_digest: d}, %Subject{digest: d}), do: true
  def exact?(_, _), do: false
end
