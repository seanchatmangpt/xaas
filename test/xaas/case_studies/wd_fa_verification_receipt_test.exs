defmodule Xaas.CaseStudies.WdFaVerificationReceiptTest do
  use ExUnit.Case, async: true

  alias Xaas.CaseStudies.WdFa.VerificationReceipt

  @attrs %{
    case_id: "novel_x",
    candidate_standing: "UNKNOWN",
    observed_disposition: "MODE-X-NOVEL",
    evidence_ids: ["servo_trace", "media_scan", "lot_genealogy"],
    producer_id: "producer",
    verifier_id: "independent-verifier"
  }

  test "independent receipt verifies and stays repository-local" do
    assert {:ok, receipt} = VerificationReceipt.issue(@attrs)
    assert VerificationReceipt.verify(receipt)
    assert receipt.authority_scope == "REPO_LOCAL_FIXTURE"
    assert String.starts_with?(receipt.receipt_digest, "sha256:")
  end

  test "self-certification is refused" do
    attrs = %{@attrs | verifier_id: "producer"}
    assert {:error, :self_certification_refused} = VerificationReceipt.issue(attrs)
  end

  test "tampering invalidates receipt" do
    assert {:ok, receipt} = VerificationReceipt.issue(@attrs)

    refute VerificationReceipt.verify(%{receipt | observed_disposition: "TAMPERED"})
    refute VerificationReceipt.verify(%{receipt | authority_scope: "EXTERNAL"})
  end
end
