# v26.10.7 Fleet Seal — Integration Runbook

> **Status**: this is the v26.10.7 campaign's runbook seed (the Conventions
> section below carries the sweep-lanes rule). The consolidated v26.10.6
> campaign runbook remains at `docs/sjira/v26.10.6/_INTEGRATION_RUNBOOK.md`.

## Conventions

Sweep lanes: campaign-versioned receipt dirs — v26.10.6 lanes write to `docs/sjira/v26.10.6/plans` even during later seals; enumerate all `docs/sjira/*/plans/` dirs (W650g3 wrong-dir miss, corrected by W650g4).

Lane-lease cleanup: osx-clnr classifier r6 (7b12d2e) nominates stale `_build-lane*`/`target-lane*` roots per-candidate (dir-mtime gate); live lanes suppressed. Future sweeps: run the oclnr CLI audit directly (the session MCP may serve a stale build). Cites: `plans/w651d-gate-fix.md` (fix), `plans/w651c2-gate-falsifier.md` (motivating refutation), `plans/w651b-audit-retest.md` (31-root witness).

Classifier revision: CLASSIFIER_REVISION bumped 3→4→5→6 across the day's fixes (W651/W651c/W651d); old scan caches (`scan-rN-` prefixes) are invalidated per revision — stale caches self-invalidate, no manual sweep needed. Cites: `plans/w651-osxclnr-classifier.md`, `plans/w651c-fs-gate.md`, `plans/w651d-gate-fix.md`, `plans/w651e-gate-fix-note.md`.

## Landing addendum — 2026-10-07 (lane W984ef)

Verified per-commit on `feat/playwright-surface` (`git log --oneline -25`, `git show --stat`,
grep of receipt docs for exact SHAs). Each landing: SHA, paths, court result, receipt path.

| SHA | Landing | Paths | Court result | Receipt |
|---|---|---|---|---|
| `f0321df2` | W984dq6 SpgGate integration (F2 guard + single-funnel seam) | `lib/xaas/actuation.ex`, `lib/xaas/actuation/spg_gate.ex`, `test/xaas/actuation/spg_gate_test.exs`, `test/xaas/actuation/spg_integration_test.exs` | integration court 7 cases green, ×2 fresh roots | `docs/sjira/v26.10.6/plans/w984dq6-spg-execute.md`; commit receipt `docs/sjira/v26.10.7/plans/w650h22-commit.md` |
| `ee6c18bc` | W650h22 commit receipt for the SpgGate landing | `docs/sjira/v26.10.7/plans/w650h22-commit.md` | docs-only | same file |
| `34fc8a53` | W650h33 vkg query_depth court (W984de, unreceipted-owner) | `test/xaas/semantics/vkg/query_depth_test.exs` (+158) | landed; owner receipt flagged below | `docs/sjira/v26.10.7/plans/w650h33b-commit.md` (git-state verdict corrected by `d51119c5`) |
| `0b1b70fc` + `d51119c5` | W650h33b vkg query_depth court receipt (5 tests) + git-state correction | `docs/sjira/v26.10.7/plans/w650h33b-commit.md` | 5 tests, court green | `docs/sjira/v26.10.7/plans/w650h33b-commit.md` |
| `5cf56c13` | W984ds2b completed-lane courts W984ds + W650za (batch) | `docs/sjira/v26.10.6/plans/w650za-probe.md`, `docs/sjira/v26.10.6/plans/w984ds-probe.md`, `test/xaas/ultracode/w650za_incident_lifecycle_guard_court_test.exs`, `test/xaas/ultracode/validations_court_w984ds_test.exs` | 10 green | `docs/sjira/v26.10.7/plans/w984ds2b-commit.md` |
| `b75918a5` + `f2d30813` | W984ds2b lane commit receipt + cleanup-wording correction (`rm` denied; build root moved to `/tmp`) | `docs/sjira/v26.10.7/plans/w984ds2b-commit.md` | docs-only | same file |
| `32b72c4f` | W650h10 repaired causal_receipt process_receipt_depth court | `test/xaas/causal_receipt/process_receipt_depth_test.exs` (+153), `docs/sjira/v26.10.6/plans/w650h10-owner-defect.md` | 5 passed, 0 failed; standing ALIVE on exact subject | `docs/sjira/v26.10.7/plans/w650h33c-commit.md` (cites `32b72c4f` full SHA) |

### Open items (disclosed, not landed this wave)

- **Idempotency-deepening 3F** — W650h23 in flight; landing pending.
- **W984de owner receipt** — the `34fc8a53` vkg query_depth court landed with an
  unreceipted owner (flagged in the landing commit subject and in
  `plans/w650h33b-commit.md`); owner receipt still UNSUPPORTED/open.
