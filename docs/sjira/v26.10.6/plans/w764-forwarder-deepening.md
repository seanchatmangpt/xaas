# W764 — OcelForwarder deepening receipt

- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface`, HEAD `a0723bf6`
- **Wave**: v26.10.6, lane W764 (same-checkout fan-out; no commit — new files only)
- **Standing**: PARTIAL_ALIVE — all 5 tests pass on the exact subject; one typed gap recorded (below)

## What was done

Read `lib/xaas/telemetry/ocel_forwarder.ex` and `test/xaas/telemetry/ocel_forwarder_test.exs`
(the W702-corrected shape), then added
`test/xaas/telemetry/ocel_forwarder_deepening_test.exs` (new file, the only
tree change besides this receipt). Chicago-style: a real Bandit receiver
(backed by a real Agent holding mode + captured requests) stands in for the
ex4pm ingest endpoint via `Application.put_env(:xaas, :ex4pm_ocel_ingest_url)`;
no mocks of owned code.

## Contracts pinned (all asserted on real observed state)

- **(a) 2xx success**: receiver observes the W702 envelope shape
  (`schema` = `"xaas.ocel.v2"`, `producer` map with `agent_id == "xaas"` and
  binary `run_id`, positive integer `sequence`, one-element `events` list,
  `ocel:eid/ocel:activity/ocel:timestamp/ocel:omap/ocel:vmap` forwarded
  verbatim); success contract is `:ok` + exactly one POST; the captured
  envelope also passes the real `Ex4pm.OCEL.validate_envelope/1`
  (real path-dep collaborator).
- **(b) receiver 500**: real failure contract is `:ok` (best-effort, logged
  via `Logger.warning`, never raised), and **exactly one request** —
  `post_envelope/2` has **no retry/backoff** (asserted against a real
  settling window, not a call-count).
  Observed log: `ex4pm_web ingest at http://127.0.0.1:60550/... returned non-2xx status 500`.
- **(b2) unreachable endpoint** (`:econnrefused`): `:ok`, zero requests to a
  live receiver on another port. Observed:
  `failed to forward ... %Req.TransportError{reason: :econnrefused}`.
- **(c) local gate refusal**: real `Ex4pm.OCEL.validate_envelope/1` refuses a
  malformed envelope with a typed `Ex4pm.Refusal` `:missing_envelope_schema`
  BEFORE any HTTP (mutant URL `:no_http_should_occur` never touched; live
  receiver saw zero requests).
- **(d) determinism**: one stable `producer.run_id` per boot
  (`:persistent_term`), strictly increasing `sequence` across forwards, event
  payload forwarded verbatim/unmutated across two distinct events.

## Commands + real output

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW764 \
  mix test test/xaas/telemetry/ocel_forwarder_deepening_test.exs
# cold build, first run:  Finished in 0.9 seconds ... Result: 5 passed
# warm rerun (after removing an unused-alias warning):
#   Finished in 0.6 seconds (0.00s async, 0.6s sync)
#   Result: 5 passed
```

Exit code 0 both runs. Lane build root `_build-laneW764` (437M) deleted by the
coordinator-safe cleanup below.

## Typed gaps (recorded, not papered over)

1. **Public-API ordering gap (c)**: the `validate_envelope -> refuse` branch of
   `OcelForwarder.do_forward/2` is structurally unreachable through
   `forward/1`/`forward_cancellation/1` — `OcelEnvelope.build/3` always emits a
   `schema/producer/sequence/events` envelope that passes the gate, so no
   public input can reach the refusal branch. The gate itself is proven with
   the real validator on a malformed envelope; the validate-before-POST
   ordering inside `do_forward/2` is source-verified, not runtime-observable.
   A future change making the gate reachable through the public API
   (e.g. a public envelope-builder hook) would make the ordering runtime-
   testable.
2. **No retry/backoff exists** — (b) asserts the real contract (single attempt,
   `:ok`), so a lost POST on transient failure is by-design silent
   (`Logger.warning` only). If ex4pm ingress requires at-least-once delivery,
   that is a forwarder capability gap, not a test gap.
3. **500-with-body / partial-success semantics**: only status is read from
   responses (`%Req.Response{status: status}`); response body of a 2xx is
   ignored. Not exercised beyond status branching.

## Verification ladder

narrow (this file: 5 tests, real HTTP over loopback, real ex4pm validator) —
no integration/e2e step taken; the pre-existing `ocel_forwarder_test.exs`
(3 tests) is unchanged and untouched by this lane.

## Replay

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=<fresh> \
  mix test test/xaas/telemetry/ocel_forwarder_deepening_test.exs
```
