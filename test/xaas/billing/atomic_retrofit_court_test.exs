defmodule Xaas.Billing.AtomicRetrofitCourtTest do
  @moduledoc """
  SPEC-08 / W729-GAP-4 atomic-update retrofit court (lane W984cc; contract
  `docs/sjira/v26.10.6/plans/w984bd-atomic-retrofit.md`, staged plan
  `w984az-w729-spec08.md`).

  Real Chicago-style court over real Postgres (`Ecto.Adapters.SQL.Sandbox`)
  and the real `Xaas.Ledger` Account/Transfer resources. No mocking.

  Blocks:

    (a) Rollback semantics: a real, forced `Xaas.Ledger.Transfer` failure
        inside the money-mover's `after_action/2` must roll the approval
        write back -- never approved-but-uncredited.
    (b) Exactly-one-success double-approve via `Task.async`: two concurrent
        `:approve` calls against the same pending request must yield
        exactly one success and exactly one real `Xaas.Ledger.Transfer`.
        Run FIRST against the unconverted money-mover
        (`ApprovalPatchSlaCreditApply :approve`) to decide W984az's named
        falsifier: if it passes unchanged against the unconverted
        `after_action` body, SPEC-08 reduces to disclosure-only for the
        money-movers plus conversion of the three convert-candidates
        (sites 3/6/8).
    (c) Converted-site leg: the same double-approve court driven against
        converted site #8 (`ApprovalQuotaOverride :approve`, atomic, no
        `require_atomic?(false)`), the target of the receipt's mutation
        kill.
  """
  use ExUnit.Case, async: false
  require Ash.Query

  alias Xaas.Billing.ApprovalPatchSlaCreditApply
  alias Xaas.Billing.ApprovalQuotaOverride
  alias Xaas.Ledger.{Account, Transfer}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp org_account(org_id) do
    Account
    |> Ash.Query.filter(identifier: org_id)
    |> Ash.read_one!(authorize?: false)
  end

  defp transfers_to_org(org_id) do
    case org_account(org_id) do
      nil ->
        []

      account ->
        Transfer
        |> Ash.Query.filter(to_account_id: account.id)
        |> Ash.read!(authorize?: false)
    end
  end

  defp create_patch!(attrs) do
    ApprovalPatchSlaCreditApply
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create!(authorize?: false)
  end

  defp create_quota!(attrs) do
    ApprovalQuotaOverride
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create!(authorize?: false)
  end

  defp approve_attempt(record, approved_by) do
    record
    |> Ash.Changeset.for_update(:approve, %{approved_by: approved_by})
    |> Ash.update(authorize?: false)
  end

  # Block (b): exactly-one-success double-approve, driven FIRST against the
  # UNCONVERTED money-mover to decide the falsifier.
  test "double approve on unconverted patch SLA credit apply: exactly one success, exactly one transfer" do
    org_id = "org-atomic-court-#{System.unique_integer([:positive])}"

    pending = create_patch!(%{
      requested_by: "requester-court",
      org_id: org_id,
      credit_amount_cents: 2100
    })

    results =
      Enum.map(1..2, fn i ->
        Task.async(fn ->
          approve_attempt(pending, "approver-court-#{i}")
        end)
      end)
      |> Enum.map(&Task.await/1)

    successes = Enum.count(results, &match?({:ok, _}, &1))

    assert successes == 1,
           "expected exactly one of two concurrent approves to succeed, got: #{inspect(results)}"

    assert [%Transfer{}] = transfers_to_org(org_id)
  end

  # Block (a): rollback semantics on the unconverted money-mover -- a real,
  # forced Transfer failure must roll approved_by back (never
  # approved-but-uncredited).
  test "forced transfer failure on unconverted patch SLA credit apply rolls back approved_by" do
    org_id = "platform:revenue:sla-credits"

    pending =
      create_patch!(%{
        requested_by: "requester-court-rollback",
        org_id: org_id,
        credit_amount_cents: 750
      })

    assert {:error, _error} =
             approve_attempt(pending, "approver-court-rollback")

    persisted = Ash.reload!(pending, authorize?: false)

    assert persisted.approved_by == nil,
           "a real forced Ledger.Transfer failure must roll back approved_by too"

    assert transfers_to_org(org_id) == [],
           "no transfer may survive the rolled-back transaction"
  end

  # Block (c): converted-site leg -- same double-approve court against
  # converted site #8 (ApprovalQuotaOverride :approve, atomic).
  test "double approve on converted quota override: exactly one success" do
    org_id = "org-quota-court-#{System.unique_integer([:positive])}"

    pending =
      create_quota!(%{
        requested_by: "requester-quota-court",
        org_id: org_id
      })

    results =
      Enum.map(1..2, fn i ->
        Task.async(fn ->
          approve_attempt(pending, "approver-quota-court-#{i}")
        end)
      end)
      |> Enum.map(&Task.await/1)

    successes = Enum.count(results, &match?({:ok, _}, &1))

    assert successes == 1,
           "expected exactly one of two concurrent approves to succeed, got: #{inspect(results)}"
  end
end
