defmodule Xaas.Billing.ApprovalPatchSlaCreditApplyApproveCourtW650v5Test do
  @moduledoc """
  W650v5 coverage burn-down court for `Xaas.Billing.Changes.ApprovalPatchSlaCreditApplyApprove`
  (lib/xaas/billing/changes/approval_patch_sla_credit_apply_approve.ex, 148 lines,
  zero direct test references at census time). The RESOURCE
  (`Xaas.Billing.ApprovalPatchSlaCreditApply`) had HTTP-level tests
  (approval_patch_sla_credit_apply_controller_test.exs) and validation-level
  coverage in approval_lifecycle_deepening_court_test.exs, but every one of
  those asserts on approval state only -- NONE asserts the real
  `Xaas.Ledger` money movement the change module performs inside the
  `:approve` transaction. The sibling `ApprovalSlaCreditApply` has exactly
  this Chicago suite (approval_sla_credit_apply_test.exs); this file ports
  that suite to the patch variant.

  Chicago style: real `Ecto.Adapters.SQL.Sandbox`-backed Postgres, real
  `Ash` create/update against the real `approval_patch_sla_credit_applies`
  table, real `Xaas.Ledger.Account`/`Balance` rows read back to assert on
  real persisted money movement. No mocks.

  # Mutation rationale per test

  1. credit test: a mutant that skips `credit_sla/1` (or credits the wrong
     amount, or credits a revenue account instead of the dedicated
     `platform:revenue:sla-credits` liability account) is killed by the
     exact-balance assertions on BOTH accounts.
  2. cents-conversion test: a mutant that drops the `Decimal.div(..., 100)`
     (crediting cents as dollars) or mis-rounds is killed by the exact
     $123.45 assertion.
  3. double-credit test: a mutant that drops the
     `filter(expr(is_nil(approved_by)))` DB guard (or the
     `newly_approved?/2` pre-state check) is killed by the typed-refusal +
     unchanged-balance assertions.
  4. self-approval test: a mutant that drops
     `ApprovalPatchSlaCreditApplyRequiresApprover` is killed by the refusal
     + no-account-opened assertions.
  5. forced-failure test: a mutant reverting `after_action/2` ->
     `after_transaction/2` (the module's own disclosed historical bug) is
     killed by the `approved_by` rollback + no-orphaned-ledger-row
     assertions.
  """

  use ExUnit.Case, async: false

  # async: false, same real disclosed reason as the sibling suite
  # (approval_sla_credit_apply_test.exs): AshEvents' single global
  # advisory lock on the Ledger resources under open sandbox transactions
  # deadlocks under async: true.
  require Ash.Query

  alias Xaas.Billing.ApprovalPatchSlaCreditApply
  alias Xaas.Ledger.{Account, Balance}

  @platform_account "platform:revenue:sla-credits"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp real_balance_for(identifier) do
    case Account
         |> Ash.Query.filter(identifier: identifier)
         |> Ash.read_one!(authorize?: false) do
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
    ApprovalPatchSlaCreditApply
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create!(authorize?: false)
  end

  defp approve!(record, approved_by) do
    record
    |> Ash.Changeset.for_update(:approve, %{approved_by: approved_by})
    |> Ash.update!(authorize?: false)
  end

  test "first approve credits the org's real Ledger account by the exact amount and the dedicated platform liability account goes negative (overdraft opt-in witnessed)" do
    org_id = "org-w650v5-credit-#{System.unique_integer([:positive])}"

    request =
      create!(%{
        requested_by: "w650v5-requester-1",
        org_id: org_id,
        credit_amount_cents: 2500
      })

    approved = approve!(request, "w650v5-approver-1")

    assert approved.approved_by == "w650v5-approver-1"

    org_balance = real_balance_for(org_id)

    assert org_balance != nil,
           "expected a real Xaas.Ledger.Account/Balance to exist for #{org_id}"

    assert Money.equal?(org_balance, Money.new(:USD, "25.00"))

    sla_credits_balance = real_balance_for(@platform_account)

    assert sla_credits_balance != nil,
           "expected the dedicated #{@platform_account} liability account to exist"

    assert Money.compare!(sla_credits_balance, Money.new(:USD, "0")) == :lt,
           "expected the never-funded platform liability account to go NEGATIVE " <>
             "(the W785/W799/W835 allow_overdraft opt-in), got: #{inspect(sla_credits_balance)}"
  end

  test "credit_amount_cents converts to USD exactly -- cents are not credited as dollars" do
    org_id = "org-w650v5-convert-#{System.unique_integer([:positive])}"

    request =
      create!(%{
        requested_by: "w650v5-requester-2",
        org_id: org_id,
        credit_amount_cents: 12_345
      })

    approve!(request, "w650v5-approver-2")

    org_balance = real_balance_for(org_id)

    assert Money.equal?(org_balance, Money.new(:USD, "123.45")),
           "expected an exact cents->dollars conversion (12345c = $123.45), got: #{inspect(org_balance)}"
  end

  test "second approve is refused typed by the DB-level guard and does not double-credit" do
    org_id = "org-w650v5-idem-#{System.unique_integer([:positive])}"

    request =
      create!(%{
        requested_by: "w650v5-requester-3",
        org_id: org_id,
        credit_amount_cents: 1000
      })

    approved = approve!(request, "w650v5-approver-3")

    # W746 corrected contract, patch variant: a second real :approve against
    # the already-approved record (held post-update by this caller) is
    # refused typed by the `filter(expr(is_nil(approved_by)))` WHERE guard.
    assert {:error, %Ash.Error.Invalid{}} =
             approved
             |> Ash.Changeset.for_update(:approve, %{approved_by: "w650v5-approver-3"})
             |> Ash.update(authorize?: false)

    org_balance = real_balance_for(org_id)

    assert Money.equal?(org_balance, Money.new(:USD, "10.00")),
           "expected exactly one real $10.00 credit, not a duplicate; got: #{inspect(org_balance)}"
  end

  test "self-approval is refused and opens no real Ledger account" do
    org_id = "org-w650v5-self-#{System.unique_integer([:positive])}"

    request =
      create!(%{
        requested_by: "w650v5-requester-self",
        org_id: org_id,
        credit_amount_cents: 500
      })

    assert {:error, %Ash.Error.Invalid{}} =
             request
             |> Ash.Changeset.for_update(:approve, %{approved_by: "w650v5-requester-self"})
             |> Ash.update(authorize?: false)

    assert real_balance_for(org_id) == nil,
           "expected no real Ledger.Account to have been opened -- self-approval was rejected"
  end

  test "a real forced Ledger.Transfer failure rolls back approved_by too -- never approved-but-uncredited" do
    # Deterministic real failure: org_id equal to the fixed platform
    # identifier makes both open_or_get_account/1 calls resolve to the SAME
    # account, and AshDoubleEntry's real VerifyTransfer change rejects any
    # transfer whose from == to. No mocks, no timing races.
    org_id = @platform_account

    request =
      create!(%{
        requested_by: "w650v5-requester-ff",
        org_id: org_id,
        credit_amount_cents: 750
      })

    assert {:error, _error} =
             request
             |> Ash.Changeset.for_update(:approve, %{approved_by: "w650v5-approver-ff"})
             |> Ash.update(authorize?: false)

    persisted = Ash.reload!(request, authorize?: false)

    assert persisted.approved_by == nil,
           "a real forced Ledger.Transfer failure must roll back approved_by too -- " <>
             "the after_transaction/2 -> after_action/2 isolation this change module discloses"

    assert real_balance_for(org_id) == nil,
           "expected no real Ledger.Account/Balance row to survive the real rolled-back transaction"
  end
end
