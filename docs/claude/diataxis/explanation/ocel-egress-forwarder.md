# OCEL v2 egress: forwarding to ex4pm/beam4pm

## What this is

`Xaas.Telemetry.OcelForwarder` (`lib/xaas/telemetry/ocel_forwarder.ex`) is the
real, network-facing OCEL v2 egress path from xaas to the beam4pm/ex4pm
process-mining stack. It is called as a second sink from
`Xaas.Telemetry.OcelAshEmitter.handle_event/4`
(`lib/xaas/telemetry/ocel_ash_emitter.ex`) — alongside the existing durable
NDJSON append to `priv/ocel/ash-actions.ndjson` — so every real OCEL event
xaas already produces from a real Ash action's `:telemetry` `:stop` event is
also POSTed to `ex4pm_web`'s ingest endpoint.

## Why ex4pm_web and not beam4pm directly

Per the beam4pm-rf3-ocel and beam4pm-ash-domain findings (see
`beam4pm-ex4pm-dependency-decision.md`), beam4pm itself has no HTTP ingress
and no reusable OCEL codec API — it cannot be integrated with over the
network. `ex4pm_web` does expose one: a real controller action,
`Ex4pmWeb.OcelController.ingest/2`
(`/Users/sac/ex4pm/apps/ex4pm_web/lib/ex4pm_web/controllers/ocel_controller.ex`),
routed at `POST /api/v1/ocel/events`
(`/Users/sac/ex4pm/apps/ex4pm_web/lib/ex4pm_web/router.ex`). That action
calls `Ex4pm.Stream.Ingest.ingest_envelope/2`
(`/Users/sac/ex4pm/apps/ex4pm_stream/lib/ex4pm/stream/ingest.ex`), which
validates the envelope via `Ex4pm.OCEL.validate_envelope/1`
(`/Users/sac/ex4pm/apps/ex4pm_core/lib/ex4pm/ocel.ex`), normalizes it, feeds
it to `Ex4pm.Engine.OnlineMiner`, records an evidence receipt, and — via the
controller's own broadcaster callback — projects it through
`Ex4pm.Domain.Projector.project_log/1` and broadcasts it over
`Phoenix.PubSub` on topic `"process_intelligence:live"` for real-time
LiveView listeners (`Ex4pmWeb.ProcessIntelligenceLive`).

xaas does not reimplement any of that. `OcelForwarder` only builds the
envelope shape `validate_envelope/1` requires and POSTs it.

## Real envelope shape (read field-for-field, not assumed)

`Ex4pm.OCEL.validate_envelope/1` requires a top-level JSON map with:

- `"schema"` — any non-nil value
- `"producer"` — a map (`Ingest.ingest_envelope/2` additionally reads
  `"agent_id"`/`"run_id"` from it for receipt bookkeeping)
- `"sequence"` — a non-negative integer
- `"events"` — a list or map of OCEL event records

`"objects"` and `"object_relationships"` are optional (default to `%{}` and
`[]`). xaas does not currently track OCEL objects/O2O relationships beyond
the per-event `"ocel:omap"` id list, so they are omitted from the forwarded
envelope.

Each event record inside `"events"` is normalized by
`Ex4pm.OCEL.normalize_event/2`, which accepts either bare OCEL-2.0-JSON keys
(`"id"`, `"activity"`, `"timestamp"`) or the prefixed JSON-OCEL keys xaas
already produces (`"ocel:eid"`, `"ocel:activity"`, `"ocel:timestamp"`) via
its key-alias lookup — so `OcelAshEmitter`'s existing per-event map is
forwarded unchanged, with no reshaping needed at the event level.

`OcelForwarder.forward/1` wraps that unchanged event map in:

```elixir
%{
  "schema" => "xaas.ocel.v2",
  "producer" => %{"agent_id" => "xaas", "run_id" => run_id()},
  "sequence" => System.unique_integer([:positive, :monotonic]),
  "events" => [event]
}
```

## Configuration

- `config :xaas, :ex4pm_ocel_ingest_url` — the full ingest URL (e.g.
  `http://localhost:4001/api/v1/ocel/events`), set via the
  `EX4PM_OCEL_INGEST_URL` env var in `config/runtime.exs`. `nil` (unset)
  disables forwarding entirely — `OcelForwarder.forward/1` becomes a no-op.
- `config :xaas, :ex4pm_ocel_ingest_timeout_ms` — Req's `receive_timeout`,
  via `EX4PM_OCEL_INGEST_TIMEOUT_MS` (default `2000`).

HTTP client: `Req` (already a transitive/direct dependency per
`mix.lock`, backed by `Finch`) — no new HTTP dependency was added.

## Failure handling

Forwarding is always best-effort and non-fatal, mirroring
`OcelAshEmitter.append_ocel_event!/1`'s existing `rescue` pattern: an
unreachable, slow, or erroring `ex4pm_web` never raises into or blocks the
Ash action whose `:telemetry` `:stop` event triggered it. Non-2xx responses
and transport errors (`Req.post/2` returning `{:error, reason}`, or any
unexpected raise) are caught and logged via `Logger.warning/1`;
`OcelForwarder.forward/1` always returns `:ok`.

## What is explicitly NOT xaas's job

Once an event lands in `ex4pm_web` via this forwarder, all downstream
process-mining work — DFG discovery, conformance checking, and beam4pm's
`rf1-dfg-oracle`/`rf2-conformance-oracle` Rust-oracle-backed analysis — is
ex4pm_engine's and beam4pm's job, not xaas's. xaas does not reimplement OCEL
validation, DFG discovery, or conformance logic anywhere in this codebase;
`Xaas.Telemetry.OcelForwarder` is exclusively an egress/transport concern.

## Testing

`test/xaas/telemetry/ocel_forwarder_test.exs` is a real, Chicago-style
integration test — no mocked HTTP client. It starts a real `Bandit` server
on a real loopback port running a real `Plug.Router` that captures the
actual decoded JSON body, then asserts `OcelForwarder.forward/1` produces a
real HTTP POST whose body matches `Ex4pm.OCEL.validate_envelope/1`'s real
required shape, plus real non-fatal-failure and no-op-when-unconfigured
cases.

## See also

- `beam4pm-ex4pm-dependency-decision.md` — why no mix path/hex dependency on
  beam4pm/ex4pm exists; this forwarder is the "batch 2" HTTP integration
  that document anticipates.
- `lib/xaas/telemetry/ocel_ash_emitter.ex` — the real Ash-action telemetry
  source this forwarder's input comes from.
