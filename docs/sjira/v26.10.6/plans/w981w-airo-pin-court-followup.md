# W981w — AIRo Pin-Drift Check (Pin-Court Follow-up) — Receipt

- **Lane**: W981w, xaas v26.10.6 campaign
- **Date**: 2026-10-07
- **Subject**: /Users/sac/xaas, uncommitted work tree (no commit per lane order)
- **Complement to**: W981j (`test/xaas/airo/airo_pin_court_test.exs`, present on
  disk — not duplicated; this lane adds the drift dimension only)
- **Deliverables**:
  - `docs/airo/pin_drift_check.exs` — standalone Elixir script, no repo code
    deps (System.cmd git only, hand-rolled JSON encoder since Jason is
    unavailable in bare `elixir` scripts)
  - `test/xaas/airo/pin_drift_test.exs` — ExUnit wrapper, 3 tests
- **Standing**: ALIVE (executed twice on the exact subject, 3/3 ExUnit both runs)

## Contract

For each SHA-bearing row in `docs/cro/artifacts/airo-wiring-ledger.md`
(21 rows parse: 12 fleet table incl. the beam4pm vendor submodule, 3 W981e,
6 W981f), the script runs `git -C ~/<repo> rev-parse HEAD` and
`git merge-base --is-ancestor <recorded> HEAD`:

- CURRENT = recorded == HEAD; ANCESTOR = recorded fast-forwarded;
  DRIFT = recorded not an ancestor (history diverged); MISSING = repo absent.
- DRIFT is reported per-row, not failed. The ExUnit court asserts the drift
  table matches reality: any DRIFT row must equal `@receipted_drift`
  (old→new recorded in this receipt); new/vanished/changed drift fails the
  test and forces a receipt update.

## Per-repo result (both runs identical)

| repo | recorded (pin) | HEAD (2026-10-07) | status |
|---|---|---|---|
| ggen-marketplace | b58d7854142b… | b58d7854142b… | CURRENT |
| ggen | ba837d743736… | ba837d743736… | CURRENT |
| beam4pm | 560202484f5f… | 7312ffcd43f2… | ANCESTOR |
| beam4pm/vendor/ggen-marketplace | 6e4de9765e36… | 6e9344140668… | **DRIFT** |
| ash_surface | b70da9e1c2f5… | b70da9e1c2f5… | CURRENT |
| gymact | 2fa947cb71f9… | 2fa947cb71f9… | CURRENT |
| autofde-lab | 31e3decfbbbd… | 31e3decfbbbd… | CURRENT |
| wasm4pm | d980a2a29413… | d980a2a29413… | CURRENT |
| zcode-cli | 1e40596c6ce7… | 1e40596c6ce7… | CURRENT |
| ex4pm | abac0d23e2a5… | abac0d23e2a5… | CURRENT |
| ash_pplan | 343e52aebf29… | 343e52aebf29… | CURRENT |
| ferroplan | e2c48d339c… | e2c48d339c… | CURRENT |
| ash_graphlaw | 1d89ba5f9a56… | 1d89ba5f9a56… | CURRENT |
| ggen-ecosystem | 7e107f18c43b… | 7e107f18c43b… | CURRENT |
| chatman-ecosystem | 83ceef8a862a… | 83ceef8a862a… | CURRENT |
| ash_atlassian | 43e3d21b7c4e… | 43e3d21b7c4e… | CURRENT |
| ash_dspy | 5d985d5332e8… | 5d985d5332e8… | CURRENT |
| ash_kudzu | 2d600ffd4a67… | 2d600ffd4a67… | CURRENT |
| ash_planning_center | 5ee26cbdc8fe… | 5ee26cbdc8fe… | CURRENT |
| ash_expo | 59a80d5e9a18… | 59a80d5e9a18… | CURRENT |
| ash_autofde | 65cd05e1bd88… | 65cd05e1bd88… | CURRENT |

