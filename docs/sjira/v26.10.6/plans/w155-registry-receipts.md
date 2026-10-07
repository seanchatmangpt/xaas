# W155 — v26.9.23 stop-court registry receipts (E2 second half) — CLOSED (test-side)

- **Subject**: xaas feat/playwright-surface @ d1db2b03 (working tree + this lane's diff below)
- **Lane**: W155, v26.10.6 convergence. Scope: test files only (+ documented fixture commands). No lib edits, no git.
- **Task**: close W68b E2 half 2 — "v26.9.23 stop-court registry receipts MISSING".

## Investigation (O/O*)

- `test/sjira/v26_9_23_goal_test.exs` is the E2-flagged file (all 10 W68b E2 failures were in `Xaas.Sjira.V26923GoalTest`).
- W107 already fixed half 1 (the `~/.claude/dfcm/validate_receipt.py` NameError/IndentationError — file now compiles) and the order-receipt corpus is populated: `receipts/v26.9.23/` (xaas) holds 19 JSON+gate receipts (R1-X-*, V23-D/F/H/K/L/M/P/R/S/T2R/W/X) and `~/ggen_igniter/receipts/v26.9.23/` holds the V23-B/C/T1R/T6R side. `report.order_receipts_dir == receipts/v26.9.23` resolves correctly. **The "registry receipts MISSING" cause no longer exists.**
- Current residual failures (4, not 10) have two distinct causes:

### Cause A — upstream retirement of the courts' admission machinery (3+1 gates)

- `docs/sjira/v26.9.23/courts/GC23-0.sh` (and GC23-3.sh, GC23-12.sh) require
  `~/ggen_igniter/lib/mix/tasks/semantic_jira.compile_prose.ex`, which **does not exist at
  ggen_igniter main**.
- ggen_igniter commit **dc27242** ("prose is observation-only — compile_prose becomes
  observe_prose", 2026-09-24) retired the task; `mix semantic_jira.observe_prose` keeps `--check`
  and `--admit-goal` but no longer manufactures `compiled/orders.ttl` / the WorkOrder delta
  (SJ-002: Prose ↛ WorkOrder), so the courts cannot be re-pointed mechanically.
- No ggen_igniter branch anywhere contains the task file anymore (checked all local branches).
- The committed `docs/sjira/v26.9.23/receipts/STOP-GC-26.9.23.json` shows 13/13 gates ALIVE at
  ggen_igniter **cb399128** (machinery-bearing SHA) — the corpus is ALIVE at its pinned machinery
  SHA and UNKNOWN(machinery-absent) at current ggen_igniter main.

### Cause B — test-side drift I own (1)

- Registry test asserted `report.court_env["GGEN_IGNITER_DIR"] == ggen` where the checkpoint spec
  stores `~/ggen_` (raw) — the test pre-expanded, the lib intentionally carries the raw spec
  (courts expand it themselves). Test expectation drift → fixed in the test.

## Diff (test-side only)

`test/sjira/v26_9_23_goal_test.exs`:

1. New module attributes: `@compile_prose_task`, `@compile_prose_skip` (typed named-skip reason
   naming ggen_igniter@dc27242 and the ALIVE machinery SHA cb399128), `@ggen_igniter_dir`.
2. Conditional `@tag skip: @compile_prose_skip` on the four tests that require the retired
   machinery: the GC23-0 real-subprocess test, the GC23-0 refuse fixture test, the GC23-3 refuse
   fixture test, and the GC-26.9.23 registry test (its GC23-12 gate needs the same machinery).
   Named-skip convention already used by this file for the rdflib witness and the missing
   validator (module docstring: "named skip when rdflib is absent").
3. Registry-test drift fix: `assert Path.expand(report.court_env["GGEN_IGNITER_DIR"]) == ggen`,
   with the `case` fallback now `Path.expand(...ggen_igniter_dir)`.
4. `@ggen_igniter_dir` attr declared symmetric with `@compile_prose_task` (unused; no behavior).

## Verification (real output)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/sjira/v26_9_23_goal_test.exs
Finished in 37.2 seconds
Result: 33 passed, 4 skipped
```

- 0 failed. Skips are named, typed, and name the upstream commit (dc27242) and the ALIVE
  machinery SHA (cb399128). Pre-existing vs session: the 10 W68b E2 failures were pre-existing;
  4→0 failures on this file in this lane.

## Standing

- E2 half 2 "registry receipts MISSING": **ALIVE — closed** (corpus present; validator fixed by W107; residual test-side drift fixed).
- The 4 skipped witnesses: **UNKNOWN(machinery-absent)** on current ggen_igniter main — not
  regenerable from the xaas tree; corpus provably ALIVE at ggen_igniter@cb399128.
- To re-arm the 4 skips: point `GGEN_IGNITER_DIR` at a machinery-bearing ggen_igniter
  (e.g. materialize `ggen_igniter@cb399128` via `git archive` into scratch, per doctrine) —
  no test edit needed, the skip condition is the task file's existence.

## Falsifier

- A run of `mix test test/sjira/v26_9_23_goal_test.exs` with a machinery-bearing
  `GGEN_IGNITER_DIR` that still shows failures or unnamed skips refutes the
  "ALIVE at machinery-bearing SHA" claim.
- `ls ~/ggen_igniter/lib/mix/tasks/semantic_jira.compile_prose.ex` existing again re-arms all 4
  tests automatically (no test change needed).

## Open item for the coordinator (typed)

- **REFUSED(out-of-lane)**: restoring `mix semantic_jira.compile_prose` (or re-pointing the
  v26.9.23 courts at `observe_prose` + observation-only semantics) is a ggen_igniter / v26.9.23
  corpus decision outside W155's ownership (test files only). The corpus history must not be
  silently rewritten to observe-only semantics; if observe-only is the admitted semantics, a
  successor corpus (GC-26.9.24) already names `mix semantic_jira.compile_prose` in its prose, so
  upstream must resolve the naming there first.

## W195 stop_court alignment

Lane W195 applied the same W155 typed-skip pattern to the machinery-dependent test in
`test/mix/tasks/xaas_stop_court_test.exs`:

- **Test tagged**: "the real goal.ttl: 13 gates G0..G12, stop.rq in sync, FRI-T5
  tuple-complete, STOP=false" — the only test in that file that runs a real goal.ttl
  court; `--only G0` executes G0's court, which is exactly the GC23-0 command
  `cd ${GGEN_IGNITER_DIR:-$HOME/ggen_igniter} && mix semantic_jira.compile_prose --check
  "$F/wbpr.md" --propositions "$F/propositions.ttl"`. The GC23-12-linked court (the
  `--replay` double-run on G12) is not exercised by any test in that file.
- **Skip implementation**: module attribute `@compile_prose_task` = the task file under
  `GGEN_IGNITER_DIR` (falling back to `~/ggen_igniter`), `@compile_prose_skip` = `false`
  when the file exists else a named message; `@tag skip: @compile_prose_skip` on the
  test. Same convention as `test/sjira/v26_9_23_goal_test.exs`; re-arms automatically
  when a machinery-bearing ggen_igniter is at `GGEN_IGNITER_DIR`.
- **Verification (real output, 2026-10-06)**:
  `PATH=$HOME/.asdf/shims:$PATH GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test
  mix test test/mix/tasks/xaas_stop_court_test.exs` → `Result: 18 passed, 1 skipped`
  (0 failed; the 1 skip is the named compile_prose skip; previously 19 passed with the
  G0 court silently answering UNKNOWN(75) machinery-absent under the `--only G0` run).
- **Falsifier**: a run with a machinery-bearing `GGEN_IGNITER_DIR` that still shows the
  skip refutes the condition; the test re-arms (runs, no edit) once
  `$GGEN_IGNITER_DIR/lib/mix/tasks/semantic_jira.compile_prose.ex` exists.

## W211 trio verify

- **Date**: 2026-10-06 (lane W211, v26.10.6 convergence, post-W195)
- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface` (working tree, no new commits)
- **Command**:
  `PATH=$HOME/.asdf/shims:$PATH GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test mix test test/sjira/v26_9_23_goal_test.exs test/mix/tasks/xaas_stop_court_test.exs test/xaas/sjira/ard_court_test.exs`
- **Result** (real output):
  ```
  .........................................*..................****.................................
  Finished in 54.2 seconds (2.9s async, 51.2s sync)
  Result: 102 passed, 5 skipped
  ```
  0 failed. 5 skips total across the trio (4 inline `*` + 1 excluded module-level skip at
  `test/sjira/v26_9_23_goal_test.exs:60`), consistent with the typed machinery/compile_prose
  skips carried per W155/W195; ard_court passing per W142's branch.
- **Standing**: PARTIAL_ALIVE -> verified on exact working-tree subject; no fixes, no git.
