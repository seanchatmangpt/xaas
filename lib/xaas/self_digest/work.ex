defmodule Xaas.SelfDigest.Work do
  @enforce_keys [:id, :subject, :gap, :construct]
  defstruct [:id, :subject, :gap, :construct, :acceptance, :authority, state: :ready]

  def from_gap(gap, construct, opts \\ []) when is_function(construct, 1) do
    id = Keyword.get(opts, :id, stable_id(gap))

    %__MODULE__{
      id: id,
      subject: gap.subject,
      gap: gap,
      construct: construct,
      acceptance: gap.falsifier,
      authority: Keyword.get(opts, :authority, :construct_only)
    }
  end

  defp stable_id(gap) do
    digest =
      {gap.subject, gap.claim}
      |> :erlang.term_to_binary([:deterministic])
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)
      |> binary_part(0, 16)

    "work-" <> digest
  end
end
