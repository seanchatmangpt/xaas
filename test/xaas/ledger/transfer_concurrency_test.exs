defmodule Xaas.Ledger.TransferConcurrencyTest do
  @moduledoc """
  Chicago-style adversarial concurrency qualification for `Xaas.Ledger.Transfer`.

  Modeled on `ash_r2rml`'s `adversarial/concurrency_test.exs` pattern: real
  concurrent `Task.async_stream` calls against a real Postgres sandbox (shared mode,
  not per-process, so every task hits the same real transactions/locks), then a
  state-based assertion on the real final balance -- not on call counts or mocked
  interactions. This is the most consequential concrete gap named in this session's
  own gap analysis: Ledger `Transfer`/`Balance` arithmetic previously had zero
  concurrency coverage anywhere in xaas, despite being the domain most exposed to a
  double-spend/lost-update race.

  `AshDoubleEntry.Transfer.Changes.VerifyTransfer` (`deps/ash_double_entry/lib/
  transfer/changes/verify_transfer.ex`) locks both accounts (`:lock_accounts`,
  `AshDoubleEntry.Account.Preparations.LockForUpdate`) before computing and
  upserting each account's new `Xaas.Ledger.Balance` row -- this test proves that
  locking actually serializes concurrent transfers between the same two real
  accounts rather than merely asserting the code exists.
  """

  use ExUnit.Case

  require Ash.Query

  alias Xaas.Ledger.{Account, Balance, Transfer}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo, sandbox: false)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, :manual)
    end)

    :ok
  end

  defp open_account!(identifier) do
    Account
    |> Ash.Changeset.for_create(:open, %{identifier: identifier, currency: "USD"})
    |> Ash.create!(authorize?: false)
  end

  defp transfer!(from, to, amount) do
    Transfer
    |> Ash.Changeset.for_create(:transfer, %{
      amount: Money.new!(amount, :USD),
      from_account_id: from.id,
      to_account_id: to.id
    })
    |> Ash.create!(authorize?: false)
  end

  defp latest_balance!(account) do
    Balance
    |> Ash.Query.filter(account_id == ^account.id)
    |> Ash.Query.sort(transfer_id: :desc)
    |> Ash.Query.limit(1)
    |> Ash.read_one!(authorize?: false)
  end

  @tag :async_false
  test "N concurrent transfers between two real accounts settle to the exact expected real balance, no lost updates" do
    source = open_account!("concurrency-source-#{System.unique_integer([:positive])}")
    dest = open_account!("concurrency-dest-#{System.unique_integer([:positive])}")

    # Fund the source account first so every concurrent debit is individually valid.
    funding = open_account!("concurrency-funding-#{System.unique_integer([:positive])}")
    transfer!(funding, source, 100_000)

    concurrency = 25
    per_transfer = 100

    results =
      1..concurrency
      |> Task.async_stream(
        fn _ -> transfer!(source, dest, per_transfer) end,
        max_concurrency: concurrency,
        timeout: 30_000
      )
      |> Enum.to_list()

    assert Enum.all?(results, &match?({:ok, %Transfer{}}, &1))

    expected_dest = Money.new!(concurrency * per_transfer, :USD)
    expected_source = Money.new!(100_000 - concurrency * per_transfer, :USD)

    dest_balance = latest_balance!(dest)
    source_balance = latest_balance!(source)

    assert Money.equal?(dest_balance.balance, expected_dest)
    assert Money.equal?(source_balance.balance, expected_source)
  end
end
