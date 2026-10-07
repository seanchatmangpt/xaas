# W731 — Graphlaw engine-registry deepening (PW6)

- **Lane**: W731, repo `/Users/sac/xaas`, branch `feat/playwright-surface`, HEAD `a0723bf6` (uncommitted lane work)
- **Files**: new `test/xaas/graphlaw_deepening_test.exs` (only file written besides this receipt)
- **Standing**: PARTIAL_ALIVE — real Ash actions on real sandboxed Postgres, 13/13 passing; the brief's assumed `:capability_class` enum does not exist and is recorded as a typed gap, not invented.

## Command + real tails

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW731 \
  mix test test/xaas/graphlaw_deepening_test.exs
# Running ExUnit with seed: 691764, max_cases: 32
# .............
# Finished in 0.9 seconds (0.9s async, 0.00s sync)
# Result: 13 passed
```

Exit 0. Rerun (warm lane build root) also 13 passed. Lane build root
`_build-laneW731` **left in place** — `rm -rf` was permission-denied in this
session; coordinator should delete it per the cleanup law.

## What was asserted (read-first, real behavior)

- **(a) EngineLimit**: create→read round-trip of all six accepted attrs
  (`name, value, scope, source, unit, refusal_name`); `refusal_name` nil-safe;
  `unique_name` upsert (same name → same row id, value replaced, count 1);
  `Catalog.limits_by_scope/1` filters on real `scope` column, name-sorted.
- **(b) Capability**: create→read round-trip; `unique_name_algorithm` upsert
  (pair identity — same name + different algorithm = distinct rows); missing
  required attr → `{:error, %Ash.Error.Invalid{}}` naming the field; destroy
  deletes the real row.
- **(d) determinism**: `Catalog.ingest/1` twice → identical counts, stable rows
  (idempotent upserts).

## Typed gaps (W715 pattern, honest)

1. **GAP(graphlaw-capability-class)**: the W731 brief assumed an
   `:capability_class` enum (`observe/select/construct/do`) on
   `Xaas.Graphlaw.Capability`. No such attribute exists anywhere in
   `lib/xaas/graphlaw*`. The test asserts the real surface (create accepts
   exactly `[:name, :algorithm, :profile, :supported_in]` and the row struct
   has no `:capability_class` key) instead of inventing it.
2. **GAP(graphlaw-limits-not-enforced)**: `EngineLimit` rows are a pure
   registry projection. Nothing in `lib/xaas` consumes a limit to gate
   anything — a value of 1,000,000 against a recorded `max_json_depth = 64`
   persists happily. `limits_by_scope/1` is the only read helper. Consumers
   are `Xaas.Bridges.Graphlaw` (WASM purchase-policy bridge) and
   `Xaas.Bridges.Registry` (layer registry entry) — neither reads
   `EngineLimit`/`Capability` rows.
3. **GAP(graphlaw-registry-path-hardcoded)**: `Catalog.default_registry_path/0`
   is a hardcoded absolute path (`/Users/sac/graphlaw/registry/capability-registry.json`);
   ingest is host-bound, not hermetic.

## Falsifier

`PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW731 mix test test/xaas/graphlaw_deepening_test.exs` —
13 passed = PARTIAL_ALIVE standing for the projection surface as documented.
