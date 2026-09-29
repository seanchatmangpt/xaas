defmodule Xaas.Sa2a.ReceiptFeedbackTest do
  use ExUnit.Case, async: true

  alias Xaas.Sa2a.ReceiptFeedback

  test "failed XaaS receipt becomes an SA2A replan decision with exact subject" do
    assert %{kind: :replan, subject: "sha256:subject", reason: :failed, authority: :none} =
             ReceiptFeedback.decision(%{
               receipt_id: "r1",
               exact_subject: "sha256:subject",
               outcome: :failed
             })
  end

  test "unknown XaaS receipt requires reconcile before replan" do
    assert %{kind: :replan, reason: :unknown_outcome_reconcile_first, authority: :none} =
             ReceiptFeedback.decision(%{
               receipt_id: "r2",
               exact_subject: "sha256:subject",
               outcome: "new-provider-verdict"
             })
  end
end
