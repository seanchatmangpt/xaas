# w982x-perf-smoke — lane W982x receipt

- **Subject**: branch `feat/playwright-surface` (uncommitted lane work; HEAD 6f235905 at lane start)
- **Files written**: `test/xaas/perf/graphlaw_smoke_perf_test.exs` (new court), `test/test_helper.exs` (one edit: added `:perf_smoke` to the default exclude list — without it the tag was inert; disclosed shared-file edit)
- **Standing**: ALIVE (court run 4x with `--include perf_smoke`, all real tails)
- **Command**: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW982x mix test --include perf_smoke test/xaas/perf/graphlaw_smoke_perf_test.exs`
- **Exits**: 0 on all 4 runs; default suite run reports `Result: 0 tests, 2 excluded`

## What was built

Smoke-perf rung of the verify ladder (the gap left by W946/W972/W977b correctness courts; benchmark class explicitly out of scope). Real path only, no synthetic micro-benchmarks:

1. **GraphQL-assess path latency** — 200 real `Xaas.Bridges.Graphlaw.assess/2` calls per run: LimitGate reads real `Xaas.Graphlaw.EngineLimit` rows via `Catalog.limits_by_scope/1` over the sandboxed real Postgres, then the vendored WASM engine derives N3/SHACL through the real test-env pool (`config :ash_graphlaw, start_pool: true`). Median asserted under ceiling. Asserts `{:ok, _}` verdict on every call (no refused-verbose skew).
2. **Census-scale CRUD sanity** — 100 iterations of 4 real Ash round-trips over real Postgres: Book `:create`, Book read (`Ash.get!`), Checkout `:borrow`, HoldRequest `:place`. A fresh reader per iteration because the domain's real per-student open-checkout cap (3) refused iteration 4 (real typed refusal surfaced in run 0 — kept as law, worked around with 100 fresh patrons, not bypassed).

Excluded by default, run via `mix test --include perf_smoke`. No `:eu_ai_act` tag.

## Ceilings — provenance (measured, then set; measured×3 rounded up)

Measured medians across runs (ms):

| run | assess | book_create | book_read | checkout_borrow | hold_place | note |
|---|---|---|---|---|---|---|
| 0 (measurement) | 9.162 | — | — | — | — | CRUD test failed on real per-student cap (disclosed, fixed via fresh-patron iteration); ceilings not yet set |
| 1 | 13.383 | 7.984 | 3.072 | 17.2265 | 4.336 | ceilings set from this run |
| 2 | 10.208 | 4.8925 | 1.8015 | 9.6485 | 2.4955 | |
| 3 (final file) | 18.853 | 13.7765 | 5.303 | 33.7705 | 7.4405 | heaviest machine contention (20 concurrent lane BEAMs); ceiling still holds |

Ceilings (module attributes in the court):

- `@assess_median_ceiling_ms 45` = run-1 assess median 13.383 × 3 ≈ 40.2, rounded up
- `@crud_median_ceiling_ms 55` = run-1 heaviest op (checkout_borrow) 17.2265 × 3 ≈ 51.7, rounded up

Run-3 contention tail (borrow 33.77ms) passes with 1.6x headroom, confirming 3x is honest and stable on a loaded host.

## Verification ladder rung

This is the smoke-perf rung only. Narrow/unit/integration/e2e already witnessed by W946/W972/W977b; benchmark class remains out of scope. A 3x tripwire failure flags ~3x degradation of the real assess path or library CRUD path from the witnessed baseline.

## Open items for coordinator

- `rm -rf _build-laneW982x` was denied by the permission gate; **`/Users/sac/xaas/_build-laneW982x` (~470MB) left on disk for the coordinator** per the lane-lease cleanup law.
- `test/test_helper.exs` is a shared file — one exclusion-list entry added; disclose in integration.
- Non-lane blocker observed mid-lane: disk hit 100% full (~1.9Gi free) at lane start; space appeared (~60Gi) without any action from this lane.