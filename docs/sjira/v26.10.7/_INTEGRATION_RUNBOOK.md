# v26.10.7 Fleet Seal — Integration Runbook

> **Status**: this is the v26.10.7 campaign's runbook seed (the Conventions
> section below carries the sweep-lanes rule). The consolidated v26.10.6
> campaign runbook remains at `docs/sjira/v26.10.6/_INTEGRATION_RUNBOOK.md`.

## Conventions

Sweep lanes: campaign-versioned receipt dirs — v26.10.6 lanes write to `docs/sjira/v26.10.6/plans` even during later seals; enumerate all `docs/sjira/*/plans/` dirs (W650g3 wrong-dir miss, corrected by W650g4).

Lane-lease cleanup: osx-clnr classifier r6 (7b12d2e) nominates stale `_build-lane*`/`target-lane*` roots per-candidate (dir-mtime gate); live lanes suppressed. Future sweeps: run the oclnr CLI audit directly (the session MCP may serve a stale build). Cites: `plans/w651d-gate-fix.md` (fix), `plans/w651c2-gate-falsifier.md` (motivating refutation), `plans/w651b-audit-retest.md` (31-root witness).

Classifier revision: CLASSIFIER_REVISION bumped 3→4→5→6 across the day's fixes (W651/W651c/W651d); old scan caches (`scan-rN-` prefixes) are invalidated per revision — stale caches self-invalidate, no manual sweep needed. Cites: `plans/w651-osxclnr-classifier.md`, `plans/w651c-fs-gate.md`, `plans/w651d-gate-fix.md`, `plans/w651e-gate-fix-note.md`.
