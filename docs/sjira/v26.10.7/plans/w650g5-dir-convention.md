# W650g5 — Receipt: campaign-versioned receipt-dir convention note

- Lane: W650g5 (v26.10.7 fleet seal)
- Repo: /Users/sac/xaas (branch `feat/playwright-surface`, no commit made, per lane constraints)
- Sibling-lane collision, disclosed: on arriving, the runbook already contained
  the exact convention note — landed by sibling lane **W650g5b**
  (`docs/sjira/v26.10.7/plans/w650g5b-dir-convention.md`, untracked on disk at
  write time). No edits made to the runbook by this lane; duplicating the line
  would have double-written the conventions section.
- Note verified on disk (Read of `docs/sjira/v26.10.7/_INTEGRATION_RUNBOOK.md`,
  Conventions section, line 5) — exact text:
  > Sweep lanes: campaign-versioned receipt dirs — v26.10.6 lanes write to `docs/sjira/v26.10.6/plans` even during later seals; enumerate all `docs/sjira/*/plans/` dirs (W650g3 wrong-dir miss, corrected by W650g4).
- Note placement: new "Conventions" section in the v26.10.7 runbook (the
  runbook did not previously exist); the prior runbook with sweep notes is at
  `docs/sjira/v26.10.6/_INTEGRATION_RUNBOOK.md`, which contains no existing
  W650e/W650h2 sweep-notes section to append to (grep confirmed).
- Root cause (per `w650g4-receipt-discrepancy.md`): W650g3 checked only
  `docs/sjira/v26.10.7/plans/` and falsely reported
  `w984dj2-spg-gate.md` absent; it actually lives in
  `docs/sjira/v26.10.6/plans/` (landed in `50638a5e`).
- Standing: **ALIVE** — note on disk and verified by this lane's Read; one
  line, ≤2 lines, cites w650g3/w650g4. Files written by this lane: this
  receipt only. No mix commands run, per lane constraints.
- Falsifier: deleting the Conventions line from
  `docs/sjira/v26.10.7/_INTEGRATION_RUNBOOK.md` (or the file itself) would
  refute the ALIVE standing recorded here.
