defmodule Xaas.Trimtab.Evidence do
  alias Xaas.Trimtab.{Hash, Subject}
  @enforce_keys [:subject_digest, :claim, :witness, :digest]
  defstruct [:subject_digest, :claim, :witness, :falsifier, :provenance, :digest]

  def new(%Subject{digest: d}, claim, witness, falsifier \\ nil, p \\ %{}) do
    c = %{subject_digest: d, claim: claim, witness: witness, falsifier: falsifier, provenance: p}

    %__MODULE__{
      subject_digest: d,
      claim: claim,
      witness: witness,
      falsifier: falsifier,
      provenance: p,
      digest: Hash.sha256(c)
    }
  end
end
