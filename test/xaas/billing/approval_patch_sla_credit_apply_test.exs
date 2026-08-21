defmodule Xaas.Billing.ApprovalPatchSlaCreditApplyTest do
  @moduledoc """
  Real Chicago-style tests: real `Ecto.Adapters.SQL.Sandbox`-backed
  Postgres (`Xaas.Repo`), real `Ash.Changeset.for_create`/`for_update` +
  `Ash.create!`/`Ash.update!` calls against the real
  `approval_patch_sla_credit_applies` table, real `Xaas.Ledger.Account`/`Balance`
  rows read back to assert on real persisted money movement. No mocking
  of `Xaas.Billing.ApprovalPatchSlaCreditApply`,
  `Xaas.Billing.Changes.ApprovalPatchSlaCreditApplyApprove`, or the ledger.
  """
  # async: false (real, disclosed, fourteenth-pass ERRC fix -- see
  # `docs/claude/diataxis/explanation/errc-innovation-grid.md`): this file
  # writes real `Xaas.Ledger.Account`/`Transfer` rows, both
  # `AshEvents.Events`-tracked resources with no `multitenancy do` block, so
  # every write takes AshEvents' single global `pg_advisory_xact_lock(
  # 2_147_483_647)` (the library default, unset by `Xaas.Ledger.EventLog`).
  # That lock is transaction-scoped and this test's Sandbox transaction
  # stays open until teardown, so under `async: true` any 2 of this file's
  # 6 real siblings running concurrently on separate connections contend
  # for the identical lock for the length of the slower test -- the real,
  # root-caused mechanism behind this session's worsening full-suite
  # Postgres "deadlock detected" flake. Slower (serialized relative to its
  # 5 named siblings, see `dev_seeds_test.exs`), but correct.
  use ExUnit.Case, async: false
  require Ash.Query

  alias Xaas.Billing.ApprovalPatchSlaCreditApply
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
    ApprovalPatchSlaCreditApply
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create!(authorize?: false)
  end

  defp approve!(record, approved_by) do
    record
    |> Ash.Changeset.for_update(:approve, %{approved_by: approved_by})
    |> Ash.update!(authorize?: false)
  end

  test "creating a request accepts a real org_id and credit_amount_cents" do
    org_id = "org-patch-sla-create-#{System.unique_integer([:positive])}"

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
    org_id = "org-patch-sla-approve-#{System.unique_integer([:positive])}"

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
    org_id = "org-patch-sla-noduplicate-#{System.unique_integer([:positive])}"

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
    org_id = "org-patch-sla-self-#{System.unique_integer([:positive])}"

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

  # Real Chicago-style coverage for the atomic-Ledger-write fix
  # (Xaas.Billing.Changes.ApprovalPatchSlaCreditApplyApprove now uses
  # `Ash.Changeset.after_action/2`, not `after_transaction/2`): a real
  # Ledger write failure must roll back `approved_by` too, never leave a
  # record "approved but never credited."
  #
  # This forces a REAL Ledger.Transfer failure deterministically, not via
  # a timing-dependent race. A real, concurrent `Xaas.Ledger.Account`
  # unique-constraint race (the scenario this fix's own design doc names)
  # was tried first via `Task.async` + `Ecto.Adapters.SQL.Sandbox.allow/3`
  # and empirically does NOT reproduce under Ecto Sandbox's testing model
  # (confirmed by a real 8-trial x 15-task probe run outside this suite:
  # 0 real constraint collisions out of 120 real concurrent attempts) --
  # Sandbox multiplexes every allowed process onto the SAME single
  # physical connection/transaction, so two real, independent Postgres
  # sessions racing a unique index (the real production failure mode)
  # cannot be reproduced this way; disclosed here rather than shipping a
  # test that looks like it covers the race but never actually exercises
  # the failure branch.
  #
  # Instead: `AshDoubleEntry.Transfer.Changes.VerifyTransfer` (real
  # dependency code,
  # `deps/ash_double_entry/lib/transfer/changes/verify_transfer.ex:45-49`)
  # really rejects any `:transfer` whose `from_account_id` equals its
  # `to_account_id`. Setting `org_id` to the EXACT same string as the
  # fixed `platform:revenue:sla-credits` identifier makes both
  # `open_or_get_account/1` calls inside `credit_sla/1` resolve to the
  # identical `Xaas.Ledger.Account` row -- a real, deterministic,
  # non-flaky way to force the real Ledger write to fail on every run.
  test "a real forced Ledger.Transfer failure rolls back approved_by too -- never approved-but-uncredited" do
    org_id = "platform:revenue:sla-credits"

    request =
      create!(%{
        requested_by: "requester-forced-fail",
        org_id: org_id,
        credit_amount_cents: 750
      })

    assert {:error, _error} =
             request
             |> Ash.Changeset.for_update(:approve, %{approved_by: "approver-forced-fail"})
             |> Ash.update(authorize?: false)

    persisted = Ash.reload!(request, authorize?: false)

    assert persisted.approved_by == nil,
           "a real forced Ledger.Transfer failure must roll back approved_by too -- " <>
             "this is exactly the after_transaction/2 bug the after_action/2 fix targets"

    # Real cross-check: the whole parent transaction rolled back, so the
    # Ledger.Account opened mid-flight (before the transfer failed) must
    # not have been left behind either -- no orphaned real Postgres row.
    assert real_balance_for(org_id) == nil,
           "expected no real Ledger.Account/Balance row to survive the real rolled-back transaction"
  end
end
