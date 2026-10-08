defmodule Xaas.Billing.InvoiceResourceCourtW984jkTest do
  @moduledoc """
  Lane W984jk unclaimed-family probe court on the invoice family
  (`Xaas.Billing.ApprovalInvoiceReconciliationApprove` + its validation and
  change module). Real sandboxed Postgres, real Ash actions, real persisted
  state, zero mocks. Mutation rationale per test: each test pins a branch
  the census (test/xaas_web/controllers/approval_invoice_reconciliation_approve_controller_test.exs,
  test/xaas/billing/approval_lifecycle_deepening_court_test.exs) does not
  reach.
  """

  use Xaas.DataCase

  alias Xaas.Billing.ApprovalInvoiceReconciliationApprove

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp uniq, do: System.unique_integer([:positive])

  test "1. create refuses :approved_by typed (REPAIRED: CREATE_APPROVED_BY_BYPASS closed, W984jz)" do
    requester = "requester-#{uniq()}"

    # W984jz repair: :approved_by is no longer on the :create accept list,
    # so a requester cannot mint an already-approved row — any attempt to
    # supply it is refused typed at the changeset layer.
    error =
      assert_raise Ash.Error.Invalid,
                   fn ->
                     ApprovalInvoiceReconciliationApprove
                     |> Ash.Changeset.for_create(
                       :create,
                       %{requested_by: requester, approved_by: requester},
                       authorize?: false
                     )
                     |> Ash.create!()
                   end

    assert Enum.any?(error.errors, fn e ->
             match?(%Ash.Error.Invalid.NoSuchInput{input: :approved_by}, e) or
               match?(%Ash.Error.Changes.InvalidAttribute{field: :approved_by}, e) or
               match?(%Ash.Error.Changes.InvalidArgument{field: :approved_by}, e)
           end)

    # Real state: every row that does get created starts unapproved, so the
    # W984k is_nil(approved_by) approve guard remains reachable.
    row =
      ApprovalInvoiceReconciliationApprove
      |> Ash.Changeset.for_create(:create, %{requested_by: requester}, authorize?: false)
      |> Ash.create!()

    persisted = Ash.get!(ApprovalInvoiceReconciliationApprove, row.id, authorize?: false)
    assert persisted.approved_by == nil
    assert persisted.requested_by == requester
  end

  test "2. fresh row approves through the real maker-checker path (REPAIRED: guard reachable)" do
    requester = "requester-#{uniq()}"
    checker = "checker-#{uniq()}"

    row =
      ApprovalInvoiceReconciliationApprove
      |> Ash.Changeset.for_create(:create, %{requested_by: requester}, authorize?: false)
      |> Ash.create!()

    # With the repair, no row can be minted pre-approved, so the W984k
    # WHERE-clause guard (is_nil(approved_by)) is reachable for every row
    # and a real second approver can sanction it through :approve.
    approved =
      row
      |> Ash.Changeset.for_update(:approve, %{approved_by: checker})
      |> Ash.update!(authorize?: false)

    persisted = Ash.get!(ApprovalInvoiceReconciliationApprove, row.id, authorize?: false)
    assert persisted.approved_by == checker
    assert persisted.requested_by == requester
  end

  test "3. create without requested_by is refused typed (allow_nil? false)" do
    # allow_nil?(false) on :requested_by — only exercised indirectly via
    # HTTP 400 shapes elsewhere; pinned here at the Ash action layer.
    assert_raise Ash.Error.Invalid, fn ->
      ApprovalInvoiceReconciliationApprove
      |> Ash.Changeset.for_create(:create, %{org_id: "org-#{uniq()}"}, authorize?: false)
      |> Ash.create!()
    end
  end
end
