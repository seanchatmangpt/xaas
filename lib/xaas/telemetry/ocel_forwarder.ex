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
  conformance checking -- ex4pm_engine's `Ex4pm.Domain.Projector` (invoked
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

  defp do_forward(url, event) do
    envelope = %{
      "schema" => "xaas.ocel.v2",
      "producer" => %{"agent_id" => "xaas", "run_id" => run_id()},
      "sequence" => System.unique_integer([:positive, :monotonic]),
      "events" => [event]
    }

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
  rescue
    error ->
      Logger.warning(
        "Xaas.Telemetry.OcelForwarder: unexpected error forwarding OCEL event to #{url}: " <>
          inspect(error)
      )

      :ok
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
