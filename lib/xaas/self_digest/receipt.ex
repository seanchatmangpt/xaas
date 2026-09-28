defmodule Xaas.SelfDigest.Receipt do
  @enforce_keys [:id, :subject, :work_id, :before, :after, :evidence]
  defstruct [:id, :subject, :work_id, :before, :after, :evidence, :previous, :authority]

  def seal(subject, work_id, before, after_value, evidence, opts \\ []) do
    previous = Keyword.get(opts, :previous)

    payload =
      {subject, work_id, before, after_value, Enum.map(evidence, & &1.digest), previous}

    id =
      payload
      |> :erlang.term_to_binary([:deterministic])
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    %__MODULE__{
      id: id,
      subject: subject,
      work_id: work_id,
      before: before,
      after: after_value,
      evidence: evidence,
      previous: previous,
      authority: Keyword.get(opts, :authority, :construct_only)
    }
  end

  def replayable?(receipt),
    do: is_binary(receipt.id) and not is_nil(receipt.before) and not is_nil(receipt.after)
end
