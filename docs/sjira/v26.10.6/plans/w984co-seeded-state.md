# W984co — Seed idempotency court (unit surface)

- **Repo / subject**: /Users/sac/xaas @ branch `feat/playwright-surface`, uncommitted working tree
  (head 755b6559; file written fresh, not committed, per lane contract).
- **Lane contract**: tests under test/xaas/ + this receipt only; no commit.
- **Files**: `test/xaas/dev_seeds_idempotency_test.exs` (new, 4 tests). No lib/ or guard changes —
  read fresh post-W984bs: `run/0` is arity-1 (`run(opts \\ [])`) with `e2e: true` opt-in branch
  (lib/xaas/dev_seeds.ex:196, :267-284); court written against that surface.
- **Standing**: ALIVE (all verdicts below from real runs on real Postgres, MIX_ENV=test,
  MIX_BUILD_ROOT=_build-laneW984co, PATH asdf shims).

## Courts (per-test verdicts)

| # | Test | Verdict |
|---|------|---------|
| 1 | `run/0 twice grows row counts by exactly zero (full dedupe per the idempotency contract)` | PASS — replay returns identical row ids across all 7 slots; slot counts identical between run 1 and run 2 (delta 0); every natural-key slot exactly populated (1 org/sub/ledger/pending, 10 books, 1 dev reader, 2 checkouts, 1 curation) |
| 2 | `replayed rows satisfy the real unique constraints` | PASS — 1 org slug, 1 subscription per org_id, 10 books all-unique isbns+titles, exactly 1 dev-reader email row, 1 checkout per (user,book), 1 curation per book |
| 3 | `sandbox rollback of the allowed path leaves zero residue of this run's rows` | PASS — every id run/0 returned is either a pre-existing committed row (reused by idempotent lookup) or absent after `Sandbox.checkin`; before/after id sets equal; fresh replay post-rollback clean |
| 4 | `guard refusal message shape is stable: REFUSED(dev_seeds, env=...)` | PASS — raw spawned unsandboxed caller raises `%Mix.Error{}` matching `~r/REFUSED\(dev_seeds/`, `env=test`, remediation text names `mix run priv/repo/seeds.exs` and `e2e: true`; no table drift after refusal |

## Commands / exits

```
mix test test/xaas/dev_seeds_idempotency_test.exs   # pass 1: 4 passed
mix test test/xaas/dev_seeds_idempotency_test.exs   # pass 2 (fresh): 4 passed
mix test test/xaas/dev_seeds_test.exs test/xaas/dev_seeds_env_guard_test.exs
                                                    # regression: 7 passed
```

Pass 1 first attempt: 2/4 — two real defects found and fixed in this lane's own court (see below).
Final: 4/4, twice. Siblings green. **No pre-existing failures touched.**

## Findings / falsifiers resolved

1. **Count-delta courts are the wrong shape on this DB.** `xaas_test` carries committed seed
   rows (sanctioned `run(e2e: true)` boot path, W984bs — confirmed live: 10 library_books, 1 dev
   reader, 2 checkouts, 1 curation, 1 org committed in xaas_test). Table-wide count deltas
   (baseline+10) fail on an already-seeded test DB, and that failure is the idempotency contract
   *working*, not breaking. Re-shaped courts 1/3 to natural-key slots + before/after id-set diff
   (row either pre-existing-reused or gone-after-rollback; no third state). Recommendation for
   W984bs's e2e seed work: any court asserting count deltas against xaas_test must sample the
   committed baseline or use natural-key slots.
2. **Lane-local bug found by the court itself**: initial helper filtered `library_checkouts` by
   the *org* id; checkouts belong to the dev reader. Fixed (SQL email lookup → user_id filter).

## Coordination notes

- W984bs owns global-setup.cjs + guard — no collision: this lane wrote only the new test file;
  guard behavior asserted read-only (`run(opts \\ [])` arity-1 preserved).
- `_build-laneW984co` removal was denied by the permission system; **left in place for the
  coordinator** per the cleanup law fallback (~1 full test compile of xaas deps).
- Async discipline: `async: false` with the same AshEvents advisory-lock justification as
  `Xaas.DevSeedsTest` (Ledger writes in the seed chain).
