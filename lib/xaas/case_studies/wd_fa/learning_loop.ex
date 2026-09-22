defmodule Xaas.CaseStudies.WdFa.LearningLoop do
  @moduledoc """
  Verified repository-local UNKNOWN → MachineExperience → future KNOWN fixture.

  The compiler refuses unverified or disposition-mismatched receipts.
  """

  alias Xaas.CaseStudies.WdFa
  alias Xaas.CaseStudies.WdFa.VerificationReceipt

  @spec verify_novel_fixture() :: {:ok, map()} | {:error, term()}
  def verify_novel_fixture do
    state = WdFa.presentation_state("novel_x")

    with {:ok, receipt} <-
           VerificationReceipt.issue(%{
             case_id: "novel_x",
             candidate_standing: state.standing,
             observed_disposition: "MODE-X-NOVEL",
             evidence_ids: state.evidence,
             producer_id: "wd-fa-candidate-producer",
             verifier_id: "wd-fa-independent-observer"
           }),
         {:ok, experience} <- compile(receipt, "MODE-X-NOVEL") do
      {:ok, %{receipt: receipt, experience: experience}}
    end
  end

  @spec compile(map(), String.t()) :: {:ok, map()} | {:error, term()}
  def compile(receipt, mode_id) do
    cond do
      not VerificationReceipt.verify(receipt) ->
        {:error, :invalid_receipt}

      receipt.observed_disposition != mode_id ->
        {:error, :disposition_binding_failed}

      true ->
        {:ok,
         %{
           id: "MX-NOVEL-X-001",
           source_case: receipt.case_id,
           mode_id: mode_id,
           next_action: "RUN_NOVEL_X_STANDARD_WORK",
           receipt_digest: receipt.receipt_digest,
           verifier_id: receipt.verifier_id,
           applicability: "exact novel_x fixture class",
           evidence_ceiling: receipt.authority_scope,
           replay_identity: "NOVEL-X-REPLAY"
         }}
    end
  end
end
