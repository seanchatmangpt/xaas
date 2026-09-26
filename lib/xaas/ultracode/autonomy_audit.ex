defmodule Xaas.Ultracode.AutonomyAudit do
  @moduledoc """
  The autonomy audit law over a time window: UAR = 0 and DCR = 0.

    * **UAR (unreceipted actuations)** -- epochs that reached a TERMINAL
      state in the window without a single sealed STANDING receipt. A
      terminal epoch IS an actuation on the subject (the lease closed,
      failed, was missed, or was cancelled); a terminal epoch with only
      `:heartbeat` lifecycle records (or none) acted without a receipt --
      the exact `mu_on_O`/`R_missing_consequence` class this audit exists
      to keep at zero. Cancelled epochs are exempt from NOTHING here: a
      cancellation seals its own `:blocked` receipt by construction
      (`Lease.cancel/3` / `Lease.cancel_epoch/4`), so an unreceipted
      "cancel" is precisely a bug this counts.
    * **DCR (duplicate consequences)** -- epochs with MORE THAN ONE sealed
      standing receipt: the consequence was recorded twice (the
      double-close/retry-race class; the concurrency kernel's own tests
      assert <= 1 per epoch, this audit is the standing-window tripwire
      over live rows, not a test-only claim).

  The audit is DERIVED from persisted rows (the same discipline as
  `Xaas.Ultracode.OcelEgress`: the lease writes bypass notifiers, so only a
  derivation can be trusted), read-only, and returns a typed report:

      {:ok, %{since: dt, epochs_audited: n, uar: [epoch_ids], dcr: [epoch_ids],
              standing: :alive | {:partial_alive, [...]}}}

  A window with no terminal epochs is vacuously clean (`:alive`, 0 audited)
  -- the caller decides whether an empty window is meaningful; this module
  does not paper over it with a special standing.
  """

  require Ash.Query

  alias Xaas.Ultracode.{Epoch, Receipt}

  @default_window_minutes 1440

  @doc "The default audit window, in minutes (#{@default_window_minutes} = 24h)."
  def default_window_minutes, do: @default_window_minutes

  @doc """
  Audits terminal epochs whose terminal moment (`terminal_at`, falling back
  to `completed_at`) falls in `[since, now]`. Options: `:since` (DateTime,
  default now - #{@default_window_minutes} minutes).
  """
  @spec audit(keyword()) :: {:ok, map()} | {:error, term()}
  def audit(opts \\ []) do
    now = DateTime.utc_now()
    since = Keyword.get(opts, :since) || DateTime.add(now, -@default_window_minutes * 60, :second)

    with {:ok, epochs} <- terminal_epochs(since) do
      epoch_ids = Enum.map(epochs, & &1.id)
      receipts_by_epoch = standing_receipts_by_epoch(epoch_ids)

      uar =
        epochs
        |> Enum.reject(&Map.has_key?(receipts_by_epoch, &1.id))
        |> Enum.map(& &1.id)

      dcr =
        receipts_by_epoch
        |> Enum.filter(fn {_epoch_id, receipts} -> length(receipts) > 1 end)
        |> Enum.map(&elem(&1, 0))
        |> Enum.sort()

      standing =
        case {uar, dcr} do
          {[], []} ->
            :alive

          {uar, dcr} ->
            {:partial_alive,
             [
               "UAR=#{length(uar)} unreceipted actuation(s)",
               "DCR=#{length(dcr)} duplicate-consequence epoch(s)"
             ]}
        end

      {:ok,
       %{
         since: since,
         until: now,
         epochs_audited: length(epochs),
         uar: Enum.sort(uar),
         dcr: dcr,
         standing: standing
       }}
    end
  end

  defp terminal_epochs(since) do
    Epoch
    |> Ash.Query.for_read(:read_unscoped)
    |> Ash.Query.filter(state in [:completed, :missed, :failed])
    |> Ash.Query.filter(
      (not is_nil(terminal_at) and terminal_at >= ^since) or
        (not is_nil(completed_at) and completed_at >= ^since)
    )
    |> Ash.read()
  end

  # One query for the window's standing receipts, grouped by epoch.
  defp standing_receipts_by_epoch([]), do: %{}

  defp standing_receipts_by_epoch(epoch_ids) do
    Receipt
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(epoch_id in ^epoch_ids and outcome != :heartbeat)
    |> Ash.read!(authorize?: false)
    |> Enum.group_by(& &1.epoch_id)
  end
end
