defmodule Xaas.CaseStudies.WdFa.VerificationReceipt do
  @moduledoc """
  Repository-local independent verification receipt for the WD CS2 fixture.

  It carries no external or production authority.
  """

  @authority_scope "REPO_LOCAL_FIXTURE"

  @spec issue(map()) :: {:ok, map()} | {:error, term()}
  def issue(attrs) when is_map(attrs) do
    producer = Map.fetch!(attrs, :producer_id)
    verifier = Map.fetch!(attrs, :verifier_id)

    if producer == verifier do
      {:error, :self_certification_refused}
    else
      payload = %{
        case_id: Map.fetch!(attrs, :case_id),
        candidate_standing: Map.fetch!(attrs, :candidate_standing),
        observed_disposition: Map.fetch!(attrs, :observed_disposition),
        evidence_ids: attrs |> Map.fetch!(:evidence_ids) |> Enum.sort(),
        producer_id: producer,
        verifier_id: verifier,
        authority_scope: @authority_scope
      }

      {:ok, Map.put(payload, :receipt_digest, digest(payload))}
    end
  end

  @spec verify(map()) :: boolean()
  def verify(receipt) when is_map(receipt) do
    with true <- receipt.authority_scope == @authority_scope,
         true <- receipt.producer_id != receipt.verifier_id,
         digest when is_binary(digest) <- receipt.receipt_digest do
      payload = Map.delete(receipt, :receipt_digest)
      digest == digest(payload)
    else
      _ -> false
    end
  end

  def verify(_), do: false

  defp digest(payload) do
    canonical = [
      payload.case_id,
      payload.candidate_standing,
      payload.observed_disposition,
      payload.evidence_ids,
      payload.producer_id,
      payload.verifier_id,
      payload.authority_scope
    ]

    "sha256:" <>
      (canonical
       |> :erlang.term_to_binary([:deterministic])
       |> then(&:crypto.hash(:sha256, &1))
       |> Base.encode16(case: :lower))
  end
end
