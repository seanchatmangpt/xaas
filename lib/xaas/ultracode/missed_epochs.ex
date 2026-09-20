defmodule Xaas.Ultracode.MissedEpochs do
  @moduledoc """
  Real missed-epoch state transition.

  `ExpectedEpoch => not CompletedEpoch => (past run.epoch_timeout_seconds)`
  is enforced here as a real `Epoch.state` transition to `:missed`, not a
  silent forward-advance of `Run.last_expected_epoch_at`. An `Epoch` row
  already in `:expected` or `:running` whose `expected_at` is older than
  its `Run`'s `epoch_timeout_seconds` is transitioned to `:missed` via the
  real `Xaas.Ultracode.Epoch.:mark_missed` update action -- this produces
  a visible, queryable `Epoch` row in `:missed` state. `Run.
  last_expected_epoch_at` is never written by this module: it is left
  exactly as it was, so a caller reading it alongside a `:missed` epoch
  sees real drift (expectation set, not met) instead of a
  quietly-rolled-forward timestamp that would hide the miss.

  Closes the ULTRACODE-50 receipt-coverage gap: `ConsequentialEffect =>
  Receipt` previously held for `EpochReactor`'s two transitions
  (`:expected -> :running`, `:running -> :completed`) but not for this
  module's `:missed` transition, measuring `ReceiptCoverage = 2/3` for a
  single-epoch run. Every `:mark_missed` transition now also seals a real
  `Xaas.Ultracode.Receipt` (`outcome: :blocked`, matching this repo's own
  `ALIVE/PARTIAL_ALIVE/BLOCKED/...` vocabulary -- a missed expectation is
  exactly what `:blocked` means, not a distinct new outcome atom), via the
  same `Receipt.:seal` action `EpochReactor`'s `:receipt` step uses.
  ## Live leases are exempt (the worker's TTL is its liveness bound)

  A `:running` Epoch whose lease is still LIVE (`lease_expires_at >= now`,
  `Xaas.Ultracode.Lease`) is deliberately NOT marked `:missed`, no matter
  how stale its `expected_at`: the lease TTL is the worker's real liveness
  reservation, and terminalizing a live-leased epoch mid-work strands real
  work (a worker that finishes after this reaping finds
  `{:error, {:lease_not_live, :missed}}` on close, and the epoch can never
  reach `:completed`). This is not hypothetical: the Run moduledoc records
  a real failover trial where a provider worker's claim->edit->close round
  trip outran the then-300s timeout and the epoch was marked `:missed`
  MID-LEASE. The miss deadline for a live-leased epoch is therefore its
  own `lease_expires_at` (default TTL 30 minutes); once the lease has
  expired -- a crashed or stuck worker -- the ordinary
  `expected_at + epoch_timeout_seconds` rule reaps it exactly as before,
  receipt sealed. `:expected` epochs (never claimed) keep the original
  deadline unchanged.
  """

  require Ash.Query
  require Logger

  @doc """
  Scans every `:running` `Run` and transitions any of its stale
  `:expected`/`:running` `Epoch`s to `:missed`. Returns a real per-run
  summary (not a boolean) so the calling Reactor step has evidence to
  return, not just a side effect.
  """
  @spec advance_all() :: [%{run_id: Ash.UUID.t(), missed: [Ash.UUID.t()]}]
  def advance_all do
    {:ok, active_runs} =
      Xaas.Ultracode.Run
      |> Ash.Query.for_read(:read_unscoped)
      |> Ash.Query.filter(state == :running)
      |> Ash.read()

    advance_all(active_runs)
  end

  # ERRC reduce: `Xaas.Ultracode.Reactor`'s tick already fetches every
  # `:running` Run once per tick for its own step; this lets that same
  # list be passed in here instead of this module re-scanning the Run
  # table independently. `advance_all/0` above stays as a real, still-
  # querying standalone entry point -- kept deliberately (not removed or
  # renamed) because `test/xaas/ultracode/missed_epoch_receipt_test.exs`
  # and `test/xaas/ultracode/epoch_reactor_test.exs` call it directly
  # with no arguments to exercise this module in isolation from the
  # Reactor.
  @spec advance_all([Xaas.Ultracode.Run.t()]) :: [
          %{run_id: Ash.UUID.t(), missed: [Ash.UUID.t()]}
        ]
  def advance_all(active_runs) when is_list(active_runs) do
    Enum.map(active_runs, &advance_run/1)
  end

  @doc """
  Transitions one `Run`'s stale epochs to `:missed`. Real per-epoch
  `Ash.update!/1` calls against the real `:mark_missed` action -- no
  in-memory-only bookkeeping.
  """
  @spec advance_run(Xaas.Ultracode.Run.t()) :: %{run_id: Ash.UUID.t(), missed: [Ash.UUID.t()]}
  def advance_run(%Xaas.Ultracode.Run{} = run) do
    now = DateTime.utc_now()
    deadline = DateTime.add(now, -run.epoch_timeout_seconds, :second)

    {:ok, stale_epochs} =
      Xaas.Ultracode.Epoch
      |> Ash.Query.for_read(:read_unscoped)
      |> Ash.Query.filter(run_id == ^run.id)
      |> Ash.Query.filter(state in [:expected, :running])
      |> Ash.Query.filter(not is_nil(expected_at) and expected_at < ^deadline)
      # Live-lease exemption -- see the moduledoc section: a `:running`
      # epoch still inside its lease TTL belongs to a working (or at least
      # bounded) worker; only an expired/absent lease makes it reapable
      # here. Evaluated against the SAME `now` the deadline above used so
      # the two predicates cannot straddle a clock step.
      |> Ash.Query.filter(is_nil(lease_token) or lease_expires_at < ^now)
      |> Ash.read()

    missed_ids =
      Enum.map(stale_epochs, fn epoch ->
        system_actor = Xaas.SystemAuthority.new(:ultracode_reactor)

        missed_epoch =
          epoch
          |> Ash.Changeset.for_update(:mark_missed, %{})
          |> Ash.update!(actor: system_actor)

        {:ok, _receipt} =
          Xaas.Ultracode.Receipt
          |> Ash.Changeset.for_create(
            :seal,
            %{
              epoch_id: missed_epoch.id,
              subject: missed_epoch.exact_subject,
              outcome: :blocked,
              evidence: %{
                "expected_state" => "completed",
                "observed_state" => "missed",
                "expected_at" => to_string(epoch.expected_at),
                "epoch_timeout_seconds" => run.epoch_timeout_seconds
              },
              sealed_at: DateTime.utc_now()
            }
          )
          |> Ash.create(actor: system_actor)

        Logger.warning(
          "[ultracode] epoch #{epoch.id} (run #{run.id}, cycle #{epoch.cycle}) " <>
            "expected_at=#{epoch.expected_at} exceeded epoch_timeout_seconds=" <>
            "#{run.epoch_timeout_seconds} -> marked :missed (receipt sealed)"
        )

        epoch.id
      end)

    %{run_id: run.id, missed: missed_ids}
  end
end
