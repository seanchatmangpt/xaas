# W735 — Coupling domain deepening (test-only lane)

- **Subject**: repo `/Users/sac/xaas`, branch `feat/playwright-surface`, HEAD `a0723bf6` (uncommitted; no commit made per lane contract)
- **Standing**: ALIVE (tests executed on the exact subject, real Postgres sandbox, no mocks)
- **New file**: `test/xaas/coupling_deepening_test.exs` (16 tests, hand-written — no generator surface exists for tests)

## What was docketed here

`Xaas.Coupling` / `Xaas.Coupling.Engine` / `Xaas.Coupling.CouplingRun` had only
`test/xaas/coupling/{engine_test,coupling_run_test}.exs`. This lane adds a
deepening suite through both the pure engine and the real Ash `:couple` action:

- **(a) Analytic WLS**: 1-D unequal-weight case (`w_a=0.5`, `w_b=0.125` → z=4.4
  exactly, fractions 0.8/0.2 asserted from the receipt), 2-D independent
  per-coordinate case (z=[3.75, 13.75]), and the same 1-D case through the Ash
  action asserting persisted `z` and `weights`.
- **(b) Box binding**: lower-bound clamp (`-100 → -5`, receipt names
  `:lower`/unconstrained mean), mixed 2-D clamp to `-5.0`/`100.0` on both
  coordinates simultaneously, and the same via the Ash action including
  persisted stringified receipt kinds/bounds.
- **(c) Typed refusals**: `:empty_proposal_set`, `:mismatched_vector_dimensions`
  (with `dims: [2, 1]`), `:mismatched_bound_dimensions`, `:zero_total_weight`
  (infeasible, no div-by-zero), `:box_constraints_infeasible` with the exact
  conflicting coordinate tuple, `:malformed_proposal` (confidence 1.5),
  `:general_affine_constraints_unsupported` (E z = f); through the Ash action:
  `:infeasible` persists with `unsupported_reason`, empty set fails admission
  with a real `Ash.Error.Invalid` on field `:proposals`.
- **(d) Determinism x3**: engine runs over original/reversed/shuffled input
  orders give bit-identical `z`/`weights`/`receipt`; three identical Ash creates
  give bit-identical persisted solved state.

## Verification (real gate)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW735 \
  mix test test/xaas/coupling_deepening_test.exs
# (cold-compile lane build root, ~15 min)
Running ExUnit with seed: 44315, max_cases: 32
................
Finished in 0.6 seconds (0.6s async, 0.00s sync)
Result: 16 passed
```

Rerun after warm build: `Result: 16 passed` (exit 0). Mock gate not run
(no `patch`/`Mock` in the new file — verified by construction; file uses real
module calls and real Ash actions over `Ecto.Adapters.SQL.Sandbox`).

## Notes / typed gaps

- The engine contract has no matrix inversion, so there is no literal
  "singular matrix" input class; the degenerate-input refusals covered are the
  ones the real contract emits (listed above). UNSUPPORTED(n/a) for a singular
  determinant case — the box-only closed-form solver never forms a matrix.
- Pre-existing environmental noise only: PromEx Grafana dashboard-upload
  warnings (`nxdomain`) during test-boot — unrelated, present across the suite.
- `_build-laneW735` NOT deleted: lane `rm -rf` was denied by the permission
  system; left in place for coordinator deletion at integration (lane lease law).
- Not committed: coordinator owns lane commits.
