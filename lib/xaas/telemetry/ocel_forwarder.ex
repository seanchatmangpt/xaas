defmodule Xaas.Telemetry.OcelForwarder do
  @moduledoc """
  Real OCEL v2 egress: forwards every OCEL event xaas already emits
  (via `Xaas.Telemetry.OcelAshEmitter`) to ex4pm_web's real network-facing
  ingest endpoint, `POST /api/v1/ocel/events` ->
  `Ex4pmWeb.OcelController.ingest/2` (confirmed by reading
  `/Users/sac/ex4pm/apps/ex4pm_web/lib/ex4pm_web/controllers/ocel_controller.ex`
  and its router at
  `/Users/sac/ex4pm/apps/ex4pm_web/lib/ex4pm_web/router.ex`), which calls
  `Ex4pm.Stream.Ingest.ingest_envelope/2` ->
  `Ex4pm.OCEL.validate_envelope/1`.

  This module does not reimplement OCEL validation, DFG discovery, or
  conformance checking -- it calls ex4pm_core's real
  `Ex4pm.OCEL.validate_envelope/1` directly (a real path dep, see mix.exs)
  on the envelope it builds, before POSTing, so a drift between this
  envelope shape and what ex4pm_web's real ingest endpoint requires is
  refused here rather than discovered later as a silent non-2xx response.
  ex4pm_engine's `Ex4pm.Domain.Projector` (invoked
  by the controller's broadcaster) and beam4pm's rf1/rf2 oracles are the
  real downstream consumers of forwarded events, once ex4pm_web has
  ingested them. xaas's only job here is to produce a correctly-shaped
  envelope and POST it.

  ## Real envelope shape required by `Ex4pm.OCEL.validate_envelope/1`

  Read field-for-field from
  `/Users/sac/ex4pm/apps/ex4pm_core/lib/ex4pm/ocel.ex` (`validate_envelope/1`,
  around line 366) -- NOT xaas's bare `ocel:eid`/`ocel:activity`/`ocel:omap`/
  `ocel:vmap` shape verbatim. The envelope (top-level map POSTed as JSON) must
  have:

    * `"schema"` -- any non-nil value (stringified)
    * `"producer"` -- a map (validate_envelope requires `is_map/1`); ex4pm's
      `Ingest.ingest_envelope/2` additionally reads `"agent_id"`/`"run_id"`
      out of it (falling back to `"unknown"` if absent)
    * `"sequence"` -- a non-negative integer
    * `"events"` -- a list or map of OCEL event records

  Each event record (validated later by `Ex4pm.OCEL.normalize_event/2`)
  accepts either the plain OCEL-2.0-JSON keys (`"id"`, `"activity"`,
  `"timestamp"`) or the prefixed JSON-OCEL keys xaas already produces
  (`"ocel:eid"`, `"ocel:activity"`, `"ocel:timestamp"`) -- both are read via
  `value/2`'s key-alias list, so xaas's existing per-event shape is forwarded
  unchanged inside the `"events"` list.

  `"objects"` and `"object_relationships"` are optional in the envelope
  (`validate_envelope/1` defaults them to `%{}` and `[]}` respectively) --
  xaas does not currently track OCEL objects/relationships beyond the single
  `ocel:omap` id already embedded per-event, so they are omitted here.

  Forwarding failure (ex4pm_web unreachable, non-2xx response, timeout) is
  always non-fatal and logged via `Logger.warning/1`, mirroring
  `OcelAshEmitter.append_ocel_event!/1`'s `rescue` pattern -- an unreachable
  ex4pm_web must never crash or block the Ash action that produced the
  event.
  """

  require Logger

  @doc """
  Forward one already-built xaas OCEL event map (the same shape
  `Xaas.Telemetry.OcelAshEmitter.build_ocel_event/3` produces, i.e. with
  `"ocel:eid"`/`"ocel:activity"`/`"ocel:timestamp"`/`"ocel:omap"`/
  `"ocel:vmap"` keys) to ex4pm_web's real ingest endpoint, wrapped in the
  batch envelope shape `Ex4pm.OCEL.validate_envelope/1` requires.

  Returns `:ok` unconditionally -- forwarding is best-effort and must never
  raise into the caller (a `:telemetry` handler running inline in the Ash
  action's own process).
  """
  def forward(event) when is_map(event) do
    case ingest_url() do
      nil ->
        :ok

      url ->
        do_forward(url, event)
    end
  end

  @doc """
  Forward a real OCEL v2 correction/cancellation event for an action whose
  original event was already forwarded by `forward/1` (fired synchronously
  off `Xaas.Telemetry.OcelAshEmitter`'s `:stop` telemetry handler, mid-`:do`,
  before `Xaas.Actuation.Reactor`'s `:receipt` step seals) but whose real
  database effect was then rolled back by a later reactor failure.

  Ash's own data-layer transaction already undoes the DB mutation; this
  function is the compensating action for the one side effect that
  transaction cannot touch -- the OCEL event that already left this process
  over HTTP. It is called from `Xaas.Actuation.Kernel.undo_actuate/3`, the
  real `undo/4` callback (see `lib/xaas/actuation.ex`) on the reactor's
  `:do` ash_step.

  Builds a distinct event (same envelope-validation + POST path as
  `forward/1`) with `"outcome" => "cancelled"` and an `"ocel:activity"`
  suffixed `.cancelled`, keyed by the same `idempotency_key` threaded
  through `Xaas.Actuation.run/4`, so ex4pm_web and its downstream
  projector/oracles can tell the original event's effect did not survive.

  Returns `:ok` unconditionally, same as `forward/1` -- this runs inside
  Reactor's undo path and must never raise or halt rollback.
  """
  def forward_cancellation(%{resource: resource, action: action, idempotency_key: idempotency_key}) do
    short_name =
      if Ash.Resource.Info.resource?(resource) do
        Ash.Resource.Info.short_name(resource)
      else
        resource
      end

    event = %{
      "ocel:eid" => Ash.UUIDv7.generate(),
      "ocel:activity" => "#{short_name}.#{action}.cancelled",
      "ocel:timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "ocel:omap" => [to_string(short_name)],
      "ocel:vmap" => %{
        "resource" => inspect(resource),
        "action" => to_string(action),
        "outcome" => "cancelled",
        "idempotency_key" => idempotency_key,
        "reason" => "downstream_reactor_step_failed_after_action_execution"
      }
    }

    forward(event)
  end

  defp do_forward(url, event) do
    envelope =
      Xaas.Telemetry.OcelEnvelope.build(
        event,
        %{"agent_id" => "xaas", "run_id" => run_id()},
        System.unique_integer([:positive, :monotonic])
      )

    # Real validation, not just hand-documentation: call ex4pm_core's actual
    # Ex4pm.OCEL.validate_envelope/1 (path dep, see mix.exs) before POSTing,
    # so a drift between this envelope shape and what ex4pm_web's real
    # ingest endpoint requires is caught here instead of discovered as a
    # silent non-2xx response.
    case Ex4pm.OCEL.validate_envelope(envelope) do
      {:ok, _validated} ->
        post_envelope(url, envelope)

      {:error, reason} ->
        Logger.warning(
          "Xaas.Telemetry.OcelForwarder: refusing to forward OCEL event to #{url}, " <>
            "envelope failed Ex4pm.OCEL.validate_envelope/1: #{inspect(reason)}"
        )

        {:error, reason}
    end
  rescue
    error ->
      Logger.warning(
        "Xaas.Telemetry.OcelForwarder: unexpected error forwarding OCEL event to #{url}: " <>
          inspect(error)
      )

      :ok
  end

  defp post_envelope(url, envelope) do
    case Req.post(url, json: envelope, receive_timeout: receive_timeout_ms()) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        :ok

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.warning(
          "Xaas.Telemetry.OcelForwarder: ex4pm_web ingest at #{url} returned " <>
            "non-2xx status #{status}: #{inspect(body)}"
        )

        :ok

      {:error, reason} ->
        Logger.warning(
          "Xaas.Telemetry.OcelForwarder: failed to forward OCEL event to #{url}: " <>
            inspect(reason)
        )

        :ok
    end
  end

  # Real, distinct-per-boot run id -- ex4pm's Ingest only uses this for
  # receipt/idempotency bookkeeping on its side, never validated by shape.
  defp run_id do
    :persistent_term.get({__MODULE__, :run_id}, nil) ||
      begin_run_id()
  end

  defp begin_run_id do
    id = Ash.UUIDv7.generate()
    :persistent_term.put({__MODULE__, :run_id}, id)
    id
  end

  defp ingest_url do
    Application.get_env(:xaas, :ex4pm_ocel_ingest_url)
  end

  defp receive_timeout_ms do
    Application.get_env(:xaas, :ex4pm_ocel_ingest_timeout_ms, 2_000)
  end
end
