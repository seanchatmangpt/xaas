# W750 — Capability-liveness ALIVE-receipt composed court (deepening)

- **Lane**: W750, xaas v26.10.6, branch `feat/playwright-surface` @ `a0723bf6`
- **New file**: `test/xaas/operations/capability_liveness_deepening_test.exs` (8 tests, all real rows, no mocks)
- **Standing**: PARTIAL_ALIVE — machinery observed working end-to-end under test; two typed doctrine gaps pinned as real behavior (below).

## What ran (real tails)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW750 \
  mix test test/xaas/operations/capability_liveness_deepening_test.exs
# => Result: 8 passed (0.00s async, 1.7s sync), zero warnings after fix
```

Full-lane command exited 0 on a clean second run (first run: 1 compile error `conn/0` undefined — fixed to `build_conn()`; fixed-forward, no reset).

## What the real contract actually is (asserted, not assumed)

- (a) Round trip: real `Ash.create!(:ingest)` row → real GET
  `/internal-api/capability_liveness_receipts?filter[capability]=...`
  (AshJsonApi forward, `:require_internal_api_token` floor) returns the row
  verbatim (id, capability, authority, status, executed, exit_code, subject). 401
  without token, capability string absent from the response body.
- (b) **GAP[G1 — no ALIVE-requires-execution gate]**: `executed` is a plain
  `:boolean` defaulting to `true`; `status` is a free `:string`. An ingest of
  `status: "ALIVE", executed: false` (or a fully fabricated status string) is
  accepted, persisted, and served through the route as-is. No refusal, no
  downgrade, no status enum. Doctrine's "ALIVE requires observed execution" is
  prose-only at this resource.
- (c) **GAP[G2 — no TTL/staleness]**: a receipt backdated 365 days (real
  `Repo.update_all` on `inserted_at`) is still served ALIVE through the route and
  yields no regression from `detect/1`. The only staleness machinery is:
  idempotent re-ingest (upsert on `capability_subject` identity) overwriting
  status in place — which *destroys* prior-ALIVE history, so a real
  ALIVE→non-ALIVE overwrite is invisible to `detect/1` (pinned in test); the
  regression rule fires only across distinct subjects ordered by `inserted_at`
  (verified with a 2ms sleep against the same-ms hazard).
- (d) Determinism: 3 repeated ingests of identical attrs → exactly 1 row, same
  id; two consecutive route GETs return identical bodies.

## Verification ladder

narrow (this file, 8 green) — unit-level only; integration is exercised via the
real HTTP route but no e2e/stress beyond existing suites
(`capability_liveness_receipt_stress_test.exs` untouched, still green elsewhere).

## Gaps / follow-ups (typed)

- G1: add a change validation on `:ingest` refusing `status=="ALIVE" and not
  executed` (typed ALIVE_WITHOUT_EXECUTION), or an explicit downgrade rule
  (ALIVE+unexecuted → stored as-is but flagged). Current behavior pinned by
  test so a future gate lands as a visible diff.
- G2: `detect/1` is blind to upsert-overwritten regressions (history destroyed
  by the identity upsert). A real fix needs an append-only observation log or a
  `previous_status` column; the current single-row blindness is pinned.
- No TTL: age never affects served status or detect/1; if staleness is wanted,
  it is new machinery, not a config flip.

## Lane lease

`_build-laneW750` deletion was denied by the permission system; **left for
coordinator** (lane-lease law: coordinator deletes at integration).
