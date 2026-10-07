defmodule Xaas.Ledger.TransferReverseAdverseCourtTest do
  @moduledoc """
  W982i independent adverse court for the W968c SPEC-27 `Xaas.Ledger.Transfer :reverse`
  sensitive-surface change. Independent lane: this file does not modify any W968c
  test or production code; it probes attack classes W968c's court
  (test/xaas/ledger/reversal_deepening_test.exs, SPEC-27 describe block) does not cover.

  Chicago-style: real Ecto.Adapters.SQL.Sandbox Postgres, real Ash actions, real
  persisted balances read back. async: false (AshEvents advisory lock; the
  concurrency leg shares the test's sandbox connection via Sandbox.allow/3).

  Verdicts (all asserted against observed behavior on a fresh test DB):

    Attack 1 -- originally a GAP (W982i): the compensating mint ignored the
      source account's balance (sufficiency validation dead code -- accept([])
      plus before_action forcing hid the ids from validation). FIXED by lane
      W983j: Xaas.Ledger.Changes.ReverseTransfer now invokes
      TransferSourceSufficiency explicitly after forcing the swapped
      attributes, so an underfunded compensating source (the original
      recipient spent the credit) refuses with the sufficiency error, and the
      W785 allow_overdraft context is honored as a real exemption on
      :reverse. Legs below assert the fixed behavior; the W982i-era
      negative-drain assertions are obsolete and were replaced.
    Attack 2 -- deny floor only, no authorizing policy: with authorize?: true ANY
      actor (nil actor included) is refused by the blanket forbid floor. No
      per-action authorizing policy for :reverse exists, and Xaas.Ledger.Account
      has no org/tenant attribute to scope one against. Report-only typed finding:
      REFUSED(policy-absent).
    Attack 3 -- holds: two concurrent Task.async processes over real Postgres, at
      most one reversal succeeds; the loser is refused reversal-aware.
    Attack 4 -- holds: a raw-SQL second reversal row for the same original
      violates ledger_transfers_reverses_transfer_id_index.
  """

  use ExUnit.Case, async: false
  require Ash.Query

  alias Xaas.Ledger.{Account, Balance, Transfer}

  @platform "platform:revenue:sla-credits"
  @treasury "w982i-treasury"

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
        |> Ash.read!(authorize?: false)
        |> Enum.max_by(& &1.transfer_id, fn -> nil end)
        |> case do
          nil -> nil
          balance -> balance.balance
        end
    end
  end

  defp open_account!(identifier) do
    case Account
         |> Ash.Query.filter(identifier: identifier)
         |> Ash.read_one!(authorize?: false) do
      nil ->
        Account
        |> Ash.Changeset.for_create(:open, %{identifier: identifier, currency: "USD"})
        |> Ash.create!(authorize?: false)

      account ->
        account
    end
  end

  # Real treasury->platform funding via the W785 per-caller overdraft opt-in
  # (treasury is deliberately unfunded; the negative balance IS the receivable).
  defp seed_platform_funding!(money) do
    treasury = open_account!(@treasury)
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

  # Real platform->org credit (the original transfer :reverse will target).
  # Returns the original transfer row. allow_overdraft lets the test control
  # the platform's resulting balance exactly.
  defp credit_org!(org_id, money) do
    platform = open_account!(@platform)
    org = open_account!(org_id)

    Transfer
    |> Ash.Changeset.for_create(
      :transfer,
      %{
        amount: money,
        timestamp: DateTime.utc_now(),
        from_account_id: platform.id,
        to_account_id: org.id
      },
      context: %{xaas_ledger: %{allow_overdraft: true}}
    )
    |> Ash.create!(authorize?: false)

    last_transfer_to!(org.id)
  end

  defp spend_from_org!(org_id, money) do
    org = open_account!(org_id)
    sink = open_account!("w982i-sink")

    Transfer
    |> Ash.Changeset.for_create(
      :transfer,
      %{
        amount: money,
        timestamp: DateTime.utc_now(),
        from_account_id: org.id,
        to_account_id: sink.id
      }
    )
    |> Ash.create!(authorize?: false)
  end

  defp last_transfer_to!(account_id) do
    Transfer
    |> Ash.Query.filter(to_account_id == ^account_id)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!(authorize?: false)
    |> hd()
  end

  defp reverse(original_id, context \\ %{}) do
    Transfer
    |> Ash.Changeset.for_create(:reverse, %{transfer_id: original_id}, context: context)
    |> Ash.create(authorize?: false)
  end

  defp money_composite("USD", amount) when is_binary(amount), do: {"USD", Decimal.new(amount)}

  # -- Attack 1: compensating mint vs. source account state -----------------

  describe "attack 1: compensating mint vs. source account state" do
    @tag :w982i_gap_sufficiency_noop
    test "FIXED: reversal after the recipient spent the funds refuses with the sufficiency error" do
      org_id = "org-w982i-spent-#{System.unique_integer([:positive])}"

      seed_platform_funding!(Money.new(:USD, "30.00"))
      original = credit_org!(org_id, Money.new(:USD, "20.00"))
      spend_from_org!(org_id, Money.new(:USD, "15.00"))

      # The compensating source (the org, which received the original credit
      # and spent 15 of its 20) holds only 5.00 against a 20.00 reversal.
      # W983j fix: the sufficiency check now runs against the real swapped
      # ids, so the reversal is refused with the same typed error the
      # ordinary :transfer action produces.
      assert {:error, %Ash.Error.Invalid{} = error} = reverse(original.id)

      error_text = Exception.message(error)
      assert error_text =~ "insufficient funds",
             "expected the sufficiency error, got: #{error_text}"

      # Refusal is consequence-free: the org keeps its 5.00, the platform its 10.00.
      assert Money.equal?(real_balance_for(org_id), Money.new(:USD, "5.00"))
      assert Money.equal?(real_balance_for(@platform), Money.new(:USD, "10.00"))
    end

    @tag :w982i_gap_sufficiency_noop
    test "FIXED: W785 allow_overdraft context is a real exemption on :reverse -- underfunded reversal admits with the context" do
      org_id = "org-w982i-vacuous-#{System.unique_integer([:positive])}"

      seed_platform_funding!(Money.new(:USD, "30.00"))
      original = credit_org!(org_id, Money.new(:USD, "20.00"))
      spend_from_org!(org_id, Money.new(:USD, "15.00"))

      # With the W785 per-caller overdraft context the underfunded reversal
      # admits (intentional receivable), leaving the org at -15.00.
      assert {:ok, %Transfer{}} =
               reverse(original.id, %{xaas_ledger: %{allow_overdraft: true}})

      assert Money.equal?(real_balance_for(org_id), Money.new(:USD, "-15.00"))
    end

    test "baseline sanity: reversal with the recipient still holding the full amount lands the recipient at 0" do
      org_id = "org-w982i-sane-#{System.unique_integer([:positive])}"

      seed_platform_funding!(Money.new(:USD, "30.00"))
      original = credit_org!(org_id, Money.new(:USD, "20.00"))

      assert {:ok, %Transfer{}} = reverse(original.id)

      assert Money.equal?(real_balance_for(org_id), Money.new(:USD, "0.00"))
      assert Money.equal?(real_balance_for(@platform), Money.new(:USD, "30.00"))
    end
  end

  # -- W983j follow-up leg: sufficiency fix re-verdict ------------------------

  describe "w983j follow-up: sufficiency on :reverse is live, not dead code" do
    test "underfunded compensating source refuses with the sufficiency error; sufficient funds still admits" do
      # Leg A (refusal): recipient spent the credit.
      org_spent = "org-w983j-underfunded-#{System.unique_integer([:positive])}"

      seed_platform_funding!(Money.new(:USD, "30.00"))
      original_spent = credit_org!(org_spent, Money.new(:USD, "20.00"))
      spend_from_org!(org_spent, Money.new(:USD, "20.00"))

      assert {:error, %Ash.Error.Invalid{} = error} = reverse(original_spent.id)
      assert Exception.message(error) =~ "insufficient funds"

      # Leg B (admission): recipient still holds the full amount; the
      # W968c happy path (reversal admitted, recipient back to zero) is
      # unbroken under the now-live check.
      org_full = "org-w983j-sufficient-#{System.unique_integer([:positive])}"
      original_full = credit_org!(org_full, Money.new(:USD, "20.00"))

      assert {:ok, %Transfer{} = reversal} = reverse(original_full.id)
      assert reversal.reverses_transfer_id == original_full.id
      assert Money.equal?(real_balance_for(org_full), Money.new(:USD, "0.00"))
      # platform: seed 30 - leg-A credit 20 - leg-B credit 20 + leg-B reversal 20
      assert Money.equal?(real_balance_for(@platform), Money.new(:USD, "10.00"))
    end
  end

  # -- Attack 2: authority ---------------------------------------------------

  describe "attack 2: authority / actor" do
    test "REFUSED(policy-absent): authorize?: true refuses :reverse for ANY actor -- deny floor only, no authorizing policy" do
      org_id = "org-w982i-authz-#{System.unique_integer([:positive])}"

      seed_platform_funding!(Money.new(:USD, "30.00"))
      original = credit_org!(org_id, Money.new(:USD, "10.00"))

      # Real authorization, nil actor: the blanket deny floor refuses. Note
      # this is a deny-everything floor, NOT a scoped authorizing policy: no
      # policy admits any actor to :reverse, and Xaas.Ledger.Account has no
      # org/tenant attribute a scoped policy could filter on. Recorded as
      # REFUSED(policy-absent), report-only, in the lane receipt.
      assert {:error, %Ash.Error.Forbidden{}} =
               Transfer
               |> Ash.Changeset.for_create(:reverse, %{transfer_id: original.id})
               |> Ash.create(authorize?: true)
    end
  end

  # -- Attack 3: concurrent replay ------------------------------------------

  describe "attack 3: concurrent :reverse replay (at most one wins)" do
    test "two concurrent attempts on the same transfer: at most one succeeds" do
      org_id = "org-w982i-conc-#{System.unique_integer([:positive])}"

      seed_platform_funding!(Money.new(:USD, "30.00"))
      original = credit_org!(org_id, Money.new(:USD, "10.00"))

      # Two real processes over real Postgres, joining the test's sandbox
      # connection (Sandbox.allow) so they observe this test's seeded rows.
      tasks =
        for _ <- 1..2 do
          Task.async(fn ->
            receive do
              :sandbox_go -> :ok
            end

            reverse(original.id)
          end)
        end

      Enum.each(tasks, &Ecto.Adapters.SQL.Sandbox.allow(Xaas.Repo, self(), &1.pid))
      Enum.each(tasks, &send(&1.pid, :sandbox_go))

      results = Task.await_many(tasks)

      assert results |> Enum.count(&match?({:ok, %Transfer{}}, &1)) <= 1,
             "at most one concurrent reversal may succeed: #{inspect(results)}"

      # Exactly one attempt may move money: org credited 10.00, one reversal
      # brings it to 0.00. Two successes would read 20.00.
      assert Money.equal?(real_balance_for(org_id), Money.new(:USD, "0.00")),
             "exactly one compensating mint may move money"

      loser_error_text =
        results
        |> Enum.flat_map(fn {tag, value} -> if tag == :error, do: [value], else: [] end)
        |> Enum.flat_map(fn
          %Ash.Error.Invalid{errors: errors} -> Enum.map(errors, & &1.message)
          _ -> []
        end)
        |> Enum.join("; ")

      assert loser_error_text =~ "already reversed",
             "the losing attempt must be refused reversal-aware, got: #{loser_error_text}"
    end
  end

  # -- Attack 4: DB-layer unique index --------------------------------------

  describe "attack 4: partial unique index at the DB layer" do
    test "raw SQL insert of a second reversal row violates ledger_transfers_reverses_transfer_id_index" do
      org_id = "org-w982i-db-#{System.unique_integer([:positive])}"

      seed_platform_funding!(Money.new(:USD, "30.00"))
      original = credit_org!(org_id, Money.new(:USD, "10.00"))
      {:ok, reversal} = reverse(original.id)

      # Raw repo SQL: a second reversal row for the SAME original, fresh
      # 16-byte id. The partial unique index must refuse it at the DB layer,
      # independent of any application guard.
      {:ok, new_id} = AshDoubleEntry.ULID.encode(:crypto.strong_rand_bytes(16))
      {:ok, orig_id} = AshDoubleEntry.ULID.dump_to_native(original.id, nil)
      {:ok, rev_from} = Ecto.UUID.dump(reversal.from_account_id)
      {:ok, rev_to} = Ecto.UUID.dump(reversal.to_account_id)

      # OBSERVED: raw repo SQL (not Ecto schema insert) raises the Postgrex
      # 23505 unique_violation naming the exact constraint, rather than Ecto's
      # ConstraintError translation (which applies to changeset inserts only).
      assert_raise Postgrex.Error,
                   ~r/ledger_transfers_reverses_transfer_id_index/,
                   fn ->
                     Xaas.Repo.query!(
                       "INSERT INTO ledger_transfers (id, amount, timestamp, from_account_id, to_account_id, reverses_transfer_id, inserted_at, updated_at) " <>
                         "VALUES ($1, ($2)::money_with_currency, $3, $4, $5, $6, $3, $3)",
                       [
                         new_id,
                         money_composite("USD", "10.00"),
                         reversal.timestamp,
                         rev_from,
                         rev_to,
                         orig_id
                       ]
                     )
                   end

      # The lawfully minted reversal is still the only one discoverable.
      count =
        Transfer
        |> Ash.Query.filter(reverses_transfer_id == ^original.id)
        |> Ash.read!(authorize?: false)
        |> length()

      assert count == 1
    end
  end
end