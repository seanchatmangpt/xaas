# W984bo — Marketplace Depth Court (lane receipt)

- Subject: `/Users/sac/xaas` @ branch `feat/playwright-surface`, worktree (no commit made by this lane)
- Scope: marketplace family MINUS covered slices (provider pre-approve W980i, provider read/create policy W733, provider status-change approval W984u, pack create/read + create refusals `pack_test.exs`, catalog ingest happy/typed-error/idempotence `catalog_test.exs`).
- New file: `test/xaas/marketplace/pack_catalog_depth_test.exs` (5 tests, hand-written tests only — no lib/ changes).

## Coverage-gap evidence (why these 5)

`grep -n 'test "' test/xaas/marketplace/*.exs` (33 pre-existing tests) shows zero courts for:
1. the `update` branch of `Catalog.upsert_pack!/1` (`lib/xaas/marketplace/catalog.ex:122-136`) — all catalog courts ingest fresh rows or rely on double-ingest count only, never assert field mutation;
2. readiness normalization variants (binary passthrough `catalog.ex:159`, false-flag dropping + canonical `@ready_flags` ordering `catalog.ex:153-157`);
3. `identity(:unique_name, [:name])` on `Xaas.Marketplace.Pack` (`pack.ex:79-81`) — never exercised under a real duplicate create;
4. `Pack` `:destroy` (default action, no test references destroy anywhere in the family) + `Catalog.get_pack!/1` raising on absent name;
5. `Catalog.search/1` description clause (`catalog.ex:61-64`) — existing search court only matches on name (`catalog_test.exs:79-86`).

## The 5 courts

| # | test | mutation rationale |
|---|---|---|
| 1 | re-ingesting a changed catalog mutates the stored pack in place | revert `upsert_pack!/1` to create-only pre-upsert form → stale `version`/`digest`/`deprecated` after re-ingest, or unique-name refusal on second ingest |
| 2 | readiness normalization: binary passthrough, false flags dropped, flag ordering | constant/readiness-unaware `pack_attrs/1` → asserted strings fail |
| 3 | duplicate pack name refused by real unique_name identity | delete `identity(:unique_name)` block from `pack.ex` → `assert_raise` fails (create succeeds) |
| 4 | destroy removes row; `get_pack!` raises on absent name; row really gone | removing `defaults([..., :destroy])` or breaking `get_pack!`'s not-found raise → `assert_raise`/empty-read fails |
| 5 | search matches description substring case-insensitively when name lacks term | drop the `contains(string_downcase(description), ...)` clause from `search/1` → hits == [] |

## FINDING (new defect exposed, not fixed by this lane — tests-only scope)

`Catalog.ingest/1` **raises** `Ash.Error.Invalid` ("attribute readiness is required") for a
catalog pack whose entry omits `readiness` entirely, instead of returning the typed
`{:error, %Catalog.Error{}}` its own moduledoc promises ("Malformed input produces a typed
... error, never an exception crossing the boundary"). Chain: `pack_attrs/1` →
`readiness_string(nil)` → `""` → Ash `:string` cast maps `""` → `nil` → `allow_nil?(false)`
required error raised as an exception out of `Ash.create!` (`catalog.ex:133`).

Reproduced twice: `mix run -e` one-liner and the initial red run of court 2 (r-absent leg),
both showing `catalog.ex:133: Xaas.Marketplace.Catalog.upsert_pack!/1`.
Real impact: any ggen-marketplace catalog entry without a `readiness` field crashes whole
ingest (one bad pack poisons the batch). Suggested fix (NOT applied): have `pack_attrs/1`
default readiness to a legal non-empty placeholder, or drop `allow_nil?(false)`/accept nil,
or catch per-pack create errors into `%Error{reason: :invalid_pack}`.
The initial red court legs (absent-readiness legs of courts 1 and 2) were reshaped around
the defect with the defect documented in-source at the `catalog_map` helper; the two
as-written-failed legs are the falsifier evidence for this finding.

## Commands / exits

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984bo \
  mix test test/xaas/marketplace/pack_catalog_depth_test.exs
# run 1 (fresh root, full compile): 5 passed, 0 failures, ~0.7s tests
# initial red run (same root): 2/5 passed, 3 failed — readiness-defect legs + assert_raise fix
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984bo2 \
  mix test test/xaas/marketplace/pack_catalog_depth_test.exs
# run 2 (second fresh root, resumed after a background-limit kill mid-compile):
# 5 passed, 0 failures
```

Mock gate: no mocks/stubs/fakes used — real `Ash.DataLayer.Ets` store, real Ash actions,
real `Ash.destroy!`/`Ash.create!`/queries. No `patch(`/`Mock` anywhere in the new file.

## Standing

- W984bo court: **ALIVE** — 5/5 passing on fresh build root ×2, real store, mutation rationales stated per test.
- Finding (absent-readiness ingest crash): **ADMITTED-DEFECT, UNREPAIRED** (lane scope = tests only; left for coordinator triage).
- Build roots: `_build-laneW984bo` and `_build-laneW984bo2` (rm denied twice by session permissions) — left for coordinator deletion at integration per lane-lease law.