Counts: 19 CURRENT / 1 ANCESTOR / **1 DRIFT** / 0 MISSING, of 21 rows.
(The ledger's headline "25 repos" includes ash_a2a, ash_r2rml, ggen_igniter,
ash_affidavit, whose text rows record no checkable SHA — excluded, not drifted.)

## Drift table (reality, receipted)

| repo | recorded (old) | HEAD (new) | nature |
|---|---|---|---|
| beam4pm/vendor/ggen-marketplace (submodule) | `6e4de9765e36392c09539afb1464e1eae4f9b2d8` | `6e93441406684f6270a90c7f44660cbadbe0500d` | submodule moved; recorded SHA not an ancestor of submodule HEAD (history diverged — likely force-push or rebase of the submodule branch) |

One drift row. Same value in `@receipted_drift` in
`test/xaas/airo/pin_drift_test.exs`; any change to the drift set fails the
court until both are updated.

## Commands / exits (both runs)

1. `PATH=$HOME/.asdf/shims:$PATH elixir docs/airo/pin_drift_check.exs` →
   exit 0; JSON counts `{current: 19, ancestor: 1, drift: 1, missing: 0}`
   (run 1 and run 2 identical).
2. `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/airo/pin_drift_test.exs`
   → run 1: `Result: 3 passed` (2.0s); run 2: `Result: 3 passed` (2.5s).

## Transport failures (disclosed, session-resolved)

- Initial script bugs (found and fixed in-lane): `Enum.find` returned the raw
  cell with backticks instead of the captured group (all 21 rows misread as
  DRIFT — the negative case was witnessed before the fix); Jason unavailable
  in bare scripts → hand-rolled encoder.
- Run-2 compile aborts on shared `lib/` files owned by other lanes
  (`lib/xaas/ocel/event.ex`, then `lib/xaas/security/finding.ex`) — compile
  freeze by other lanes, not this lane's files; resolved by waiting and
  retrying (per compile-freeze SLA), final run 3/3 green.
- Ancestor nuance: beam4pm's recorded SHA is an ancestor of its moved HEAD —
  fast-forward, not drift, exactly the semantics ordered.

## Falsifiers

- Court: run
  `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/airo/pin_drift_test.exs`.
  Introduce a new drift (e.g. reset any ledger repo to an unrelated SHA) →
  `unreported drift` failure naming the repo; resolve the beam4pm submodule
  drift (update ledger+receipt) without updating `@receipted_drift` →
  `stale receipt` failure.
- Script negative case witnessed in-lane: the pre-fix backtick bug reported
  21/21 DRIFT, confirming rows are actually compared, not vacuously CURRENT.

## Replay

`git -C /Users/sac/xaas` work tree at receipt time, branch `feat/playwright-surface`;
files: `docs/airo/pin_drift_check.exs`, `test/xaas/airo/pin_drift_test.exs`,
this receipt. Script is dep-free; replay = the two commands above from the
repo root with any Elixir ≥ 1.14 + git.

## Carry-forwards

1. beam4pm's `vendor/ggen-marketplace` gitlink diverged from the ledgered
   `6e4de976…`; integration/coordinator should re-pin or investigate the
   submodule history rewrite.
2. 4 ledger repos (ash_a2a, ash_r2rml, ggen_igniter, ash_affidavit) have no
   recorded SHA in the ledger; a future extension could add their rows so the
   court covers all 25.

## W984gt addendum (2026-10-07) — drift row resolved, court map emptied

The single DRIFT row above is RESOLVED: lane W980b lawfully rebased the
ledger submodule pin to `6e934414…` (equivalence verified per w982h), so
`pin_drift_check.exs` now reports `drift=0` (5 CURRENT / 16 ANCESTOR / 21 rows).
Per the receipt contract, `@receipted_drift` in
`test/xaas/airo/pin_drift_test.exs` is emptied to match reality. Re-add
entries only from real `pin_drift_check.exs` output.
