# W961c — Actuation refusal-negative test: stale wrapped-error shape fix

Standing: **ALIVE** — file green ×2 (7 passed, exit 0 both), mutation
(reverting the expectation to the old wrapped shape) fails 1/7 against the
landed contract, restored and re-verified green.

## Exact subject

- Repo `/Users/sac/xaas`, branch `feat/playwright-surface`, tree state at
  lane start: HEAD `fab56ae1` (dirty shared tree, sibling lanes landed).
- Toolchain: asdf elixir 1.20.2-otp-28 (`PATH=$HOME/.asdf/shims:$PATH`),
  `MIX_ENV=test`, `MIX_BUILD_ROOT=_build-laneW961c` (left for coordinator —
  rm denied, see Cleanup).
- File changed (test-side only, no lib code touched):
  `test/xaas/actuation_refusal_negative_test.exs` — the
  `:subject_id_required` test only.

## Before / After

**Before** (stale): the test pinned the pre-W773 rollback shape —
`{:error, {:reactor_failed, %Reactor.Error.Invalid{errors: [...]}}}` with a
deep structural match on `RunStepError → Ash.Error.Invalid →
InvalidAttribute(field: :error, value: "subject_id_required")`, plus the
now-false invariant that the rollback left NO intent row for the refused key.

**After** (landed shape): `{:error, :subject_id_required}` — the raw atom
surfaced by W773's seal-boundary normalization (`Xaas.Actuation.Kernel.seal/2`,
`lib/xaas/actuation.ex`): the DO step's `{:error, :subject_id_required}`
(from `get_subject/5`) seals a real `:failed` receipt via `sealed_error/1`
instead of rolling back. Invariant preserved and strengthened: subject row
untouched (`status` + `updated_at` byte-identical), AND the refused key now
leaves a durable refusal record — intent `:failed`, receipt `:failed` with a
map `error` and empty `result`. Mirrors W953's axiom-A fix
(`test/xaas/semantics/authority_decoupling_test.exs:176`), cited in a
comment.

## Verification (real tails)

```
# Run 1 (first green)
Result: 7 passed                    # EXIT=0
# Run 2 (second green)
Result: 7 passed
# Mutation (expectation reverted to old wrapped shape)
Result: 6/7 passed  — 1 failure, "match (=) failed ... :reactor_failed"
# Post-restore confirm
Result: 7 passed
```

Mutation rationale: the reverted expectation fails against the landed
`Kernel.seal/2` contract, proving the test now pins the real shape and is
non-vacuous. All runs under `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW961c
INTERNAL_API_TOKEN=test-token`.

## Falsifier

The mutation run above is the falsifier: reverting the expectation → red
against the landed contract.

## Cleanup

`rm -rf _build-laneW961c` was DENIED in this lane (same class as W953's
denied rm). `_build-laneW961c` is left in place for coordinator cleanup per
the lane-lease law fallback.

## Standing

ALIVE (lane-local, exact subject above). Residual: coordinator-owned full
depth-combine rerun on a quiescent tree (same residual as W953).
