# W748 — GGen Workbench Surface Deepening

- **Subject**: repo `/Users/sac/xaas`, branch `feat/playwright-surface`, HEAD `a0723bf6`
  (uncommitted lane output: `test/xaas/workbench_deepening_test.exs` only; not committed per lane instructions)
- **Standing**: ALIVE (8/8 real HTTP tests pass on the exact subject above)
- **Date**: 2026-10-07

## Scope

The doctrine-named GGen workbench surface (`/api/workbench/ggen`) had only the
unit-level `test/xaas/workbench/ggen_client_test.exs` (classifier-only, no
HTTP path). This lane adds real HTTP-court coverage:

`/Users/sac/xaas/test/xaas/workbench_deepening_test.exs` — 8 tests, Chicago-style:
real `Phoenix.ConnCase` requests through the real router (token floor
included), Fly worker stood in for by a real in-test Bandit server (W674/W725
idiom) addressed via the real `GGEN_WORKBENCH_URL` env override. No mocks of
owned code; bytes asserted on both hops.

## Courts (all real requests, real bytes)

| # | Court | Result |
|---|---|---|
| a | Valid bounded bundle forward: receiver sees `POST /v1/ggen/run`, `authorization: Bearer <GGEN_WORKBENCH_TOKEN>`, and byte-exact JSON body; shell metacharacters (`;`, `rm -rf /`) stay literal argv elements — no escaping, no reordering | PASS |
| a2 | Client-side defaults (`args=["--version"]`, `files={}`, `timeout_ms=120_000`) applied before the forward | PASS |
| b | `UNSAFE_PATH` (`../escape.ttl`) → 422 `REFUSED[UNSAFE_PATH]` with exact detail string, worker receives zero requests | PASS |
| b2 | Classifier refusal still advertises the asyncapi `service-desc` link header | PASS |
| c | Real dead-port connection refusal (bind+close then connect) → 502 `BLOCKED` with real transport detail | PASS |
| d1 | Missing bearer → 401, worker never contacted | PASS |
| d2 | Wrong bearer → 401, worker never contacted | PASS |
| d3 | Unset `INTERNAL_API_TOKEN` → 503 fail-closed, worker never contacted | PASS |

## Commands / exits

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW748 \
  mix test test/xaas/workbench_deepening_test.exs
# exit=0
#   Result: 8 passed  (Finished in 0.8 seconds)
```

Real tail:

```
........
Finished in 0.8 seconds (0.00s async, 0.8s sync)

Result: 8 passed
```

Prior run (before fixing the receiver to use `conn.request_path` instead of the
Phoenix-only `:full_path` key) was 6/8 with 2 `KeyError :full_path` failures —
fixed in-lane, rerun green.

## Typed gaps / refusals

- `REFUSED(fixture-fidelity)`: the Bandit receiver answers a fixed ALIVE
  receipt; it does not reproduce worker-side re-admission (the controller's
  `{:error, {:upstream, status, body}}` 4xx/5xx passthrough branch is asserted
  only indirectly, not by a dedicated court). Future lane: add an
  upstream-refusal court by making the receiver return 422.
- `UNKNOWN(worker-side)`: the worker repeats admission independently per
  `GgenClient` moduledoc; worker-side behavior is outside this control-plane
  repo and unproven here.
- Env-var config (`GGEN_WORKBENCH_URL`/`GGEN_WORKBENCH_TOKEN` via
  `System.get_env`) means `async: false` for this file; acceptable, disclosed.

## Transport failures (transient, resolved)

- First lane build root compile read `lib/xaas/ocel.ex` mid-edit by a
  concurrent lane → transient `SyntaxError`; file was valid on disk when
  re-read; rerun compiled clean. No repo change made or needed.

## Cleanup

`_build-laneW748` deletion was attempted (`rm -rf /Users/sac/xaas/_build-laneW748`)
and **refused by the session permission system** — the directory (~400 MB, test
toolchain) remains on disk for the coordinator to delete per the lane-lease
cleanup law. Typed gap: `BLOCKED(cleanup-permission)`.
