defmodule Xaas.SelfDigest.Evidence do
  @enforce_keys [:subject, :work_id, :kind, :value]
  defstruct [:subject, :work_id, :kind, :value, :provenance, :digest]

  def new(subject, work_id, kind, value, provenance \\ %{}) do
    core = {subject, work_id, kind, value, provenance}

    %__MODULE__{
      subject: subject,
      work_id: work_id,
      kind: kind,
      value: value,
      provenance: provenance,
      digest: digest(core)
    }
  end

  def same_subject?(%__MODULE__{subject: subject}, subject), do: true
  def same_subject?(_, _), do: false

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
