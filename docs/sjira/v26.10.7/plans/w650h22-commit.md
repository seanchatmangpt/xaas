# W650h22 — Commit Receipt (W984dq6 SpgGate integration landing)

Lane W650h22, v26.10.7 fleet seal, repo `/Users/sac/xaas`, branch
`feat/playwright-surface`.

## Subject

Commit `f0321df22498503f7afe624f01b0632e79b8fd58` (short `f0321df2`),
pushed fast-forward `c0626503..f0321df2` to
`origin/feat/playwright-surface` (fetch-first verified: origin was at
`c0626503` == HEAD~1 at push time).

## Paths staged (explicit pathspec, exactly five)

- `lib/xaas/actuation/spg_gate.ex` — F2 fingerprint guard
  (`fingerprint_token/1` head; exact refusal
  `{:error, :spg_fingerprint_atom_keyed}`; never raises).
- `lib/xaas/actuation.ex` — seam `admit_spg/1` inside
  `Kernel.do_admit/2` (opt-in atom `:spg` key, ordered after
  `admit_authority/2`, no string-key fallback) +
  `unwrap_reactor_error/1` extension surfacing
  `{:spg_gate_refused, reason}` bare to `run/4`.
- `test/xaas/actuation/spg_gate_test.exs` — amended unit court
  (test 5 pins string-keyed input; test 4 atom-keyed determinism
  unchanged).
- `test/xaas/actuation/spg_integration_test.exs` — new 8-case
  integration court (7 work-order cases + 1 bonus
  string-`"spg"`-key fail-closed pin).
- `docs/sjira/v26.10.6/plans/w984dq6-spg-execute.md` — the W984dq6
  execute receipt (staged; NOTE: it lives under `v26.10.6/plans/`,
  not `v26.10.7/plans/` as the dispatch stated — disclosed, staged
  at its actual on-disk path).

## Six-checkbox status (re-verified this session, on disk)

| # | Checkbox | Status | Evidence |
|---|---|---|---|
| 1 | F2 refinement landed | WITNESSED | `spg_gate.ex` on disk; unit court test 5 green |
| 2 | Seam caller in `Kernel.do_admit/2` | WITNESSED | `admit_spg/1` present, after `admit_authority/2`, no string-key fallback |
| 3 | Integration court green | WITNESSED | 8 passed (EXIT=0) this session |
| 4 | Unit court green (amended test 5) | WITNESSED | 5 passed (EXIT=0) this session |
| 5 | `actuation_test.exs` still green | WITNESSED WITH COUNT DRIFT | 5 passed (EXIT=0); task/receipt said "6" — HEAD also has 5 tests (`git show HEAD:...` grep count 5); the "6" figure is stale on both sides, 0 failures is the standing fact |
| 6 | Zero bypass callers | WITNESSED | `grep -rln SpgGate lib/` → exactly `lib/xaas/actuation.ex` + `lib/xaas/actuation/spg_gate.ex` |

## Gates (this lane's own runs, `MIX_BUILD_ROOT=_build-laneW650h22`)

- Fresh root `mix compile --force`: EXIT=0, "Generated xaas app"
  (pre-existing warnings only, e.g.
  `refusal_ledger_export.ex:388 assert_all_pinned`).
- One batch, 3 real files, EXIT=0, **18 passed, 0 failures**:
  spg_integration 8, spg_gate 5, actuation_test 5
  (per-file counts re-witnessed individually).
- Boundary-suite leg ("if quick"):
  `test/xaas/actuation/run_idempotency_deepening_test.exs` →
  **7/10 passed, 3 failures, real exit 2**. This file is OUTSIDE this
  lane's pathspec, unmodified in the working tree
  (`git status` clean for it). Failure shape: after deliberately
  refused actuations (missing idempotency key, delegated-without-
  authority, malformed intent), an `ActuationIntent` row persists when
  the court asserts `== []`. Refusal atoms involved are not spg-gate
  atoms; the seam is opt-in on the `:spg` key which these cases do not
  pass. Classified: pre-existing / other-lane surface, NOT gated by
  this lane, handed back to the coordinator as an open finding
  (`w650h22-finding: idempotency-deepening 3F`). The named
  `run_idempotency_test.exs` in the dispatch does not exist on disk
  (only the deepening variant).

## Replay

```
git checkout f0321df2
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-replay \
  mix compile --force
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-replay \
  mix test test/xaas/actuation/spg_integration_test.exs \
           test/xaas/actuation/spg_gate_test.exs \
           test/xaas/actuation_test.exs
# expect: compile EXIT=0; 18 passed, 0 failures, EXIT=0
```

## Standing

- `Xaas.Actuation.SpgGate` integrated path: **ALIVE** (all six boxes
  witnessed on the exact committed subject's working-tree state;
  compile + courts re-run by this lane, not inherited).
- Commit: LANDED (pushed fast-forward, no force).
- Out-of-pathspec finding open: idempotency-deepening 3F
  (BLOCKED→coordinator).

## Lane lease cleanup

`_build-laneW650h22` deleted at integration; leftover lane-lease
roots `_build-laneW984dq6` and `_build-laneW984dq6b` (left by the
W984dq6 lane per its receipt, deviation 2) deleted by this lane per
the same-checkout fan-out cleanup law. Confirmations in the run log.
