# W984dj4 — Ultracode family court: ProcessGroup (real-OS subprocess semantics)

Lane: W984dj4 · Campaign: xaas v26.10.6 · Subject: branch
`feat/playwright-surface`, working tree (uncommitted, shared checkout) ·
Date: 2026-10-07 · No commits made (lane law).

## Files written

- `test/xaas/ultracode/process_group_court_test.exs` (new, 5 tests)
- `docs/sjira/v26.10.6/plans/w984dj4-ultracode.md` (this receipt)

## Census (re-run fresh, CamelCase method per W984cy3's correction)

Word-bounded CamelCase grep over `test/**/*.exs`, excluding this lane's own
file:

- `DurableClose`: 1 referring file (W984cy3's court) — covered.
- `SubstitutionPolicy`: 1 referring file
  (`test/xaas/generation/substitution_policy_depth_test.exs`) — now covered
  (W984cw3's depth test landed since W984cy3's probe; the probe's
  disposition is refreshed: SubstitutionPolicy is **covered**, standing
  moves to that test's court).
- `ProcessGroup`: 0 — the only genuinely uncovered ultracode-family module
  remaining.

Disposition of W984cy3's remaining set: no state-bearing candidate better
than ProcessGroup exists; per the task's fallback clause, ProcessGroup is
courted on its real subprocess behavior, as-real, not typed UNKNOWN.

## Court: `Xaas.Ultracode.ProcessGroup`

Every test drives real `perl` children that `setpgrp(0,0)` — the exact
wrapper shape Dispatch/ZcodePackage spawn — through real `/bin/kill` and
verified against the OS ground truth (`/bin/ps -axo pgid=`) independently
of the module under test. Zero mocks.

Invariants + mutation rationale per test:

1. **TERM reaps a live group**: `kill/2` returns `:ok` and `alive?` goes
   false; port delivers a nonzero exit status (signal-terminated). Kills
   the mutant that returns `:ok` without sending TERM to the group
   (`-#{os_pid}` dropped or mis-targeted at the pid, not the group).
2. **KILL escalation**: a TERM-immune group (`SIG{TERM}='IGNORE'` in the
   wrapper) survives the grace budget and is reaped only by the KILL
   escalation; final `:ok` + gone. Kills the dropped-KILL-branch mutant
   (TERM-only implementations pass test 1 but die here).
3. **Idempotence on a gone group**: out-of-band hard-kill first, then
   `kill/2` on the dead group returns `:ok` (no crash on ESRCH). Kills the
   mutant that propagates kill(2) failure as an error/crash.
4. **alive?/1 truthfulness**: true for a live group, false after out-of-band
   kill, cross-checked against `ps -axo pgid=` both directions. Kills the
   invert/always-true/always-false `alive?` mutants.
5. **Guard on os_pid**: non-positive/non-integer pids raise
   `FunctionClauseError` — a bad pid must never reach `/bin/kill` as a
   signal target (pid 0 would signal the caller's own process group — a
   real hazard). Kills the guard-dropped mutant.
## Verification (real output)

- Run 1: `MIX_BUILD_ROOT=_build-laneW984dj4` (fresh full compile),
  two test-helper repairs (reap/1, hard_reap/1 with subject-independent
  `ps` ground truth) → `Result: 5 passed`.
- Run 2: `MIX_BUILD_ROOT=_build-laneW984dj4-r2` (second fresh root):
  `Result: 5 passed` (fresh full compile, no failures).

## Standing

- `ProcessGroup` group-kill semantics: **ALIVE** (5/5 ×2 fresh roots, real
  OS children, real signals, ps-cross-checked).
- Ultracode family: W984cy3's true uncovered set
  {DurableClose, ProcessGroup, SubstitutionPolicy} is now fully covered →
  family standing **covered / ALIVE-by-constituent-courts**; no
  state-bearing ultracode module remains uncovered.

## Lane hygiene

Build roots `_build-laneW984dj4` (392 MB) and `_build-laneW984dj4-r2` left
for coordinator per lane law.
