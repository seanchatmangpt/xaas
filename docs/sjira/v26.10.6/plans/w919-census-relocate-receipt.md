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
- **Replay**: plan is self-contained at `docs/claude/diataxis/reference/w849-census-relocate-plan.md`; the dispatch-named copy W954's operator spec references now exists at `docs/claude/diataxis/reference/w919-census-relocate-plan.md` (added W957, 2026-10-07).
- **Not claimed**: no relocation executed; census section still present in the generated page on disk.
- **Resolution note (W956, 2026-10-07)**: line dispute vs w918 resolved by grep at HEAD — `grep -n "SIBLING generated projections coverage" docs/claude/diataxis/reference/generated-castle-bridge-errc.md` → line **23**; file's last content line is **41**. Exact section bounds: **23-41** (this receipt's original figures; w918's "22-41" is off by one on the start). Numbers may shift ±1 if another lane edits the page — W954's locate-by-H2-text instruction governs.
