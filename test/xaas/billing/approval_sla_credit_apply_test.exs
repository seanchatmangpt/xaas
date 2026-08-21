defmodule Xaas.Billing.ApprovalSlaCreditApplyTest do
  @moduledoc """
  Real Chicago-style tests: real `Ecto.Adapters.SQL.Sandbox`-backed
  Postgres (`Xaas.Repo`), real `Ash.Changeset.for_create`/`for_update` +
  `Ash.create!`/`Ash.update!` calls against the real
  `approval_sla_credit_applies` table, real `Xaas.Ledger.Account`/`Balance`
  rows read back to assert on real persisted money movement. No mocking
  of `Xaas.Billing.ApprovalSlaCreditApply`,
  `Xaas.Billing.Changes.ApprovalSlaCreditApplyApprove`, or the ledger.
  """
  use ExUnit.Case, async: true
  require Ash.Query

  alias Xaas.Billing.ApprovalSlaCreditApply
  alias Xaas.Ledger.{Account, Balance}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  # Real running-balance read, same helper shape (and same real
  # "highest transfer_id wins" reasoning) as
  # `Xaas.Billing.SubscriptionTest.real_balance_for/1`.
  defp real_balance_for(identifier) do
    case Account |> Ash.Query.filter(identifier: identifier) |> Ash.read_one!(authorize?: false) do
      nil ->
        nil

      account ->
        Balance
        |> Ash.Query.filter(account_id: account.id)
        |> Ash.read!(authorize?: false)
        |> Enum.max_by(& &1.transfer_id, fn -> nil end)
        |> case do
          nil -> nil
          balance -> balance.balance
        end
    end
  end

  defp create!(attrs) do
    ApprovalSlaCreditApply
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create!(authorize?: false)
  end

  defp approve!(record, approved_by) do
    record
    |> Ash.Changeset.for_update(:approve, %{approved_by: approved_by})
    |> Ash.update!(authorize?: false)
  end

  test "creating a request accepts a real org_id and credit_amount_cents" do
    org_id = "org-sla-create-#{System.unique_integer([:positive])}"

    request =
      create!(%{
        requested_by: "requester-1",
        org_id: org_id,
        credit_amount_cents: 1500
      })

    assert request.org_id == org_id
    assert request.credit_amount_cents == 1500
    assert request.approved_by == nil
  end

  test "approving from a distinct approver credits the org's real Ledger.Account by the real amount" do
    org_id = "org-sla-approve-#{System.unique_integer([:positive])}"

    request =
      create!(%{
        requested_by: "requester-2",
        org_id: org_id,
        credit_amount_cents: 2500
      })

    approved = approve!(request, "approver-2")

    assert approved.approved_by == "approver-2"

    org_balance = real_balance_for(org_id)
    sla_credits_balance = real_balance_for("platform:revenue:sla-credits")

    assert org_balance != nil,
           "expected a real Xaas.Ledger.Account/Balance to exist for #{org_id}"

    assert Money.equal?(org_balance, Money.new(:USD, "25.00"))
    assert Money.compare!(sla_credits_balance, Money.new(:USD, "0")) == :lt
  end

  test "approving twice does not double-credit" do
    org_id = "org-sla-noduplicate-#{System.unique_integer([:positive])}"

    request =
      create!(%{
        requested_by: "requester-3",
        org_id: org_id,
        credit_amount_cents: 1000
      })

    approved = approve!(request, "approver-3")

    # A second real :approve call against an already-approved record
    # (re-confirming the same approved_by) must not credit a second real
    # ledger amount.
    _ = approve!(approved, "approver-3")

    org_balance = real_balance_for(org_id)

    assert Money.equal?(org_balance, Money.new(:USD, "10.00")),
           "expected exactly one real $10.00 credit, not a duplicate"
  end

  test "self-approval is still rejected" do
    org_id = "org-sla-self-#{System.unique_integer([:positive])}"

    request =
      create!(%{
        requested_by: "requester-self",
        org_id: org_id,
        credit_amount_cents: 500
      })

    assert {:error, %Ash.Error.Invalid{}} =
             request
             |> Ash.Changeset.for_update(:approve, %{approved_by: "requester-self"})
             |> Ash.update(authorize?: false)

    assert real_balance_for(org_id) == nil,
           "expected no real Ledger.Account to have been opened -- self-approval was rejected"
  end
end
