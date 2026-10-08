# W984mb — Mutation Non-Vacuity Audit #9 over W984ln Readiness Guard + W984ku Curation Court

Lane: W984mb · Date: 2026-10-08 · Branch `feat/playwright-surface` (no branch switch,
no commits, no stash). Method held exactly per `w984ek-probe.md` / `w984ha-probe.md` /
`w984iy-probe.md` / `w984jp-probe.md` / `w984lc-probe.md` (FILE-SWAP baseline: disk
snapshots in `/tmp/w984mb/` via `cp`, one surgical lib mutation at a time, targeted
court run, `cmp`-verified byte-identical restore, post-restore green confirmation).
Compound-leg convention per W984ha/jp/lc applied (M6 below).

Subjects:
- W984ln's readiness guard: `lib/xaas/marketplace/catalog.ex` `validate_packs/1`
  new cond leg + `test/xaas/marketplace/catalog_court_w984kt_test.exs`.
- W984ku's curation court: `test/xaas/library/curation_resource_court_w984ku_test.exs`
  over `lib/xaas/library/curation.ex`.

Gates: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984mb`.
Fresh lane-root compile: EXIT=0. Baselines (before any mutation): kt court + ku court
together 16 passed, EXIT=0.

## Mutation Matrix

| # | Court (subject lane) | Test file | Mutated lib file | Mutation | During | Verdict |
|---|---|---|---|---|---|---|
| M1 | readiness guard (W984ln) | test/xaas/marketplace/catalog_court_w984kt_test.exs | lib/xaas/marketplace/catalog.ex | readiness-shape leg condition forced `false and not (...)` (leg dropped) | EXIT=2, 6/7 passed | **KILLED** (W984ln typed-refusal test fails — raw raise instead of typed `%Error{}`) |
| M2 | readiness guard (W984ln) | same court | lib/xaas/marketplace/catalog.ex | detail atom `[:invalid_readiness]` → `[:bad_readiness]` | EXIT=2, 6/7 passed | **KILLED** (exact detail-tuple pin `{0, [:invalid_readiness], 7}` fails) |
| M3 | readiness guard (W984ln) | same court | lib/xaas/marketplace/catalog.ex | reason atom `:invalid_pack` → `:invalid_catalog` on the readiness leg | EXIT=2, 6/7 passed | **KILLED** (exact `%Error{reason: :invalid_pack}` pattern pin fails) |
| M4 | curation (W984ku) | test/xaas/library/curation_resource_court_w984ku_test.exs | lib/xaas/library/curation.ex | `state` `one_of` widened with `:archived` | EXIT=2, 8/9 passed | **KILLED** (`state one_of rejects undeclared atom` test fails: `:archived` now accepted, no `Invalid`) |
| M5 | curation (W984ku) | same court | lib/xaas/library/curation.ex | read policy `authorize_if(always())` → `forbid_if(always())` | EXIT=2, 5/9 passed | **KILLED** (all guest-read tests RED — read pin is genuinely load-bearing) |
| M6 | curation (W984ku) | same court | lib/xaas/library/curation.ex | mutation-floor `authorize_if(actor_present())` → `authorize_if(always())` | ku alone EXIT=0, 9 passed → **SURVIVED**; with sibling `test/xaas/library/curation_test.exs` EXIT=2, 16/19 | **SURVIVED single, KILLED as compound** (sibling court's nil-actor mutation-floor tests go RED) |

## Standing Verdicts

- M1 readiness-shape leg: **NON-VACUOUS** — dropping it reintroduces the exact raw
  Ash.Error.Invalid raise the W984ln repair eliminated; the court goes RED on the
  repair-pinning test.
- M2 detail atom / M3 reason atom: **NON-VACUOUS** — the court pins the typed error's
  full shape (reason AND detail), not just "some error"; both single-atom swaps are
  observed and killed by exact pattern pins.
- M4 `state` one_of: **NON-VACUOUS** — the one_of constraint alone refuses the
  out-of-family atom with the pinned `Invalid`; no masking pair here (unlike W984lc's
  M3a tier pair).
- M5 guest-read `always()`: **NON-VACUOUS** — the positive guest-browse allowance is
  genuinely asserted, not just named.
- M6 mutation-floor `actor_present()`: **SURVIVED single, KILLED as compound** — the
  W984ku court deliberately does not cover the nil-actor mutation floor (its moduledoc
  says the sibling `curation_test.exs` owns it), so the floor guard is invisible to
  the ku court alone and only the pair of courts is load-bearing. Fourth instance of
  the W984ha/jp/lc masked/redundant-leg finding — this time at the COURT-partition
  level rather than the constraint level: two courts over one resource jointly pin a
  branch neither owns alone. Kill observed as 16/19 with the sibling's nil-actor
  create/update/destroy refusal tests failing.

5/6 single mutants killed; the 1 survivor (M6) killed by its compound leg (sibling
court). Every kill was an exact typed/value assertion — no crash-only kills.

## Tree Cleanliness

Every restore `cmp`-verified byte-identical to the pre-mutation working-tree snapshot
(`/tmp/w984mb/`). Final on-disk state: `lib/xaas/marketplace/catalog.ex` remains `M`
exactly as at lane start — that delta is W984ln's own uncommitted readiness repair
(16 insertions / 4 deletions vs HEAD, verified via `git diff` to be the W984bo-family
cond-leg rewrite), which my snapshots and every restore preserve byte-identically
(`SNAPSHOT_MATCHES_DISK` verified before first mutation). `lib/xaas/library/curation.ex`
is clean vs HEAD. The two court test files are untracked (`??`) exactly as at lane
start (their lanes' uncommitted work). No commit made. Final green sweep: 16 passed,
EXIT=0.

Standing: **ALIVE** — non-vacuity observed on exact subjects (W984ln readiness guard +
W984kt court, W984ku curation court) on branch feat/playwright-surface, this lane.

## Replay

```bash
cd /Users/sac/xaas
export PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984mb
# baseline both courts (16 passed, exit 0)
# apply one mutation from the matrix, run the paired court, expect RED
# restore from snapshot (cp), cmp-verify byte-identical, court returns EXIT=0
```

## Cleanup

`rm -rf _build-laneW984mb` SUCCEEDED (exit 0, directory confirmed absent). No lane
lease remains.
