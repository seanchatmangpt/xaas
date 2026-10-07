# W984cn — Oban / Background-Job Depth Court (v26.10.6 campaign)

- **Lane**: W984cn, checkout `/Users/sac/xaas`, branch `feat/playwright-surface`
- **Standing at close**: PARTIAL_ALIVE for the uncourted slices now courted;
  webhook retry / check_regressions / warming_up health / e2e remain under
  their pre-existing courts (excluded slices)
- **Date**: 2026-10-07

## Scope decision (covered-minus)

Read fresh: `config/config.exs` (`config :xaas, Oban` — 12 queues, Basic
engine, Postgres notifier, Cron + Lifeline plugins), `config/test.exs:111`
(`testing: :manual`), and the worker surface:

| Surface | Existing coverage found | Disposition |
|---|---||
| Health controller `warming_up` / Oban health contract | `test/xaas_web/health_court_test.exs` (W836), `health_controller_test` | excluded per task |
| e2e specs | `e2e/` | excluded per task |
| Webhook `:retry_failed_deliveries` fan-out + authority | `platform_depth_w984bq_test.exs` (4), `deliver_webhook_test` | covered, excluded |
| CapabilityLivenessReceipt `:check_regressions` schedule | `capability_liveness_receipt_check_regressions_test.exs` | covered, excluded |
| `SelfDigestWorker.perform/1` behavior | `self_digest_worker_test.exs` | covered, excluded |
| HoldRequest per-row `:expire`/`:expirable` | `hold_request_test.exs` | covered, excluded |
| **Job-level lifecycle** (Oban.insert → drain → job row state), **the AshOban `:expire_stale_holds` batch as a real Oban job**, **error→discard per real `max_attempts: 1`**, **queue config/DSL parity**, **runtime Oban config invariants** | — | **uncourted → courted here** |

## Tests written

`test/xaas/oban_depth_w984cn_test.exs` — 6 tests, Chicago (real Postgres
`oban_jobs` rows, `Oban.insert`/`Oban.drain_queue` in real
`testing: :manual` mode, zero mocks; mock gate on the file: `[]`):

1. **AshOban `:expire_stale_holds` batch as a real Oban job** — 2 expired +
   active-future + cancelled-past controls over real holds; insert
   `Xaas.Library.HoldRequest.Workers.ExpireStaleHolds`, drain its real
   queue (`:hold_request_expire_stale_holds`, resolved from
   `ExpireStaleHolds.__opts__()[:queue]`), job row `"completed"`, expired
   rows `:expired`, controls untouched.
   Mutation rationale: no-op the `:expire_stale` generic action → expired
   holds stay `:active`, court fails; force-change `expires_at` semantics
   or the `:expirable` filter → controls flip, court fails.
2. **Idempotent rerun** (extra 6th test, over the 5-test minimum) — second
   drain transitions zero rows (now-`:expired` rows leave the `:expirable`
   set), job still completes.
   Mutation rationale: a batch that re-expires or re-queues rows breaks the
   rerun assertion.
3. **SelfDigestWorker job lifecycle** — real insert→drain→`"completed"`
   with real completion side effects asserted on state: admitted
   self-subject `WorkOrder` and `self-digest-receipt.json` with
   `schema == "xaas.self-digest-receipt/1"` and a 3-count recurring
   cluster. Mutation rationale: a digest that completes without admitting
   (or a worker that returns `:ok` without writing the receipt) fails the
   state assertions; the existing perform/1 court never exercised the
   insert→drain→job-row path.
4. **Error path per real config** — unreadable telemetry → typed
   `{telemetry_unreadable, _, :enoent}` refusal recorded on the job,
   `state == "discarded"`, `attempt == 1` (real `max_attempts: 1`),
   drain summary `{success: 0, discard: 1, failure: 0}`, **zero**
   WorkOrders (no side effect on failure).
   Mutation rationale: a worker that returns `:ok` on refusal, or a config
   with `max_attempts > 1`, changes the drain summary / attempt count and
   fails the court.
5. **Config/DSL parity court** — for all 3 AshOban schedules
   (HoldRequest, WebhookDelivery, CapabilityLivenessReceipt): schedule
   registered (`AshOban.Info.oban_triggers_and_scheduled_actions/1`),
   derived queue is a real key in `config :xaas, Oban[:queues]`, worker
   module compiled and `__opts__()[:queue]` matches; plus hand-written
   workers (`SemanticWaveTrigger.Worker`, `SelfDigestWorker`) queue
   `:ultracode_wave` configured — the boot-time `AshOban.require_queues!/4`
   law re-asserted as a permanent court.
   Mutation rationale: adding a schedule/worker without a config queue (the
   exact boot-refusal class ULTRACODE-50 hit) fails the court.
6. **Runtime Oban config invariants** — Basic engine, `Xaas.Repo`,
   `testing: :manual` in test, Lifeline `rescue_after {75, :minutes}`
   (P0.1 watchdog), Cron `"17 6 * * *"` → `SelfDigestWorker`.
   Mutation rationale: dropping the Lifeline watchdog or moving the cron
   off `17 6 * * *` fails the court.

## Verification (real output)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984cn \
  mix test test/xaas/oban_depth_w984cn_test.exs
→ Result: 6 passed          (seed 229495, then fresh rerun seed 645351 → 6 passed)
mock gate scan of the file → []
```

×2 fresh-root runs, both 6/6, different seeds.

## Transport failures (pre-existing, shared-tree, not this lane's diff)

- First compile hit a lane-in-flight broken edit in
  `lib/mix/tasks/xaas.release_audit.ex`; per the compile-freeze SLA I
  waited and the owning lane fixed it (compile OK, warnings only).
- A second in-flight break (`xaas.airo.compile_shacl.ex`, then
  `quiescent_stop.ex`) recovered the same way; recovered via SLA wait loop.
- `rm -rf _build-laneW984cn` was permission-denied → **build root left in
  place for the coordinator** per the lane-lease law (not orphaned by
  choice).

## Receipt fields

- **Subject**: `test/xaas/oban_depth_w984cn_test.exs` (only file written
  besides this receipt); generated-vs-handwritten: 100% handwritten court.
- **μ/diff**: 1 test file, 6 tests; no lib/ changes, no config changes.
- **Standing**: ALIVE for the six courted assertions on the exact subject
  (6/6 × 2 seeds); excluded slices retain their pre-existing court
  standings, untouched.
- **Falsifiers**: each test's mutation rationale above; court fails if the
  expire batch no-ops, the worker completes without side effects, the
  error path leaves a retryable job, a queue loses its config key, or the
  Lifeline/cron/watchdog config drifts.
