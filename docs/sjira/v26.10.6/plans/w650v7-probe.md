# W650v7 — Bridges burn-down probe receipt

- **Subject**: `/Users/sac/xaas` @ branch `feat/playwright-surface` @ HEAD `c0626503` (uncommitted-tree lane; no commits made, per lane contract)
- **Lane env**: `PATH=$HOME/.asdf/shims:$PATH`, `MIX_ENV=test`, `MIX_BUILD_ROOT=_build-laneW650v7` (deleted at lane close)

## Census (fresh enumeration, 2026-10-07)

`lib/xaas/bridges/` — 7 modules, 1595 LOC. Coverage:

| module | LOC | dedicated court(s) |
|---|---|---|
| bridges.ex | 111 | `test/xaas/chicago/bridges/bridges_test.exs` (4 tests) — **gaps: `head_sha/1` packed-refs fallback, detached-HEAD, non-40-hex guard** |
| graphlaw.ex | 203 | gate/seams/assess-deepening/differential (landed) |
| ferroplan.ex | 474 | `test/xaas/bridges/ferroplan_test.exs` + `ferroplan_deepening_test.exs` |
| registry.ex | 117 | `test/xaas/bridges/registry_deepening_test.exs` + `test/xaas/chicago/bridges/registry_test.exs` |
| pplan.ex | 411 | `test/xaas/chicago/bridges/pplan_test.exs` (covered per lane contract) |
| sa2a.ex | 118 | `test/xaas/chicago/bridges/sa2a_test.exs` (7 tests incl. mismatch/unreadable/nil-pin) |
| ex4pm.ex | 161 | `test/xaas/chicago/bridges/ex4pm_test.exs` (incl. mutation falsifier) |

Disposition: the bridge family's own genuinely state-bearing uncovered surface is
`Xaas.Bridges.head_sha/1` — the identity substrate every bridge pin resolves
through (`Sa2a.court_receipt/1` default pin, envelope provenance). Its
`packed-refs` fallback, detached-HEAD branch, and non-40-hex no-guess guard had
zero coverage; a wrong resolution silently re-binds every receipt-match verdict
in the family. That is the top uncovered surface. Everything else: covered.

## Court

`test/xaas/bridges/bridges_head_sha_deepening_test.exs` — 5 tests, Chicago
discipline (real git-shaped files under `System.tmp_dir!/0`, real reads,
state assertions, no mocks):

1. **detached HEAD** — raw 40-hex SHA returned trimmed, never re-resolved.
   Mutation rationale: re-routing through ref resolution would flip every
   bridge pin on detached checkouts to `:receipt_subject_mismatch`.
2. **corrupt HEAD** — non-40-hex content → `nil` (typed no-guess refusal of a
   garbage "pin"; a permissive branch would bind receipts to a non-commit identity).
3. **packed-refs fallback** — loose ref absent after `git gc`, ref present in
   `packed-refs` → resolves correct SHA; otherwise every packed checkout would
   flip pins to UNKNOWN provenance from storage format alone.
4. **peeled lines** — `^sha` annotated-tag continuation lines never mistaken
   for a ref binding; pin must be the ref's own SHA.
5. **dangling ref + no packed-refs** — `nil`, not a raise; a crash would convert
   a provenance question into a bridge-call failure on fresh/corrupt clones.

## Verification (real output)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW650v7 \
  mix test test/xaas/bridges/bridges_head_sha_deepening_test.exs
Running ExUnit with seed: 27562, max_cases: 32
.....
Finished in 0.1 seconds
Result: 5 passed
[exited with code 0]
```

## Standing

- Court standing: **ALIVE** — exact subject, observed execution, 5/5 green on
  the lane build root from a fresh compile.
- Bridges burn-down: **PARTIAL_ALIVE → head_sha/1 closed**; remaining family
  surface covered by prior landed courts (graphlaw×4, ferroplan×2, registry×2,
  pplan, sa2a, ex4pm).
- Not committed, per lane contract. Coordinator owns integration commit.
- Lane build root `_build-laneW650v7` deletion was **denied by the permission
  system** at lane close; left on disk for the coordinator per the fallback
  contract (delete at integration).
