# W919 Receipt — W849 Census Relocation Plan

- **Lane**: W919, xaas v26.10.6 campaign
- **Subject**: planning only; two new docs, no code, no build root, no execution, no commit
- **O**: W918's second finding (census section inside generated page deleted by regen); read of
  `docs/claude/diataxis/reference/generated-castle-bridge-errc.md` (census at lines 23-41) and
  `docs/claude/diataxis/README.md` (index authority rules); `_INTEGRATION_RUNBOOK.md` ggen-sync steps
- **μ/diff (handwritten, 2 files)**:
  - NEW `docs/claude/diataxis/reference/w849-census-relocate-plan.md` — relocation plan (target, steps, guard, ordering)
  - NEW `docs/sjira/v26.10.6/plans/w919-census-relocate-receipt.md` — this receipt
- **Commands/exits**: none executed (plan-only lane). Read-only file reads only.
- **Verification ladder**: not applicable — no executable claim made. Plan contains its own
  falsifiers for the executing coordinator (grep counts + `ggen sync run && git diff --exit-code`).
- **Standing**: PLAN-ONLY / UNKNOWN (execution standing belongs to the coordinator's integration step)
- **Decisions recorded**:
  1. Target: NEW `reference/generated-surfaces.md` (standing-vocabulary.md thematically wrong; README index forbidden by its own no-duplication rule).
  2. Census artifact home: `docs/cro/artifacts/generated-surface-census-v26.10.6.md` per campaign artifact convention.
  3. Deletion from generated page rides the same integration step as `ggen sync`, before the runbook's drift check.
- **Replay**: plan is self-contained at `docs/claude/diataxis/reference/w849-census-relocate-plan.md`.
- **Not claimed**: no relocation executed; census section still present in the generated page on disk.
