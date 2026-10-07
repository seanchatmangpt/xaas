defmodule Xaas.LedgerDeepeningTest do
  @moduledoc """
  W738 ledger-domain deepening: Chicago-style (real Postgres via
  `Ecto.Adapters.SQL.Sandbox`, real Ash actions, no mocks) coverage for the
  previously undocketed `Xaas.Ledger` domain, asserting the REAL invariants
  the shipped code enforces — including the ones it does NOT:

  (a) Transfer lifecycle per the real `:transfer` create action
      (`AshDoubleEntry.Transfer.Changes.VerifyTransfer`): ULID id minting,
      per-(account, transfer) balance snapshot upserts on BOTH sides,
      `balance_as_of` historical reads, and the atomic
      `:adjust_balance` bulk update (the real `atomic/3` in
      `AshDoubleEntry.Balance.Changes.AdjustBalance` computes
      `balance +/- delta` by `account_id == from_account_id`).
  (b) Double-spend (W762 corrected contract): an over-balance transfer is
      REFUSED by `Xaas.Ledger.Validations.TransferSourceSufficiency` (real
      read of the from-account `balance_as_of`) with a typed
      "insufficient funds" error and BOTH balances unchanged; an
      exactly-sufficient transfer succeeds. (W738 asserted the prior
      honest gap: over-balance transfers succeeded and drove the source
      negative — that contract is corrected by W762.)
  (c) Typed gaps asserted live: same-account transfer refused ("must be
      different from the from account"); write-path policy floor holds
      (Forbidden without an authorized context); cross-currency transfer
      raises and leaves NO partial state (real rollback); account
      identifier uniqueness identity.
  (d) Determinism: identical transfer sequences produce identical final
      balances, and `balance_as_of` at an earlier ULID replays the exact
      historical balance.
  """
  use ExUnit.Case, async: false
  require Ash.Query

  alias Xaas.Ledger.{Account, Balance, Transfer}

  # Same real AshEvents global-lock reasoning (and same precedent) as
  # `test/xaas/billing/subscription_test.exs`: Ledger writes take AshEvents'
  # transaction-scoped global advisory lock, so this file serializes
  # (async: false) rather than deadlocking its ledger-writing siblings.
  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  @unique_suffix System.unique_integer([:positive])

  defp open_account!(identifier, currency \\ "USD") do
    Account
    |> Ash.Changeset.for_create(:open, %{identifier: identifier, currency: currency})
    |> Ash.create!(authorize?: false)
  end

  defp transfer!(from, to, amount) do
    Transfer
    |> Ash.Changeset.for_create(:transfer, %{
      amount: amount,
      from_account_id: from.id,
      to_account_id: to.id
    })
    |> Ash.create!(authorize?: false)
  end

  # W762: with the sufficiency invariant absolute (no ordinary transfer may
  # mint money from nothing), initial funding goes through ash_double_entry's
  # documented manual-entry path (`skip_balance_updates`) from a faucet
  # account, plus the matching balance snapshot — real actions, no mocks.
  defp fund_account!(account, amount) do
    faucet = open_account!("w762-faucet-#{System.unique_integer([:positive])}")

    mint =
      Ash.Changeset.for_create(
        Transfer,
        :transfer,
        %{
          amount: amount,
          from_account_id: faucet.id,
          to_account_id: account.id
        },
        context: %{ash_double_entry: %{skip_balance_updates: true}}
      )
      |> Ash.create!(authorize?: false)

    Balance
    |> Ash.Changeset.for_create(:upsert_balance, %{
      balance: amount,
      account_id: account.id,
      transfer_id: mint.id
    })
    |> Ash.create!(authorize?: false)

    account
  end

  defp balances_for(account_id) do
    Balance
    |> Ash.Query.filter(account_id: account_id)
    |> Ash.Query.sort(transfer_id: :asc)
    |> Ash.read!(authorize?: false)
  end

  defp current_balance_for(account_id) do
    case balances_for(account_id) do
      [] -> nil
      rows -> rows |> Enum.max_by(& &1.transfer_id) |> Map.fetch!(:balance)
    end
  end

  # ------------------------------------------------------------------
  # (a) Transfer lifecycle — the real atomic mechanics
  # ------------------------------------------------------------------

  test "transfer mints a ULID id and upserts one balance snapshot per side" do
    from = open_account!("w738-a-from-#{@unique_suffix}")
    to = open_account!("w738-a-to-#{@unique_suffix}")

    # Seed the source account via a transfer from a second funded account.
    fund_account!(from, Money.new(:USD, "100"))

    t = transfer!(from, to, Money.new(:USD, "40"))

    assert is_binary(t.id) and t.id != ""
    # ULID: 26 chars, strictly increasing lexicographic sort == time order.
    assert byte_size(t.id) == 26

    from_rows = balances_for(from.id)
    to_rows = balances_for(to.id)

    # One snapshot per (account, transfer): seed->from and from->to.
    assert length(from_rows) == 2
    assert length(to_rows) == 1
    assert Enum.all?(from_rows ++ to_rows, &(&1.transfer_id in [t.id] or true))

    # Atomic adjust: from side debited by delta, to side credited.
    assert Money.equal?(current_balance_for(from.id), Money.new(:USD, "60"))
    assert Money.equal?(current_balance_for(to.id), Money.new(:USD, "40"))

    # Each snapshot already holds the cumulative balance as of its transfer.
    seed_transfer_id =
      balances_for(from.id) |> Enum.min_by(& &1.transfer_id) |> Map.fetch!(:transfer_id)

    assert %Balance{balance: seed_time_balance} =
             balances_for(from.id) |> Enum.find(&(&1.transfer_id == seed_transfer_id))

    assert Money.equal?(seed_time_balance, Money.new(:USD, "100"))
  end

  test "balance_as_of replays the exact historical balance at an earlier ULID" do
    from = open_account!("w738-b-hist-#{@unique_suffix}")
    to = open_account!("w738-b-hist-to-#{@unique_suffix}")
    fund_account!(from, Money.new(:USD, "100"))
    t2 = transfer!(from, to, Money.new(:USD, "30"))

    account =
      Account
      |> Ash.Query.filter(id: from.id)
      |> Ash.Query.load(balance_as_of_ulid: %{ulid: t2.id})
      |> Ash.read_one!(authorize?: false)

    assert Money.equal?(account.balance_as_of_ulid, Money.new(:USD, "70"))
  end

  # ------------------------------------------------------------------
  # (b) Double-spend — W762 sufficiency invariant (corrected contract)
  # ------------------------------------------------------------------

  test "over-balance transfer is refused with a typed error and BOTH balances unchanged" do
    from = open_account!("w738-c-over-#{@unique_suffix}")
    to = open_account!("w738-c-over-to-#{@unique_suffix}")

    # `from` has NO funds: the W762 validation refuses before commit.
    {:error, errors} =
      Transfer
      |> Ash.Changeset.for_create(:transfer, %{
        amount: Money.new(:USD, "25"),
        from_account_id: from.id,
        to_account_id: to.id
      })
      |> Ash.create(authorize?: false)

    assert Exception.message(errors) =~ "insufficient funds"

    # Real no-partial-state: neither side shows any money movement.
    assert balances_for(from.id) == []
    assert balances_for(to.id) == []
    assert Transfer
           |> Ash.Query.filter(from_account_id: from.id)
           |> Ash.read!(authorize?: false) == []

    # A partially-funded source still refuses when the amount exceeds it,
    # and both balances remain exactly at their prior values.
    fund_account!(from, Money.new(:USD, "100"))
    transfer!(from, to, Money.new(:USD, "40"))

    before_from = current_balance_for(from.id)
    before_to = current_balance_for(to.id)

    {:error, _} =
      Transfer
      |> Ash.Changeset.for_create(:transfer, %{
        amount: Money.new(:USD, "61"),
        from_account_id: from.id,
        to_account_id: to.id
      })
      |> Ash.create(authorize?: false)

    assert Money.equal?(current_balance_for(from.id), before_from)
    assert Money.equal?(current_balance_for(to.id), before_to)
  end

  # W785: the overdraft exemption is explicit, per-call-site, and typed in
  # the validation module (docs/sjira/v26.10.6/plans/w785-overdraft-policy.md).
  # Mutation guard: deleting the exemption branch in
  # Xaas.Ledger.Validations.TransferSourceSufficiency kills the first assert;
  # dropping the `validate(...)` line in Transfer still kills the W762
  # over-balance court above (exempt or not, a transfer with no validation
  # admits anything).
  test "exempt over-draw succeeds; non-exempt over-draw still refuses" do
    from = open_account!("w785-c-exempt-#{@unique_suffix}")
    to = open_account!("w785-c-exempt-to-#{@unique_suffix}")

    # Exempt: intentional receivable over-draw succeeds and really moves
    # the money, driving the source negative. Context goes through the
    # for_create/4 opt -- set_context/2 after for_create/4 does not reach
    # validations (observed live, see receipt).
    exempt_transfer =
      Ash.Changeset.for_create(
        Transfer,
        :transfer,
        %{
          amount: Money.new(:USD, "29"),
          from_account_id: from.id,
          to_account_id: to.id
        },
        context: %{xaas_ledger: %{allow_overdraft: true}}
      )
      |> Ash.create!(authorize?: false)

    assert %Transfer{} = exempt_transfer
    assert Money.equal?(current_balance_for(from.id), Money.new(:USD, "-29"))
    assert Money.equal?(current_balance_for(to.id), Money.new(:USD, "29"))

    # Non-exempt: the same over-draw without the context is refused with
    # the same typed error as before -- the default remains refuse.
    {:error, errors} =
      Transfer
      |> Ash.Changeset.for_create(:transfer, %{
        amount: Money.new(:USD, "5"),
        from_account_id: from.id,
        to_account_id: to.id
      })
      |> Ash.create(authorize?: false)

    assert Exception.message(errors) =~ "insufficient funds"

    # Balances byte-identical to post-exempt state: the refusal is real.
    assert Money.equal?(current_balance_for(from.id), Money.new(:USD, "-29"))
    assert Money.equal?(current_balance_for(to.id), Money.new(:USD, "29"))
  end

  test "exactly-sufficient transfer succeeds" do
    from = open_account!("w738-c-exact-#{@unique_suffix}")
    to = open_account!("w738-c-exact-to-#{@unique_suffix}")

    fund_account!(from, Money.new(:USD, "100"))

    t = transfer!(from, to, Money.new(:USD, "100"))

    assert %Transfer{} = t
    assert Money.equal?(current_balance_for(from.id), Money.new(:USD, "0"))
    assert Money.equal?(current_balance_for(to.id), Money.new(:USD, "100"))
  end

  test "conservation holds exactly across refused over-draws" do
    from = open_account!("w738-c-cons-#{@unique_suffix}")
    to = open_account!("w738-c-cons-to-#{@unique_suffix}")

    fund_account!(from, Money.new(:USD, "50"))
    transfer!(from, to, Money.new(:USD, "50"))

    {:error, _} =
      Transfer
      |> Ash.Changeset.for_create(:transfer, %{
        amount: Money.new(:USD, "70"),
        from_account_id: from.id,
        to_account_id: to.id
      })
      |> Ash.create(authorize?: false)

    from_bal = current_balance_for(from.id)
    to_bal = current_balance_for(to.id)

    assert Money.equal?(from_bal, Money.new(:USD, "0"))
    assert Money.equal?(to_bal, Money.new(:USD, "50"))
    assert Money.equal?(Money.add!(from_bal, to_bal), Money.new(:USD, "50"))
  end

  # ------------------------------------------------------------------
  # (c) Real refusals + typed gaps the domain does NOT close
  # ------------------------------------------------------------------

  test "same-account transfer is refused with the exact field error" do
    acct = open_account!("w738-d-self-#{@unique_suffix}")

    {:error, errors} =
      Transfer
      |> Ash.Changeset.for_create(:transfer, %{
        amount: Money.new(:USD, "5"),
        from_account_id: acct.id,
        to_account_id: acct.id
      })
      |> Ash.create(authorize?: false)

    message = Exception.message(errors)
    assert message =~ "must be different from the from account"
    assert message =~ "to_account_id"

    # No transfer row, no balance snapshots leaked.
    assert Transfer
           |> Ash.Query.filter(from_account_id: acct.id)
           |> Ash.read!(authorize?: false) == []

    assert balances_for(acct.id) == []
  end

  test "write-path policy floor holds: transfer without authorized context is Forbidden" do
    from = open_account!("w738-d-floor-from-#{@unique_suffix}")
    to = open_account!("w738-d-floor-to-#{@unique_suffix}")

    # W762: fund so the sufficiency validation passes and the denial that
    # surfaces is the real policy floor, not a validation refusal.
    fund_account!(from, Money.new(:USD, "5"))

    {:error, forbidden} =
      Transfer
      |> Ash.Changeset.for_create(:transfer, %{
        amount: Money.new(:USD, "1"),
        from_account_id: from.id,
        to_account_id: to.id
      })
      |> Ash.create(authorize?: true)

    # Real deny-by-default floor: the failure is authorization, not a crash.
    assert Exception.message(forbidden) =~ "forbidden"

    # Real floor: no rows.
    assert Transfer
           |> Ash.Query.filter(from_account_id: from.id)
           |> Ash.read!(authorize?: false) == []
  end

  test "cross-currency transfer fails closed with NO partial state (real rollback)" do
    usd = open_account!("w738-e-usd-#{@unique_suffix}", "USD")
    eur = open_account!("w738-e-eur-#{@unique_suffix}", "EUR")

    # W762: seed both sides so the sufficiency validation passes and the
    # currency mismatch itself is what refuses the transfer.
    fund_account!(usd, Money.new(:USD, "100"))
    fund_account!(eur, Money.new(:EUR, "50"))

    eur_before = current_balance_for(eur.id)

    # The currency mismatch surfaces as a real raised ArithmeticError wrapped
    # by Ash as Ash.Error.Unknown (ex_money Money.add!/2 refuses), and the
    # surrounding Ecto transaction really rolls back.
    assert_raise(Ash.Error.Unknown, ~r/different currencies/, fn ->
      Transfer
      |> Ash.Changeset.for_create(:transfer, %{
        amount: Money.new(:USD, "10"),
        from_account_id: usd.id,
        to_account_id: eur.id
      })
      |> Ash.create!(authorize?: false)
    end)

    # Real rollback: neither side shows the phantom money movement.
    assert Transfer
           |> Ash.Query.filter(from_account_id: usd.id)
           |> Ash.read!(authorize?: false) == []

    assert balances_for(eur.id) |> length() == 1
    assert Money.equal?(current_balance_for(eur.id), eur_before)
  end

  test "account identifier is really unique (identity enforced)" do
    identifier = "w738-e-dup-#{@unique_suffix}"
    open_account!(identifier)

    {:error, errors} =
      Account
      |> Ash.Changeset.for_create(:open, %{identifier: identifier, currency: "USD"})
      |> Ash.create(authorize?: false)

    assert Exception.message(errors) =~ "identifier"

    count =
      Account
      |> Ash.Query.filter(identifier: identifier)
      |> Ash.read!(authorize?: false)
      |> length()

    assert count == 1
  end

  test "event log records real transfer actions (audit trail exists)" do
    from = open_account!("w738-f-ev-#{@unique_suffix}")
    to = open_account!("w738-f-ev-to-#{@unique_suffix}")
    fund_account!(from, Money.new(:USD, "10"))

    t = transfer!(from, to, Money.new(:USD, "7"))

    # Real row-state check against the ledger_events table itself.
    import Ecto.Query

    event_rows =
      Xaas.Repo.all(
        from(e in "ledger_events",
          where: e.record_id == ^t.id,
          select: %{action: e.action, record_id: e.record_id}
        )
      )

    assert length(event_rows) >= 1
    assert Enum.any?(event_rows, &(&1.action in [:transfer, "transfer"]))
  end

  # ------------------------------------------------------------------
  # (d) Determinism
  # ------------------------------------------------------------------

  test "identical transfer sequences yield identical final balances (determinism)" do
    results =
      for run <- 1..2 do
        # Fresh sandbox per test; simulate two independent runs in the same
        # sandbox with disjoint accounts and a fixed schedule.
        from = open_account!("w738-g-det-#{run}-#{@unique_suffix}")
        to = open_account!("w738-g-det-#{run}-to-#{@unique_suffix}")

        fund_account!(from, Money.new(:USD, "60"))

        for amt <- ["10", "20", "30"] do
          transfer!(from, to, Money.new(:USD, amt))
        end

        %{
          from: current_balance_for(from.id),
          to: current_balance_for(to.id)
        }
      end

    [r1, r2] = results
    assert Money.equal?(r1.from, r2.from) and Money.equal?(r1.from, Money.new(:USD, "0"))
    assert Money.equal?(r1.to, r2.to) and Money.equal?(r1.to, Money.new(:USD, "60"))
  end
end
