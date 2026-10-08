# W650h23 — Repair Receipt: run_idempotency_deepening_test.exs (3 failures)

- Subject: /Users/sac/xaas @ feat/playwright-surface, HEAD ee6c18bc (no commit; working tree only)
- Lane: W650h23, MIX_BUILD_ROOT=_build-laneW650h23
- Files touched: ONE — test/xaas/actuation/run_idempotency_deepening_test.exs. ZERO lib/ changes.

## Diagnosis (measured, not inherited from W650h22's spg-atom hypothesis)

W650h22's hypothesis (stale non-spg refusal atoms) was WRONG. Real failure class:
**unscoped global reads colliding with committed foreign rows in the shared
`xaas_test` database.**

Evidence: all 3 failures assert `Ash.read!(ActuationIntent, authorize?: false) == []`
and the "left" side contained only rows like:

```
idempotency_key: "curate-deactivate:36be100e-...:1791375390931",
resource_module: "Xaas.Library.Curation", authority: %{"kind" => "liveview_librarian", "source" => "toggle_pin"},
inserted_at: 2026-10-07 12:16/12:22 UTC
```

— `liveview_librarian`/`toggle_pin` seed rows, zero of them `w747-*`. Confirmed on disk:

```
psql xaas_test -c "select count(*), max(inserted_at) from actuation_intents" → 2 rows, max 12:22:07
```

READ COMMITTED lets a sandboxed transaction see rows other sessions commit
mid-transaction, so `== []` is only stable on a quiet shared DB. No refusal-contract
change; the refusal atoms asserted (d1/d2/d3/d4 primary asserts) all passed as-is —
only the trailing nothing-durably-admitted reads were unscoped.

## Fix

Scoped the three trailing assertions to the suite's own `w747-` key prefix
(`@w747_prefix "w747-"`, `String.starts_with?` filters), so committed foreign rows
cannot fail them. No mocking; reads remain real Ash reads.

## Verification (real runs, MIX_BUILD_ROOT=_build-laneW650h23, pinned asdf toolchain)

Before (full output /tmp/w650h23-before.txt):

```
Finished in 2.6 seconds
Result: 7/10 passed, Failed: 3 tests   EXIT=2
```

After:

```
mix test test/xaas/actuation/run_idempotency_deepening_test.exs → EXIT=0, 10 passed
mix test test/xaas/actuation/spg_gate_test.exs test/xaas/actuation/spg_integration_test.exs → EXIT=0, 13 passed (no cross-damage)
mock gate scan over the 3 touched/confirmed files → []
```

## Standing: ALIVE (repaired, exit 0 x2, mock gate clean)

## Notes

- `rm -rf _build-laneW650h23` DENIED by the permission system (lane lease left on
  disk — cleanup owed by coordinator per the fanout cleanup law).
- Open hazard (not this lane's fix): something writes committed
  `liveview_librarian`/`toggle_pin` seed rows to `xaas_test` (suspect
  e2e/seed-library.exs or a server pointed at the test DB). Any other test with
  unscoped `== []` reads on shared tables carries the same flake class.
