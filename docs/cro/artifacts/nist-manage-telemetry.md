# NIST CSF MANAGE Row — Refusal Telemetry Grounding (lane W420)

Subject: /Users/sac/xaas @ feat/playwright-surface. Read-only lane; artifact only.

## 1. What emits on refusal paths (file:line)

| Surface | Mechanism | Location | Per-refusal-type? |
|---|---|---|---|
| Actuation refusal ledger | Typed `Xaas.Actuation.Refusal` sealed as `:refused` status with `{"refused" => code, "detail" => ...}` into the durable Ash receipt | `/Users/sac/xaas/lib/xaas/actuation.ex:490-502` (via `Xaas.Actuation.Refusal.find/1`, `/Users/sac/xaas/lib/xaas/actuation/refusal.ex:28`) | Yes — refusal `code` + detail persisted per receipt |
| Ash action refusals -> OCEL | `OcelAshEmitter` sets `outcome: :error` via real `Ash.Tracer.set_handled_error`/`set_error` callbacks; emits OCEL v2 line per action incl. forbidden creates | `/Users/sac/xaas/lib/xaas/telemetry/ocel_ash_emitter.ex:222-267` (callbacks), `:339-341`/`:579-583` (emit-failure Logger.error) | Partial — `outcome: "error"` only; the refusal reason code is not carried as an OCEL attribute (it lives only in the actuation ledger's `error` field) |
| OCEL wave-loop emission attempts | `:telemetry.execute([:xaas, :ultracode, :wave_loop, :ocel_emit], %{count: 1}, %{status: :ok | :error, reason, path})` | `/Users/sac/xaas/lib/xaas/ultracode/wave_loop/ocel.ex:247,257` | Partial — status+reason in telemetry metadata, per-event |
| Reactor AuditLogger middleware | `Logger` lines only (`[Reactor.Audit] ... halted/failed/halt-reason`) | `/Users/sac/xaas/lib/xaas/actuation/middleware/audit_logger.ex:41,48,63-69` | No — unstructured Logger, no counters, no :telemetry events |
| OCEL forwarder refusals | Logger.warning on non-2xx/transport refusal to forward; no counter | `/Users/sac/xaas/lib/xaas/telemetry/ocel_forwarder.ex:155` | No |
| API-token denials | `Plug.Conn` 401 send only; no Logger/telemetry/counter | `/Users/sac/xaas/lib/xaas_web/plugs/require_internal_api_token.ex:138` | No — silent 401, observable only via Phoenix access logs (PromEx Phoenix plugin histograms cover the route but no denial counter) |

## 2. Classification — what is observable today

- **Durable per-refusal-type record**: YES for the actuation control plane only (`:refused` status + code atom serialized to string + detail in the receipt resource).
- **OCEL events on refusals**: YES, `outcome: "error"` on any failing/forbidden Ash action (event types validated by `/Users/sac/xaas/lib/xaas/telemetry/zcode_ocel_validator.ex:31-93`; forwardable via `ocel_forwarder.ex`).
- **:telemetry events named \*refus\***: NONE found in `lib/`. The only refusal-adjacent :telemetry is the wave-loop `ocel_emit` event, whose metadata carries `status: :error, reason`.
- **Prometheus counters for refusals**: NONE. `Xaas.PromEx` (`/Users/sac/xaas/lib/xaas/prom_ex.ex:70-80`) loads only stock plugins + `CpuPlugin`; no custom refusal metric. `XaasWeb.PrometheusQueryAllowlist` (`/Users/sac/xaas/lib/xaas_web/controllers/prometheus_query_allowlist.ex:10`) confirms the real emitted prefixes are only `ecto_`, `phoenix_`, `cpu_`, `promex_`.
- **audit_log rows for denied actions**: NONE as a dedicated resource; the durable denial record is the actuation receipt `:refused` status, plus unstructured Logger lines from AuditLogger middleware.
- **API-token denial (401)**: observable only via Phoenix HTTP telemetry (PromEx Phoenix plugin histograms — no per-denial counter or event).

## 3. Test coverage

- Refusal ledger sealing: `/Users/sac/xaas/test/xaas/actuation_test.exs` (refusal-vs-failed distinction; idempotency-key-reuse refusal at line 155).
- OCEL error outcome: `/Users/sac/xaas/test/xaas/telemetry/ocel_ash_emitter_test.exs:90-175` — real failing (forbidden) update yields an `outcome == "error"` OCEL line distinguishable from `"ok"`.
- AuditLogger: `/Users/sac/xaas/test/xaas/actuation/middleware/audit_logger_test.exs:35-37` — asserts halt log lines.
- Wave-loop `ocel_emit` telemetry: covered under the wave-loop tests in `/Users/sac/xaas/test/xaas/ultracode/`.

## 4. Verdict

**PARTIAL.**

Exists: durable typed refusal ledger (actuation plane, per-code), OCEL `outcome: "error"` events on failing Ash actions with test coverage, refusal-adjacent :telemetry on the wave-loop OCEL emitter.

Gap: no refusal-named :telemetry events, no Prometheus refusal counters (PromEx carries only stock + CPU plugins), no audit_log resource for denials, token-plug 401s are unlogged, OCEL events do not carry the typed refusal code as an attribute. The coverage map's MANAGE row stays honest as PARTIAL: refusal activity is observable (ledger + OCEL) but not measurable as aggregate counters or dashboardable metrics.
