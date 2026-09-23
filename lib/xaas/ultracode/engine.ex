defmodule Xaas.Ultracode.Engine do
  @moduledoc """
  The continuous engine around the wave: turns Time -> worker slots, on a
  cadence, forever.

  `Xaas.Ultracode.Autonomic` is a BATCH wave: sense a backlog once, work it
  at capacity, promote, seal one receipt, exit. Between waves, the tick
  (`Xaas.Ultracode.Reactor`) advances epoch LIFECYCLE state but drives no
  workers. This module is the missing continuous piece: every cycle it

    1. REAPS stuck work (`Xaas.Ultracode.MissedEpochs`) -- stale epochs go
       `:missed` with a receipt; live-leased epochs are exempt (a live
       lease is a worker's TTL-bounded reservation, see that module);
    2. FILLS free worker slots -- for every provider with ready work, up
       to the provider's pool capacity (`Xaas.Ultracode.Lease.pool_capacity/1`,
       5 in production config), it hands the oldest ready epochs to
       workers and SETTLES each slot afterwards;
    3. ADVANCES (`Xaas.Ultracode.NextEpoch`) -- completed epochs become
       their successor (or the Run completes/fails at `max_cycles`, with
       bounded recovery after `:missed`/`:failed` epochs);
    4. REPORTS health -- `Xaas.Ultracode.TickHealth.check/1`'s real
       liveness verdict on the tick cron is part of every cycle report
       (observation: the health of the SCHEDULER is a fact the report
       carries, not one the engine acts on).

  ## The worker seam (dispatch is out of this module's scope)

  A worker is the SAME 2-arity contract the wave already defines:
  `(epoch, ctx) -> :ok | :rate_limited | {:error, reason}`. It drives the
  lease protocol itself (directed `Lease.claim_next/3` on the handed
  epoch, work, `Lease.close/4` / `Lease.refuse/3`); the engine never
  claims on a worker's behalf and never inspects what the worker did --
  SETTLE reads the sealed epoch state back from the database, the same
  evidentiary boundary the wave's `settle/2` uses.

  The default is nil: with no worker configured the engine still reaps,
  advances, and reports, and each provider's fill reports
  `:no_worker_configured` instead of dispatching. Configure the real
  dispatcher via `config :xaas, :ultracode_engine_worker, {Mod, :fun}` (or
  pass `:worker` per call) -- the dispatch seam itself is a separate
  concern; tests supply scripted protocol clients (real `Lease` calls,
  no mocks), exactly like `Xaas.Ultracode.AutonomicTest` does.

  ## The provider allowlist (which pools the engine may fill by itself)

  Undirected fills (no `:providers`/`:provider` opt -- the AshOban cron
  path) only discover ready work for providers in
  `config :xaas, :ultracode_engine_providers` (default `["recipe"]`;
  `:all` restores unrestricted discovery). The CONFIGURED worker likewise
  serves only allowlisted providers: a directed fill of a provider outside
  the allowlist with no explicit `:worker` reports
  `:provider_not_allowlisted` and dispatches nothing. This is what keeps
  the deterministic `Xaas.Ultracode.RecipeWorker` (wired for "recipe") from
  ever being handed a zcode epoch it would decline -- and the engine from
  then reaping that declined epoch as a refusal. An explicit `:worker` opt
  is the caller's own choice and applies to whatever providers it names.

  ## Settling is concurrency-correct

  A slot's worker may lose its directed claim to a concurrent engine or an
  MCP worker; a worker may return without closing; a lease may expire
  mid-turn. Settlement is decided from the EPOCH's real state, not the
  worker's return value:

    * `:completed` / `:failed` / `:missed` -- terminal, receipt id reported;
    * still `:running` with a LIVE lease -- `:handed_off`: someone else
      owns the slot now; reaping it would be clobbering;
    * still `:running`, no/expired lease, `:rate_limited` -- left
      reclaimable (an unleased `:running` epoch is exactly what
      `claim_next/3` selects; the next cycle re-dispatches it);
    * still `:running`, no/expired lease, anything else -- REAPED:
      `:mark_failed` + a `:refused` receipt (a worker that ends without
      closing is a real refusal, never a silent drop -- this also closes
      the receipt gap the wave's own no-token reap has).
  """

  require Ash.Query
  require Logger

  import Ecto.Query, only: [from: 2]

  alias Xaas.Ultracode.{Epoch, Lease, MissedEpochs, NextEpoch, Receipt, Run, TickHealth}

  # Sanity bound for a single fill when pool capacity is unbounded (nil) --
  # production always runs bounded (5), so this only exists so a
  # misconfigured-nil-capacity engine cannot spawn an unbounded task storm.
  @unbounded_fill_batch 16

  # Providers the engine fills on its own by default: the deterministic
  # recipe provider only (see `provider_allowlist/0`).
  @default_providers ["recipe"]

  @doc """
  One full engine turn: reap -> fill -> advance -> health. Real Ash/Reactor
  side effects throughout; returns the cycle report (also the body the
  AshOban `:engine_cycle` scheduled action runs, every 5 minutes).
  """
  @spec cycle(keyword()) :: map()
  def cycle(opts \\ []) do
    started_at = DateTime.utc_now()

    reaped = MissedEpochs.advance_all()
    filled = fill(opts)
    advanced = NextEpoch.advance_all()
    health = TickHealth.check()

    %{
      started_at: started_at,
      finished_at: DateTime.utc_now(),
      reaped: reaped,
      fill: filled,
      advanced: advanced,
      tick_health: health.status,
      tick_last_activity_at: health.last_tick_at
    }
  end

  @doc """
  Fill free worker slots for `opts[:providers]` (default: every provider
  with ready work), bounded by each provider's pool capacity. Slots are
  dispatched concurrently (one task per free slot) and settled
  individually -- see the moduledoc for the settlement semantics.
  """
  @spec fill(keyword()) :: [map()]
  def fill(opts \\ []) do
    opts
    |> providers()
    |> Enum.map(&fill_provider(&1, opts))
  end

  # Directed (`:providers` list or a single `:provider`) wins; otherwise the
  # allowlisted providers that have ready work.
  defp providers(opts) do
    cond do
      Keyword.has_key?(opts, :providers) -> Keyword.fetch!(opts, :providers)
      is_binary(opts[:provider]) -> [opts[:provider]]
      true -> ready_providers()
    end
  end

  @doc """
  The providers whose pools the engine fills on its own and whose epochs the
  CONFIGURED worker may be handed: `config :xaas, :ultracode_engine_providers`
  (a list of provider ids, or `:all`). Unset = `["recipe"]` (the deterministic
  recipe provider only). A malformed value fails closed to `[]`.
  """
  @spec provider_allowlist() :: [String.t()] | :all
  def provider_allowlist do
    case Application.get_env(:xaas, :ultracode_engine_providers, @default_providers) do
      :all ->
        :all

      list when is_list(list) ->
        if Enum.all?(list, &is_binary/1), do: list, else: []

      _malformed ->
        []
    end
  end

  defp allowlisted?(provider) do
    case provider_allowlist() do
      :all -> true
      list -> provider in list
    end
  end

  defp fill_provider(provider, opts) do
    capacity = Keyword.get(opts, :pool_capacity, Lease.pool_capacity(provider))
    in_flight_before = Lease.live_leases(provider)

    case resolve_worker(opts, provider) do
      {:skip, outcome} ->
        %{
          provider: provider,
          capacity: capacity,
          in_flight_before: in_flight_before,
          dispatched: [],
          outcome: outcome
        }

      worker ->
        free = free_slots(capacity, in_flight_before)
        candidates = ready_epochs(provider, free)

        dispatched =
          candidates
          |> Task.async_stream(
            &dispatch_slot(&1, provider, worker),
            max_concurrency: max(length(candidates), 1),
            timeout: :infinity,
            ordered: true
          )
          |> Enum.zip(candidates)
          |> Enum.map(fn
            {{:ok, result}, _candidate} ->
              result

            {{:exit, reason}, candidate} ->
              %{epoch_id: candidate.id, status: :crashed, reason: inspect(reason)}
          end)

        %{
          provider: provider,
          capacity: capacity,
          in_flight_before: in_flight_before,
          free_slots: free,
          dispatched: dispatched
        }
    end
  end

  defp free_slots(nil, _in_flight_before), do: @unbounded_fill_batch
  defp free_slots(capacity, in_flight_before), do: max(capacity - in_flight_before, 0)

  defp dispatch_slot(epoch, provider, worker) do
    result = worker.(epoch, %{provider: provider})
    settle(epoch, result)
  rescue
    error ->
      Logger.error("[ultracode-engine] slot worker crashed: #{Exception.message(error)}")
      %{epoch_id: epoch.id, status: :worker_crashed, reason: Exception.message(error)}
  end

  # Decision from the DATABASE, not the worker's return value -- see the
  # moduledoc's "Settling is concurrency-correct".
  defp settle(%Epoch{id: id} = pre_worker_epoch, worker_result) do
    fresh = Ash.get!(Epoch, id, action: :read_unscoped)

    case {fresh.state, worker_result} do
      {:completed, _} ->
        %{
          epoch_id: id,
          status: :done,
          receipt_id: closing_receipt_id(id),
          final_head: fresh.final_head
        }

      {:failed, _} ->
        %{epoch_id: id, status: :refused, receipt_id: latest_receipt_id(id)}

      {:missed, _} ->
        %{epoch_id: id, status: :missed, receipt_id: latest_receipt_id(id)}

      {:running, :rate_limited} ->
        # Not reaped: an unleased `:running` epoch is exactly the candidate
        # set claim_next/3 selects from -- the next cycle re-dispatches it.
        %{epoch_id: id, status: :rate_limited}

      {:running, _} ->
        cond do
          lease_live?(fresh) ->
            # A concurrent claimer won this epoch -- the lease is theirs and
            # live; reaping here would clobber real in-flight work.
            %{epoch_id: id, status: :handed_off}

          true ->
            reap(fresh, pre_worker_epoch)
        end
    end
  end

  # A worker that ENDED without closing and holds no live lease is a real
  # refusal: `:mark_failed` plus a sealed `:refused` receipt naming the
  # reap. (Same semantics as the wave's lease-holding reap via
  # `Lease.refuse/3`; this is the no-live-lease variant, which
  # `Autonomic.reap/2`'s else-branch marks failed but used to leave
  # receipt-less.) Carries the XAAS-2601 system authority actor -- the
  # same admitted `:ultracode_reactor` service the rest of the tick-driven
  # pipeline (EpochReactor, NextEpoch, MissedEpochs, Lease closure) acts
  # under.
  defp reap(fresh, pre_worker_epoch) do
    changeset = Ash.Changeset.for_update(fresh, :mark_failed, %{})

    case Ash.update(changeset, actor: Xaas.SystemAuthority.new(:ultracode_reactor)) do
      {:ok, failed} ->
        {:ok, receipt} =
          seal_receipt(failed, :refused, %{
            "reaped_by" => "xaas-engine",
            "reap_reason" => "worker_ended_without_closing",
            "worker_had_lease" => not is_nil(pre_worker_epoch.lease_token)
          })

        Logger.warning(
          "[ultracode-engine] reaped epoch #{fresh.id} (worker ended without closing)"
        )

        %{epoch_id: fresh.id, status: :reaped, receipt_id: receipt.id}

      {:error, _error} ->
        # The row moved concurrently (closed/refused/missed by someone else
        # between the read and this write). Report what is really there.
        observed = Ash.get!(Epoch, fresh.id, action: :read_unscoped).state
        %{epoch_id: fresh.id, status: :settle_race, observed_state: observed}
    end
  end

  defp lease_live?(%Epoch{} = epoch) do
    not is_nil(epoch.lease_token) and not is_nil(epoch.lease_expires_at) and
      DateTime.compare(epoch.lease_expires_at, DateTime.utc_now()) != :lt
  end

  defp receipts_for(epoch_id) do
    Receipt
    |> Ash.Query.for_read(:for_epoch, %{epoch_id: epoch_id})
    |> Ash.read()
  end

  defp closing_receipt_id(epoch_id) do
    case receipts_for(epoch_id) do
      {:ok, receipts} ->
        case Enum.find(receipts, &Map.has_key?(&1.evidence, "head_verified")) do
          %Receipt{id: id} -> id
          nil -> latest_receipt_id(epoch_id)
        end

      {:error, _} ->
        nil
    end
  end

  defp latest_receipt_id(epoch_id) do
    case receipts_for(epoch_id) do
      {:ok, [%Receipt{id: id} | _]} -> id
      _ -> nil
    end
  end

  defp seal_receipt(epoch, outcome, evidence) do
    Receipt
    |> Ash.Changeset.for_create(
      :seal,
      %{
        epoch_id: epoch.id,
        subject: epoch.exact_subject,
        outcome: outcome,
        evidence: evidence,
        sealed_at: DateTime.utc_now()
      }
    )
    |> Ash.create(actor: Xaas.SystemAuthority.new(:ultracode_reactor))
  end

  # The worker seam: `:worker` opt wins (for any provider it is aimed at),
  # then `config :xaas, :ultracode_engine_worker` ({Mod, :fun} or a 2-arity
  # fun) -- but ONLY for allowlisted providers -- then nothing (observe-only
  # engine: reap/advance/health still run, no dispatch).
  defp resolve_worker(opts, provider) do
    case Keyword.get(opts, :worker) do
      nil ->
        if allowlisted?(provider) do
          to_worker(Application.get_env(:xaas, :ultracode_engine_worker)) ||
            {:skip, :no_worker_configured}
        else
          {:skip, :provider_not_allowlisted}
        end

      explicit ->
        to_worker(explicit) || {:skip, :no_worker_configured}
    end
  end

  defp to_worker({mod, fun}) when is_atom(mod) and is_atom(fun),
    do: fn epoch, ctx -> apply(mod, fun, [epoch, ctx]) end

  defp to_worker(fun) when is_function(fun, 2), do: fun
  defp to_worker(_other), do: nil

  defp ready_providers do
    now = DateTime.utc_now()

    query =
      from(e in Epoch,
        join: r in Run,
        on: e.run_id == r.id,
        where:
          e.state == :running and (is_nil(e.lease_token) or e.lease_expires_at < ^now) and
            not is_nil(r.provider),
        distinct: true,
        select: r.provider
      )

    case provider_allowlist() do
      :all -> Xaas.Repo.all(query)
      [] -> []
      allowed -> query |> where_provider_in(allowed) |> Xaas.Repo.all()
    end
  end

  defp where_provider_in(query, allowed),
    do: from([_e, r] in query, where: r.provider in ^allowed)

  defp ready_epochs(_provider, limit) when limit <= 0, do: []

  defp ready_epochs(provider, limit) do
    now = DateTime.utc_now()

    Epoch
    |> Ash.Query.for_read(:read_unscoped)
    |> Ash.Query.filter(state == :running)
    |> Ash.Query.filter(is_nil(lease_token) or lease_expires_at < ^now)
    |> Ash.Query.filter(run.provider == ^provider)
    |> Ash.Query.sort(inserted_at: :asc)
    |> Ash.Query.limit(limit)
    |> Ash.read!()
  end
end
