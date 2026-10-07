# W734 — Xaas.Igniter domain deepening (PackManifest + RefusalCode)

- **Subject**: /Users/sac/xaas @ a0723bf6, branch feat/playwright-surface, untracked new file
  `test/xaas/igniter_deepening_test.exs` (only tree change; nothing committed per lane order).
- **Wave**: v26.10.6 lane W734, undocketed surface PW7 (ggen_igniter catalog).
- **Reads before writes**: `lib/xaas/igniter.ex`, `lib/xaas/igniter/{pack_manifest,refusal_code,catalog}.ex`,
  `test/xaas/igniter/igniter_catalog_test.exs`, `test/xaas/ggen_lock_closure_test.exs`,
  `test/xaas/generated/registry_drift_guard_test.exs`, `ggen.toml`, real upstream store
  `/Users/sac/ggen_igniter/priv/schema/refusals.schema.json` (138 refusals, verified on disk).

## μ/diff (generated-vs-handwritten)

Handwritten test file (no generator profile exists for consumer-side test trees; no
UNSUPPORTED receipt needed — tests are not ggen-projection territory here).

## Courts added (11, all Chicago-style: real Ash actions, real files, zero mocks)

1. PackManifest ingest from the REAL `ggen.toml` `[packs.*]` pin set (parsed from the file) →
   rows projected with real field round-trip.
2. Duplicate identity is two-layered, both layers asserted on real state:
   - resource identity `unique_pack_name` (pre_check_with Ets) REFUSES a raw second create
     (`{:error, %Ash.Error.Invalid{}}`);
   - `Catalog.ingest_packs/1` UPSERTS (update-in-place), idempotent.
3. `update` action accept-list contract: mutable fields update; `pack_name` (PK) not
   accepted → `Ash.Error.Invalid`.
4. RefusalCode create/read round-trip incl. broken_term/owner/fix_hint/retryable; duplicate
   `code` refused by `unique_code` identity.
5. **Honest typing (read-first)**: the RefusalCode resource is OPEN at the attribute level
   (plain writable string PK). The typed closed-set discipline lives UPSTREAM
   (ggen_igniter `refusals.schema.json` + `Catalog.ingest/1` validation). Asserted the real
   open contract + the real upstream typed gate (`:invalid_refusal`, `:invalid_schema`,
   `:invalid_json`) instead of fabricating a resource-level constraint that does not exist.
6. Full real-schema ingest projects every code, family, retryable, broken_term, owner,
   fix_hint faithfully (138 rows, per-row field assertion).
7. Cross-surface pin: `Catalog.default_schema_path()` exists as a regular file, decodes,
   has `$schema` + non-empty `refusals`.
8. Projected family set == upstream schema family set.
9. xaas-side generated-file pins name the ggen_igniter/ggen-marketplace renderer
   (real read of `test/xaas/generated/registry_drift_guard_test.exs`).
10. Determinism: double ingest → identical count + identical projections, sorted by code;
    family histogram deterministic.
11. Pack ingest idempotent + deterministic sort order.

## Real gate output (tails)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW734 \
    mix test test/xaas/igniter_deepening_test.exs
...........
Finished in 9.7 seconds (0.00s async, 9.7s sync)
Result: 11 passed

$ ... mix test test/xaas/igniter_deepening_test.exs test/xaas/igniter/igniter_catalog_test.exs
Result: 21 passed
```

Mock gate: `grep -c "patch(\|Mock"` on the new file → 0.

## Standing

- New file: **ALIVE** — 11/11 observed passing on exact subject a0723bf6 + this diff.
- Pre-existing `test/xaas/igniter/igniter_catalog_test.exs`: ALIVE, unaffected (21/21 with
  the new file running alongside; pre-existing pass, not session-introduced).

## Typed gaps / notes

- **Blocking defect (pre-existing, upstream of this lane)**: `Catalog.ingest_packs/1`
  requires STRING-keyed pack maps; atom-keyed entries are refused `:invalid_manifest`
  (`{0, ["pack_name","version"], nil}`). This is now a pinned contract (court 2/11), not a
  bug claim — JSON manifests decode string-keyed so the real path is safe; noted because
  the docstring says "decoded map" without the key-type qualifier.
- `ggen.lock`/`ggen.toml` carry NO ggen_igniter pack pin (only `xaas_castle_bridge`);
  the ggen_igniter linkage is therefore pinned via (i) the absolute upstream schema path in
  `Catalog` and (ii) the registry-drift-guard renderer pins — courts 7-9 assert exactly
  those, cheaply checkable. `ggen_lock_closure_test.exs` owns ggen.lock↔ggen.toml closure;
  not duplicated here.
- Lane build root `_build-laneW734` NOT deleted (rm denied in this session) — left for
  coordinator cleanup per lane law.
