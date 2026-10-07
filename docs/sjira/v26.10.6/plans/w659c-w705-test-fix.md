# W659c — W705 map_update_dual_safe_test.exs fix lane (receipt)

## Task
Fix two reported test-side defects in W705's `map_update_dual_safe_test.exs`:
1. Census tripwire asserts `lib/xaas/runtime/fond/circuit.ex` exists but the
   real file allegedly lives elsewhere.
2. `Xaas.Gall.Turtle.from_turtle/1` returns `{:refused, :refused_authority}`
   — allegedly a missing authority context.

## Findings (both defects DO NOT REPRODUCE on the current tree)

### Defect 1 — circuit.ex path
Real paths found (both exist on disk):
- `lib/xaas/runtime/fond/circuit.ex` (module `Xaas.Runtime.FOND.Circuit`) —
  this IS the census site, and the tripwire's expected path is CORRECT.
- `lib/xaas/runtime/provider_fabric/circuit.ex` — a second, unrelated
  Circuit; likely the source of the "lives elsewhere" confusion.

The census tripwire (`File.exists?` + per-site `Map.update(` regression
check) passes as written; no path edit was needed.

### Defect 2 — from_turtle refused_authority
`from_turtle/1` takes NO authority context (arity 1, no options). Its
`{:refused, :refused_authority}` comes from `Xaas.Gall.Checkpoint.new/1`
admission and means: a required field missing/nil, a list/map field of the
wrong shape, `identity` not `urn:gall:checkpoint:<repo>:<id>`, or standing
outside the vocabulary (`lib/xaas/gall/checkpoint.ex` refusal table).
The test's TTL matches the module's own canonical form
(`test/xaas/gall/turtle_test.exs @canonical_ttl` — same setup idiom: plain
arity-1 call, no authority supply), and it admits `{:ok, %Xaas.Gall.Checkpoint{}}`
here. No test change was needed; the dual-safe pins are preserved untouched.

## Diffs
NONE. Zero bytes changed in any test or lib file. The only file written is
this receipt.

## Verification (real output, 2 runs)
```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW659c \
  mix test test/xaas/semantics/map_update_dual_safe_test.exs \
           test/xaas/w705_map_update_dual_safe_test.exs
# run 1 (fresh lane build, 926 files compiled): 13 passed, exit 0
# run 2: Result: 13 passed, exit 0
```
Note: the contract named `test/xaas/map_update_dual_safe_test.exs`; the file
on disk is `test/xaas/semantics/map_update_dual_safe_test.exs` (plus W705's
own `test/xaas/w705_map_update_dual_safe_test.exs`). Both run green; both
left untouched per the no-lib-edit / preserve-pins contract.

## Standing
ALIVE for the "no defect" verdict on the exact tree @ feat/playwright-surface
(uncommitted W659/W705 test files as found 2026-10-07). If either defect was
observed on an earlier subject, that subject predates the current dual-safe
lib patches (the residue grep's expected single site
`lib/xaas/ultracode/run_validation.ex:661` matches today).
