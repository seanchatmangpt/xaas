# W311 — Combined sjira Final Receipt (v26.10.6 convergence)

## Identity

- **Lane**: W311 (integration), v26.10.6 convergence
- **Subject**: `/Users/sac/xaas` @ `d1db2b03179975213c14663b9dbd86b5ac2a14cf`
  (`d1db2b03` "fix(ash-surface): unblock full-app generation (EA35 namespace plumbing)"),
  branch `feat/playwright-surface`, uncommitted working tree as-is (no fixes, no git ops per order)
- **Command** (verbatim, run 3x):

```bash
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH GGEN_IGNITER_DIR=/Users/sac/ggen_igniter MIX_ENV=test mix test test/xaas/sjira test/sjira
```

## Result — counts verbatim

| run | result | wall |
|---|---|---|
| 1 | `139/140 passed, 4 skipped` — `Failed: 1 test` | 60.9s |
| 2 | `Result: 140 passed, 4 skipped` | 37.0s |
| 3 | `Result: 140 passed, 4 skipped` | 37.0s |

**Standing: ALIVE (converged).** Runs 2 and 3 back-to-back clean on the exact subject;
the run-1 failure was a one-off flake that did not reproduce in two consecutive clean
runs (failure name was not captured in run 1's tail-only output — recorded as a known
unknown, not classified).

## Skip classification (4 skipped — all typed, expected)

All host prerequisites present: `jq` (/opt/homebrew/bin/jq), `python3 + rdflib`,
`~/.claude/dfcm/validate_receipt.py`, `autofde` (~/autofde-lab/.venv/bin/autofde).
The only non-satisfied precondition on this host is the retired compile_prose
machinery:

- `test/sjira/v26_9_23_goal_test.exs` — 4 courts tagged
  `@compile_prose_skip` (lines 434/500/841/861): "needs ggen_igniter mix
  semantic_jira.compile_prose (retired upstream by ggen_igniter@dc27242; the
  v26.9.23 corpus is ALIVE at machinery-bearing ggen_igniter SHAs, e.g. cb399128)"

These are the expected typed `compile_prose` machinery-absent skips (W155/W195 class).
Zero untyped skips.

## Scope

- `test/xaas/sjira/` + `test/sjira/` only. os_mon supervisor-port shutdown lines in
  the tail are normal BEAM teardown noise, not failures.
- Post-W210 vacuity, W139 origin_authority regen, W155/W195 typed skips — combined
  receipt per order. No fixes applied, no git operations performed.
