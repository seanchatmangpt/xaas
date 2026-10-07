defmodule Xaas.Ledger.ReversalDeepeningTest do
  @moduledoc """
  W799 reversal-deepening court for the Ledger refund/reversal surface
  (`lib/xaas/ledger/` + the billing SLA-credit flow
  `Xaas.Billing.ApprovalSlaCreditApply` /
  `Xaas.Billing.Changes.ApprovalSlaCreditApplyApprove`).

  ## The real reversal mechanism (read first, not invented)

  There is NO dedicated `:reverse`/`:refund`/`:undo` action anywhere on
  `Xaas.Ledger.Transfer`/`Account`/`Balance`. The real, only mechanism
  for undoing a credit is a COMPENSATING TRANSFER: a real `:transfer`
  create with `from_account_id`/`to_account_id` swapped, subject to the
  same W762/W785 `TransferSourceSufficiency` validation as any other
  transfer. This court tests that mechanism as it actually exists.

  ## Disclosed dependency on the W785 lane (file not touched by W799)

  `TransferSourceSufficiency` refuses any transfer whose source balance
  is below the amount, and the SLA credit path itself sets NO exemption
  context: `credit_sla/1` in `ApprovalSlaCreditApplyApprove` sets neither
  `xaas_ledger.allow_overdraft` nor `ash_double_entry.skip_balance_updates`.
  Consequence, observed on this exact working tree (HEAD a0723bf6,
  `feat/playwright-surface`): `test/xaas/billing/approval_sla_credit_apply_test.exs`
  is currently RED (3/5 passed, 2 failed) with real output
  `Invalid value provided for amount: insufficient funds: source balance
  $0.00 is less than transfer amount $25.00` -- the unfunded
  `platform:revenue:sla-credits` account cannot pay the credit. That is
  W785's lane (overdraft-policy reconciliation); W799 does not touch
  `lib/xaas/ledger/validations/`. To make the credit path executable
  here, each test seeds funding through the OTHER W785-documented
  channel -- the explicit per-call-site overdraft opt-in
  (`changeset.context[:xaas_ledger][:allow_overdraft] = true`, "the
  negative source balance IS the receivable") -- exactly the pattern
  billing charge sites use. That is a real transfer create against the
  real tables, not a mock.

  Chicago-style: real `Ecto.Adapters.SQL.Sandbox` Postgres, real Ash
  actions, real persisted balances read back. `async: false` for the same
  AshEvents global-advisory-lock reason as
  `Xaas.Billing.ApprovalSlaCreditApplyTest`.
  """
  use ExUnit.Case, async: false
  require Ash.Query

  alias Xaas.Billing.ApprovalSlaCreditApply
  alias Xaas.Ledger.{Account, Balance, Transfer}

  @platform "platform:revenue:sla-credits"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  # -- real read helpers ---------------------------------------------------

  defp account_id_for(identifier) do
    case Account
         |> Ash.Query.filter(identifier: identifier)
         |> Ash.read_one!(authorize?: false) do
      nil -> nil
      account -> account.id
    end
  end

  defp real_balance_for(identifier) do
    case account_id_for(identifier) do
      nil ->
        nil

      account_id ->
        Balance
        |> Ash.Query.filter(account_id: account_id)
        # "highest transfer_id wins" -- same rule as
        # Xaas.Billing.ApprovalSlaCreditApplyTest.real_balance_for/1.
        |> Ash.read!(authorize?: false)
        |> Enum.max_by(& &1.transfer_id, fn -> nil end)
        |> case do
          nil -> nil
          balance -> balance.balance
        end
    end
  end

  defp total_balance(org_ids) do
    [@platform | org_ids]
    |> Enum.map(fn ident ->
      case real_balance_for(ident) do
        nil -> Money.new(:USD, "0")
        money -> money
      end
    end)
    |> Enum.reduce(&Money.add!/2)
  end

  # -- real write helpers --------------------------------------------------

  defp open_account!(identifier) do
    case account_id_for(identifier) do
      nil ->
        Account
        |> Ash.Changeset.for_create(:open, %{identifier: identifier, currency: "USD"})
        |> Ash.create!(authorize?: false)

      account ->
        account
    end
  end

  # Seed funding through the W785-documented per-caller overdraft opt-in:
  # the treasury account deliberately over-draws (the negative balance IS
  # the receivable) and the platform account is funded by the same real
  # transfer. No other mint mechanism exists in the domain.
  defp seed_platform_funding!(money) do
    treasury = open_account!("w799-treasury")
    platform = open_account!(@platform)

    Transfer
    |> Ash.Changeset.for_create(
      :transfer,
      %{
        amount: money,
        timestamp: DateTime.utc_now(),
        from_account_id: treasury.id,
        to_account_id: platform.id
      },
      context: %{xaas_ledger: %{allow_overdraft: true}}
    )
    |> Ash.create!(authorize?: false)
  end

  defp new_credit_request!(org_id, cents) do
    ApprovalSlaCreditApply
    |> Ash.Changeset.for_create(:create, %{
      requested_by: "w799-requester",
      org_id: org_id,
      credit_amount_cents: cents
    })
    |> Ash.create!(authorize?: false)
  end

  defp approve_request!(request, approver) do
    request
    |> Ash.Changeset.for_update(:approve, %{approved_by: approver})
    |> Ash.update!(authorize?: false)
  end

  defp credit_via_approve!(org_id, cents) do
    org_id |> new_credit_request!(cents) |> approve_request!("w799-approver")
  end

  # The ONLY reversal mechanism that exists: a real compensating
  # `:transfer` with from/to swapped. Non-banging so a refusal surfaces
  # as `{:error, error}` instead of a raise.
  defp reverse_credit(org_id, money) do
    Transfer
    |> Ash.Changeset.for_create(:transfer, %{
      amount: money,
      timestamp: DateTime.utc_now(),
      from_account_id: account_id_for(org_id),
      to_account_id: account_id_for(@platform)
    })
    |> Ash.create(authorize?: false)
  end

  # -- (a) credit then compensating-transfer reversal ----------------------

  test "a credit applied then reversed leaves org balance restored and platform balance net of the round trip" do
    org_id = "org-w799-reversal-#{System.unique_integer([:positive])}"

    seed_platform_funding!(Money.new(:USD, "100.00"))

    credit_via_approve!(org_id, 25_00)

    assert Money.equal?(real_balance_for(org_id), Money.new(:USD, "25.00")),
           "credit must land in the org account before any reversal is attempted"

    assert Money.equal?(real_balance_for(@platform), Money.new(:USD, "75.00")),
           "platform balance must have decreased by the credited amount (seeded +100, credited -25)"

    assert {:ok, %Transfer{}} = reverse_credit(org_id, Money.new(:USD, "25.00"))

    assert Money.equal?(real_balance_for(org_id), Money.new(:USD, "0.00")),
           "org balance must be fully restored after the compensating transfer"

    # Platform: seeded +100, credited -25, reversed +25 => +100 net of the
    # round trip.
    assert Money.equal?(real_balance_for(@platform), Money.new(:USD, "100.00")),
           "platform balance must be back to its seeded value after credit+reverse"
  end

  # -- (b) refund idempotency ----------------------------------------------

  test "double-approve of the same credit request is refused typed and moves no money" do
    org_id = "org-w799-idem-approve-#{System.unique_integer([:positive])}"

    seed_platform_funding!(Money.new(:USD, "50.00"))
    request = new_credit_request!(org_id, 10_00)

    approved = approve_request!(request, "w799-approver")
    assert approved.approved_by == "w799-approver"

    # A second :approve against the already-approved record must be
    # refused typed by the DB-level `filter(expr(is_nil(approved_by)))`
    # guard.
    assert {:error, %Ash.Error.Invalid{}} =
             approved
             |> Ash.Changeset.for_update(:approve, %{approved_by: "w799-approver-2"})
             |> Ash.update(authorize?: false)

    assert Money.equal?(real_balance_for(org_id), Money.new(:USD, "10.00")),
           "exactly one real $10.00 credit must have landed, not a duplicate"
  end

  test "double-reverse is refused by sufficiency, not by any reversal-aware guard -- real typed gap" do
    org_id = "org-w799-idem-reverse-#{System.unique_integer([:positive])}"

    seed_platform_funding!(Money.new(:USD, "50.00"))
    credit_via_approve!(org_id, 10_00)

    assert {:ok, %Transfer{}} = reverse_credit(org_id, Money.new(:USD, "10.00"))
    assert Money.equal?(real_balance_for(org_id), Money.new(:USD, "0.00"))

    # Second reversal of the same credit: org balance is 0.00, so
    # TransferSourceSufficiency refuses it -- but ONLY by accident of the
    # org being at zero. There is no reversal-aware idempotency guard
    # (no :reverse action, no applied-reversal marker on Transfer):
    # if the org later received other funds, the same double-reverse
    # WOULD be admitted and would over-reverse. Typed gap recorded in
    # docs/sjira/v26.10.6/plans/w799-reversal-deepening.md.
    assert {:error, %Ash.Error.Invalid{} = error} =
             reverse_credit(org_id, Money.new(:USD, "10.00"))

    assert error_text(error) =~ "insufficient funds",
           "the double-reverse refusal must be the sufficiency refusal, not a reversal-aware one"

    assert Money.equal?(real_balance_for(@platform), Money.new(:USD, "50.00")),
           "no second reversal may have moved money"
  end

  # -- (c) balance conservation through credit+reverse cycles --------------

  test "total balance across platform+org+treasury is conserved through credit and reverse" do
    org_id = "org-w799-consv-#{System.unique_integer([:positive])}"

    seed_platform_funding!(Money.new(:USD, "100.00"))
    # Treasury intentionally carries the -100 receivable from the seed.
    seed_total = total_balance([org_id])

    credit_via_approve!(org_id, 30_00)

    assert Money.equal?(total_balance([org_id]), seed_total),
           "a credit moves money between accounts -- the total is invariant"

    assert {:ok, %Transfer{}} = reverse_credit(org_id, Money.new(:USD, "30.00"))

    assert Money.equal?(total_balance([org_id]), seed_total),
           "a compensating reversal is also total-invariant"
  end

  # -- (d) determinism -------------------------------------------------------

  test "credit+reverse cycles are deterministic in final balances for identical inputs" do
    org_a = "org-w799-det-a-#{System.unique_integer([:positive])}"
    org_b = "org-w799-det-b-#{System.unique_integer([:positive])}"

    seed_platform_funding!(Money.new(:USD, "200.00"))

    for org <- [org_a, org_b] do
      credit_via_approve!(org, 15_00)
      assert {:ok, %Transfer{}} = reverse_credit(org, Money.new(:USD, "15.00"))
    end

    assert Money.equal?(real_balance_for(org_a), real_balance_for(org_b))
    assert Money.equal?(real_balance_for(org_a), Money.new(:USD, "0.00"))
    assert Money.equal?(real_balance_for(@platform), Money.new(:USD, "200.00"))
  end

  # -- (e) W968c / SPEC-27: the dedicated :reverse action ------------------

  describe "W968c SPEC-27 :reverse action" do
    test "mints a real compensating transfer with from/to swapped and marks reverses_transfer_id" do
      org_id = "org-w968c-rev-#{System.unique_integer([:positive])}"

      seed_platform_funding!(Money.new(:USD, "60.00"))
      credit_via_approve!(org_id, 20_00)
      platform_before = real_balance_for(@platform)
      original = last_transfer_to!(account_id_for(org_id))

      assert {:ok, %Transfer{} = reversal} =
               Transfer
               |> Ash.Changeset.for_create(:reverse, %{transfer_id: original.id})
               |> Ash.create(authorize?: false)

      assert reversal.reverses_transfer_id == original.id
      assert reversal.from_account_id == original.to_account_id
      assert reversal.to_account_id == original.from_account_id
      assert Money.equal?(reversal.amount, original.amount)

      assert Money.equal?(real_balance_for(org_id), Money.new(:USD, "0.00"))
      assert Money.equal?(real_balance_for(@platform), Money.add!(platform_before, Money.new(:USD, "20.00")))
    end

    test "double-reverse is refused reversal-aware, even when the org has fresh funds" do
      org_id = "org-w968c-dbl-#{System.unique_integer([:positive])}"

      seed_platform_funding!(Money.new(:USD, "60.00"))
      credit_via_approve!(org_id, 20_00)
      original = last_transfer_to!(account_id_for(org_id))

      assert {:ok, %Transfer{}} =
               Transfer
               |> Ash.Changeset.for_create(:reverse, %{transfer_id: original.id})
               |> Ash.create(authorize?: false)

      # The mutation-kill leg: the org is deliberately re-funded so the old
      # sufficiency accident would ADMIT this second reversal. Only the
      # reversal-aware guard (read live from reverses_transfer_id) refuses.
      seed_platform_funding!(Money.new(:USD, "10.00"))

      # Platform now holds 60 - 20 + 10 = 50; fund the org directly via a
      # treasury->org transfer so the compensating transfer's sufficiency
      # check would pass if the guard were absent.
      Transfer
      |> Ash.Changeset.for_create(
        :transfer,
        %{
          amount: Money.new(:USD, "10.00"),
          timestamp: DateTime.utc_now(),
          from_account_id: account_id_for("w799-treasury"),
          to_account_id: account_id_for(org_id)
        },
        context: %{xaas_ledger: %{allow_overdraft: true}}
      )
      |> Ash.create!(authorize?: false)

      assert {:error, %Ash.Error.Invalid{} = error} =
               Transfer
               |> Ash.Changeset.for_create(:reverse, %{transfer_id: original.id})
               |> Ash.create(authorize?: false)

      assert error_text(error) =~ "already reversed",
             "refusal must be the reversal-aware guard, not sufficiency"

      assert Money.equal?(real_balance_for(@platform), Money.new(:USD, "70.00")),
             "no second reversal may have moved money"
    end

    test "unknown transfer_id refuses typed on field :transfer_id" do
      assert {:error, %Ash.Error.Invalid{} = error} =
               Transfer
               |> Ash.Changeset.for_create(:reverse, %{transfer_id: "01ARZ3NDEKTSV4RRFFQ69G5FAV"})
               |> Ash.create(authorize?: false)

      assert error_text(error) =~ "no such transfer"
    end

    test "the compensating transfer is itself discoverable by reverses_transfer_id and not re-reversible" do
      org_id = "org-w968c-disc-#{System.unique_integer([:positive])}"

      seed_platform_funding!(Money.new(:USD, "30.00"))
      credit_via_approve!(org_id, 10_00)
      original = last_transfer_to!(account_id_for(org_id))

      reversal =
        Transfer
        |> Ash.Changeset.for_create(:reverse, %{transfer_id: original.id})
        |> Ash.create!(authorize?: false)

      found =
        Transfer
        |> Ash.Query.filter(reverses_transfer_id == ^original.id)
        |> Ash.read_one!(authorize?: false)

      assert found.id == reversal.id

      # The guard is per-original: the reversal row is itself an ordinary
      # transfer from the guard's perspective, so re-reversing it (restoring
      # the credit) is lawful and marked against the REVERSAL, not the
      # original -- one compensating transfer per original, never two.
      assert {:ok, %Transfer{} = re_reversal} =
               Transfer
               |> Ash.Changeset.for_create(:reverse, %{transfer_id: reversal.id})
               |> Ash.create!(authorize?: false)

      assert re_reversal.reverses_transfer_id == reversal.id
      assert Money.equal?(real_balance_for(org_id), Money.new(:USD, "10.00"))
    end
  end

  defp last_transfer_to!(account_id) do
    Transfer
    |> Ash.Query.filter(to_account_id == ^account_id)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!(authorize?: false)
    |> hd()
  end

  defp error_text(%Ash.Error.Invalid{errors: errors}) do
    errors
    |> Enum.map(&Map.get(&1, :message, ""))
    |> Enum.join("; ")
  end
end
