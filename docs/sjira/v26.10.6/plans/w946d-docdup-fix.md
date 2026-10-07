# W946d — dataset_admission.ex duplicate `@doc` fix (W946 strict-compile finding 1)

- **Subject**: repo /Users/sac/xaas, branch feat/playwright-surface @ abbfcb1c (uncommitted working-tree fix, per lane contract: no commit)
- **File**: `lib/xaas/semantics/dataset_admission.ex` (only file written in lib/)
- **Standing**: ALIVE (compile EXIT=0 under `--warnings-as-errors`; test file green ×2)

## Defect (before)

W946 strict-compile gate, receipt `docs/sjira/v26.10.6/plans/w946-postcommit-gate-2.md` finding 1:
`lib/xaas/semantics/dataset_admission.ex:137`
redefined `@doc` (previously set on line 132) — two consecutive `@doc """..."""` blocks on
`sliced_w1/3`. First block = original doc; second = W865 overflow-closure doc.

## Change (after)

Removed the first (original, superseded) `@doc` block (former lines 132–136), keeping the
W865-enriched block (overflow-closure semantics) as the single `@doc` on `sliced_w1/3`.
`@spec` and function body untouched. Pure documentation-attribute fix; no behavioral diff.

## Mutation rationale

Reverting the edit restores two `@doc` blocks on `sliced_w1/3`; the compiler emits
"redefining @doc" and `--warnings-as-errors` fails strict compile — the exact gate failure
W946 recorded.

## Verification (real output)

```
# 1. compile (fresh lane build root, full dep compile)
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW946d \
  mix compile --force --warnings-as-errors
EXIT=0

# 2. dataset_admission tests, x2
mix test test/xaas/semantics/dataset_admission_test.exs
run 1: EXIT=0, Result: 9 passed
run 2: EXIT=0, Result: 9 passed
```

## Transport failures

None. Note: coordinator `rm -rf _build-laneW946d` was permission-denied in this lane;
the lane build root `_build-laneW946d/` remains on disk for coordinator deletion at
integration (same-checkout fanout cleanup law).

## Scope

Finding 1 only. Finding 2 (operator-row-coupled `purge_expired`) and finding 3 (dep-side)
remain open, out of lane scope.
