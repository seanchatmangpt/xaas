defmodule Xaas.Trimtab.SteeringSignal do
  alias Xaas.Trimtab.{Hash, Subject}
  @enforce_keys [:subject_digest, :objective, :digest]
  defstruct [:subject_digest, :objective, :digest, constraints: [], exclusions: []]

  def new(%Subject{digest: d}, o, opts \\ []) when is_binary(o) do
    c = %{
      subject_digest: d,
      objective: o,
      constraints: Keyword.get(opts, :constraints, []),
      exclusions: Keyword.get(opts, :exclusions, [])
    }

    {:ok, struct!(__MODULE__, Map.put(c, :digest, Hash.sha256(c)))}
  end
end
