# W980c — Census Relocation Execution Receipt

- **Lane**: W980c, xaas v26.10.6 campaign. **Date**: 2026-10-07.
- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface` (working tree, not committed —
  per lane instruction, no commit/push).
- **Task**: steps 1-2 of the W954 sync-gate operator sequence
  (`docs/sjira/v24.10.6`-corrected path: `docs/sjira/v26.10.6/plans/w954-sync-gate-spec.md` §b):
  the pre-sync hand-authored census relocation per
  `docs/claude/diataxis/reference/w919-census-relocate-plan.md`. NOT the pin advance
  (step 3), NOT the sync (step 4).

## μ / diff (three-file + index, all hand-authored)

| File | Change |
|---|---|
| `docs/claude/diataxis/reference/generated-surfaces.md` | **NEW**. H1 `# Generated Surfaces — Provenance and Drift Census`, one-line preamble pointing at the W849 receipt, the full 9-row census table, the "8 DRIFT-CHECKED / 4 PROVENANCE-ONLY / 0 UNPINNED" trailing paragraph, plus a relocation note naming the source page and the artifact home. The census table row formerly reading "this page" now reads `generated-castle-bridge-errc.md` (per w849-plan §b.2). |
| `docs/cro/artifacts/generated-surface-census-v26.10.6.md` | **NEW**. Full 12-row census table (9 surface rows + counts paragraph), provenance header pointing at the W849 receipt and the diataxis page. |
| `docs/claude/diataxis/reference/generated-castle-bridge-errc.md` | Census section deleted (H2 `## SIBLING generated projections coverage (W849 census)` through the trailing counts paragraph; 20 lines removed, page now 22 lines). Per w919-plan §b.3, this deletion is the pre-sync hand move the regen is then expected to confirm stable. |
| `docs/claude/diataxis/README.md` | Added Reference index entry for `reference/generated-surfaces.md` (wording per w919-plan §b.5). |

## Verification (all executed on the live tree, 2026-10-07)

| Gate | Command | Result |
|---|---|---|
| Generated page carries no census | `grep -c "W849 census" docs/claude/diataxis/reference/generated-castle-bridge-errc.md` | **0** (expected 0) |
| Census H2 gone | `grep -c "SIBLING generated projections" …generated-castle-bridge-errc.md` | **0** |
| New page carries census | `grep -c "W849" docs/claude/diataxis/reference/generated-surfaces.md` | **1** (expected >= 1) |
| Artifact carries census | `grep -c "W849" docs/cro/artifacts/generated-surface-census-v26.10.6.md` | **1** (>= 1) |
| README index entry | `grep -c "generated-surfaces.md" docs/claude/diataxis/README.md` | **1** |
| Drift guard green | `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/generated/registry_drift_guard_test.exs` | **1 passed, 0 failed** (pinned toolchain via asdf shims) |

`git diff --stat` on the generated page: 1 file changed, 20 deletions(-), 0 insertions.

## Standing

- The three hand-authored pre-sync moves: **ALIVE** (executed on the live tree with real
  output above; not committed per lane instruction).
- The generated page deletion: **ALIVE as hand-authored pre-step**; final standing for the
  deletion hunk belongs to the operator's step-4 `ggen sync` (the regen must show the
  section stays deleted — per w919-plan §b.3 "the sync confirms stability" — plus the
  predicted line-10 delta from w918). Until the sync runs, the census-section removal
  itself remains a hand-edit of a generated file riding the next regen commit.
- Remaining operator steps (W954 spec §b): step 2 prereq verify (P1), step 3 pin advance,
  step 4 `ggen sync`, step 5 predicted-diff gate, step 6 drift-guard rerun. Not executed
  by this lane.

## Falsifiers for the coordinator

- After the step-4 sync, `grep -c "W849 census" generated-castle-bridge-errc.md` must stay 0.
- Post-sync `git diff` on the generated page must be exactly the predicted two hunks
  (line-10 "Why" cell delta + census-section removal already staged by this relocation).
- `registry_drift_guard_test.exs` re-run post-sync must stay green.
