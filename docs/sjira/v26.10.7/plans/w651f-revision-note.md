# W651f — Classifier-Revision Convention Note

Lane: W651f (v26.10.7 fleet seal). Date: 2026-10-07.

## Task

Add the missing companion line to the Conventions section of
`docs/sjira/v26.10.7/_INTEGRATION_RUNBOOK.md`: CLASSIFIER_REVISION 3→4→5→6
across the day's fixes, with per-revision scan-cache invalidation
(`scan-rN-` prefixes), no manual sweep needed.

## Check performed

Grepped the runbook for `CLASSIFIER_REVISION` and read the Conventions
section: W651e's entry (`Lane-lease cleanup`, classifier r6) does not cover
the revision-bump/cache-invalidation line — genuinely missing.

## Change

Appended one paragraph to `## Conventions` (after the W651e lane-lease
paragraph), ≤2 lines, citing w651/w651c/w651d/w651e receipts (all verified
present in `docs/sjira/v26.10.7/plans/`).

## Final Conventions section content

> ## Conventions
>
> Sweep lanes: campaign-versioned receipt dirs — v26.10.6 lanes write to
> `docs/sjira/v26.10.6/plans` even during later seals; enumerate all
> `docs/sjira/*/plans/` dirs (W650g3 wrong-dir miss, corrected by W650g4).
>
> Lane-lease cleanup: osx-clnr classifier r6 (7b12d2e) nominates stale
> `_build-lane*`/`target-lane*` roots per-candidate (dir-mtime gate); live
> lanes suppressed. Future sweeps: run the oclnr CLI audit directly (the
> session MCP may serve a stale build). Cites: `plans/w651d-gate-fix.md`
> (fix), `plans/w651c2-gate-falsifier.md` (motivating refutation),
> `plans/w651b-audit-retest.md` (31-root witness).
>
> Classifier revision: CLASSIFIER_REVISION bumped 3→4→5→6 across the day's
> fixes (W651/W651c/W651d); old scan caches (`scan-rN-` prefixes) are
> invalidated per revision — stale caches self-invalidate, no manual sweep
> needed. Cites: `plans/w651-osxclnr-classifier.md`,
> `plans/w651c-fs-gate.md`, `plans/w651d-gate-fix.md`,
> `plans/w651e-gate-fix-note.md`.

## Standing

- ALIVE (docs-only edit; file on disk updated, no commit per lane contract).
- No mix commands run (per lane contract).
- Falsifier: `grep CLASSIFIER_REVISION docs/sjira/v26.10.7/_INTEGRATION_RUNBOOK.md`
  returns the appended line.
