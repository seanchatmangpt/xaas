# W860 — Per-check health-check timeout (W836 typed-gap closure)

Subject: /Users/sac/xaas @ feat/playwright-surface, HEAD `a0723bf6` (canonical
checkout; lane build root `_build-laneW860`).

## Task

W836's receipt typed the gap: no check had a timeout — a hung collaborator
(e.g. an Ontop that accepts but never answers) would hang the health request
itself. Fix minimally: wrap each check in a bounded `Task` with
`Task.await/2` and a documented per-check ceiling; on timeout report the
typed failure; aggregate fail-closed rule unchanged.

## Before / After

**Before** (`lib/xaas_web/controllers/health_controller.ex`, `timed/1`):
check bodies executed inline inside `try/rescue/catch` — exits/throws were
typed, but a *stall* (no return) had no bound: the request hung forever.

**After**: every check body now runs in a `Task.async` owned by the request
process, reaped by `Task.await(task, @check_timeout_ms)` with
`@check_timeout_ms = 2000` (module attribute, documented: comfortably above
every check's healthy latency — a `SELECT 1`, a local HTTP probe, indexed
`Ash.count!`s, one `oban_jobs` query — while bounding a hung request to ~2s).

- On expiry, `Task.await` exits `{:timeout, {Task, timeout}}`, caught and
  reported as `{:timeout, ceiling}` → JSON `status: "error"`,
  `detail: "timeout: check exceeded 2000ms"` (same `"error"` + string
  `detail` convention as the transport-error branch). `latency_ms` still
  real (>= 2000). Aggregate: still fail-closed — a timed-out check is an
  `"error"`, so 503, exactly like any other real error.
- The task body itself classifies raise/exit/throw into `{:raised, e}` /
  `{:caught, kind, reason}` values, so the pre-W860 typed shapes are
  preserved *exactly* (structured `{exception, message}` map for raises;
  `"exit: ..."` / `"throw: ..."` strings for catches) — W836's pinned
  contract did not move.
- `Process.unlink(task.pid)` before `await`: belt-and-braces so a task
  death cannot kill the request process ahead of the handlers. The
  abandoned hung task dies with the request process (a Task monitors its
  owner); nothing leaks past the ceiling.
- Moduledoc unchanged except: timeout contract documented on the
  `@check_timeout_ms` comment block; nothing else in the module moved
  (checks, aggregate, seams, config gates untouched).

## Tests (test/xaas_web/health_court_test.exs, extended only)

New section (c2), one test: **"W860 timeout: a check that never returns
reports the typed {:timeout, ceiling} failure and the endpoint still
responds 503"** — real hung collaborator via the existing real
`:ontop_proxy_http_client` seam (`NeverAnsweringOntop.request/1 ->
Process.sleep(:infinity)`, same disclosed real-stand-in pattern as the
whole file; no mocks). Asserts: endpoint responds 503 / `"error"` (the
responds-at-all assert), `ontop.status == "error"`, binary `detail =~
"timeout"` and `=~ "2000"`, `latency_ms >= 2000`, and every other real
check stays `ok` (fail-closed on exactly the hung check). 11 -> 12 tests.

## Mutation rationale

Drop the bounded-Task wrap (revert `timed/1` to inline `fun.()`): the
W860 test's `get_health!(conn)` never returns — `NeverAnsweringOntop`
sleeps forever — so `assert status == 503` never executes and the test
fails by the test process being killed waiting on the request (never
passes). Secondary asserts that also die with the mutation: `detail =~
"timeout"`, `latency_ms >= 2000` (a completed check would report its real
sub-2s latency). Existing shape tests (raise -> `{exception, message}`,
exit -> `"exit: ..."` string) pin that the wrap did not disturb the typed
failure shapes.

## Real bug found and fixed forward during the lane (disclosed)

First implementation (`Task.await(Task.async(fun), @check_timeout_ms)` with
the caller-side rescue/catch only) failed the existing court 9/12 -> 10/12:
`Task.async` links the caller, so a *crashing* check killed the request
process ahead of the handlers (raise test got the process-killed EXIT;
after unlinking, the crash arrived as an untyped `{:task_crash, ...}` exit
string, breaking W836's pinned `{exception, message}` shape). Fix (run 3 ->
run 5): classify inside the task body (values, never abnormal task exit) +
unlink before await. Failure classes preserved exactly; found by the court,
not by inspection — the court did its job.

## Verification

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW860 \
  mix test test/xaas_web/health_court_test.exs
```

Run A (run 5, exit 0):

```
............
Finished in 2.7 seconds

Result: 12 passed
```

Run B (run 6, exit 0) — court again + W752's internal-api router spec:

```
mix test test/xaas_web/health_court_test.exs test/xaas_web/internal_api_router_test.exs
..............
Finished in 2.6 seconds

Result: 14 passed
```

W752 note: `test/xaas_web/internal_api_router_test.exs` green alongside the
court in run B — the timeout wrap does not touch routing/auth surface.
(W752's receipt also mentions e2e validation; not run here — no server/e2e
in this lane, noted per contract, not gate.)

## Standing

ALIVE — 12/12 court ×2 (runs 5 and 6) against exact HEAD `a0732…` on
`feat/playwright-surface`, plus W752 internal-api spec co-run green.

## Typed gaps / notes

- The 2000ms ceiling is a module constant, not config; if a deploy ever
  grows a legitimately slower check, the constant moves by one edit
  (documented at the attribute).
- Real abandoned task footprint: a hung check task lives until its owner
  (request process) exits — bounded by the ceiling in wall-clock, no
  persistent leak.
- Lane hygiene: `_build-laneW860` deletion was refused by the permission
  system (`rm -rf` denied), same as W836's lane root; left in place for
  the coordinator per the fanout cleanup law (~437 MB, test+deps build).
  Files written: controller, court test, this receipt only. Not
  committed, per lane contract.
