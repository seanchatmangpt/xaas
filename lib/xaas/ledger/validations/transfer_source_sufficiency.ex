defmodule Xaas.Ledger.Validations.TransferSourceSufficiency do
  @moduledoc """
  W762 transfer-sufficiency invariant (W738 finding `UNSUPPORTED(invariant-absent)`).

  Before a `Xaas.Ledger.Transfer` `:transfer` create commits, refuse when the
  source account's balance is insufficient. `AshDoubleEntry`'s
  `VerifyTransfer` computes balances with `Money.sub!`/`Money.add!` and
  performs no sufficiency check, so without this validation an over-balance
  transfer is admitted and drives the source balance negative.

  Uses a real read of the from-account's `balance_as_of` calculation (defaults
  to now) — the same balance source `VerifyTransfer` itself debits.

  ## Exemptions (W785)

  1. `changeset.context[:ash_double_entry][:skip_balance_updates]` —
     ash_double_entry's documented manual-entry/minting path (VerifyTransfer
     itself short-circuits on it).
  2. `changeset.context[:xaas_ledger][:allow_overdraft] == true` — explicit
     per-call-site opt for intentional receivable transfers (billing charges
     a real over-draw from the org's unfunded account; the negative org
     balance IS the receivable). The default remains refuse; every exempt
     site sets this context itself with a comment citing
     `docs/sjira/v26.10.6/plans/w785-overdraft-policy.md`. There is no
     ambient allow-all: a caller that does not set the context is refused.
  """

  use Ash.Resource.Validation
  require Ash.Query

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    # `skip_balance_updates` is ash_double_entry's documented manual-entry
    # path (VerifyTransfer itself short-circuits on it); it is the lawful
    # minting/adjustment channel and is not an ordinary transfer.
    if changeset.context[:ash_double_entry][:skip_balance_updates] do
      :ok
    else
      # W785: explicit per-caller overdraft opt-in (intentional receivable
      # transfers). Default remains refuse; see
      # docs/sjira/v26.10.6/plans/w785-overdraft-policy.md. NOTE: the
      # caller must pass this through the `for_create/4` `context:` opt —
      # `Ash.Changeset.set_context/2` applied after `for_create/4` does NOT
      # survive to the validation (observed live this session).
      if get_in(changeset.context, [:xaas_ledger, :allow_overdraft]) == true do
        :ok
      else
        check_sufficiency(changeset)
      end
    end
  end

  defp check_sufficiency(changeset) do
    amount = Ash.Changeset.get_attribute(changeset, :amount)
    from_id = Ash.Changeset.get_attribute(changeset, :from_account_id)
    to_id = Ash.Changeset.get_attribute(changeset, :to_account_id)

    cond do
      is_nil(amount) or is_nil(from_id) or is_nil(to_id) ->
        # Other validations / not-null constraints own these.
        :ok

      from_id == to_id ->
        # The built-in self-transfer check owns this refusal.
        :ok

      true ->
        account =
          Xaas.Ledger.Account
          |> Ash.Query.filter(id == ^from_id)
          |> Ash.Query.load(:balance_as_of)
          |> Ash.read_one!(authorize?: false)

        balance = account.balance_as_of || Money.new!(0, account.currency)

        if Money.compare(balance, amount) == :lt do
          {:error,
           field: :amount,
           message:
             "insufficient funds: source balance #{Money.to_string!(balance)} is less than transfer amount #{Money.to_string!(amount)}"}
        else
          :ok
        end
    end
  end
end
