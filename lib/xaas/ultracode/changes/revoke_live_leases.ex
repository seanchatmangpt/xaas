defmodule Xaas.Ultracode.Changes.RevokeLiveLeases do
  @moduledoc """
  The STOP side effect: when `Run.:stop` lands (`:running -> :abandoned`),
  every LIVE lease this Run's epochs hold is refused through the real
  admitted path (`Xaas.Ultracode.Lease.refuse/3`, reason `:run_stopped`) --
  so each revoked worker's epoch lands `:failed` with its own `:refused`
  receipt, keeping the subsystem's `terminal epoch => receipt` invariant
  intact across a stop.

  `:expected` (never-claimed) epochs carry no lease and are deliberately
  untouched -- see `Run.:stop`'s own doc for why freezing them is the
  lawful disposition.

  A refused-revocation failure (a lease expiring between the read and the
  refuse, a concurrent close winning first) is logged and skipped, never
  raised: the losing race means the epoch settled itself lawfully, and the
  refuse receipt trail shows exactly which leases the stop actually
  revoked.
  """

  use Ash.Resource.Change

  require Ash.Query
  require Logger

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, run ->
      {:ok, leased_epochs} =
        Xaas.Ultracode.Epoch
        |> Ash.Query.for_read(:read_unscoped)
        |> Ash.Query.filter(run_id == ^run.id and state == :running)
        |> Ash.Query.filter(not is_nil(lease_token))
        |> Ash.read()

      now = DateTime.utc_now()

      revoked =
        Enum.count(leased_epochs, fn epoch ->
          live? = DateTime.compare(epoch.lease_expires_at, now) != :lt

          cond do
            not live? ->
              false

            match?({:ok, _, _}, Xaas.Ultracode.Lease.refuse(epoch.lease_token, :run_stopped)) ->
              true

            true ->
              Logger.warning(
                "[ultracode] stop of run #{run.id}: lease on epoch #{epoch.id} " <>
                  "settled concurrently -- revocation skipped (its own receipt is sealed)"
              )

              false
          end
        end)

      if revoked > 0 do
        Logger.warning(
          "[ultracode] run #{run.id} stopped: refused #{revoked} live lease(s) " <>
            "(reason :run_stopped)"
        )
      end

      {:ok, run}
    end)
  end
end
