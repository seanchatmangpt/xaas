# W957 Receipt — w919 census-relocate plan file created at dispatch-named path

- **Lane**: W957, xaas v26.10.6 campaign
- **Subject**: docs-only fix for W956's finding — W919's relocation plan content landed only at `w849-census-relocate-plan.md`; the dispatch-named `w919-census-relocate-plan.md` did not exist although W954's operator spec references it. No code, no build root, no commit, no execution.
- **O**: W956 finding; `docs/sjira/v26.10.6/plans/w919-census-relocate-receipt.md` (plan summary: target `reference/generated-surfaces.md`, move steps, artifact home `docs/cro/artifacts/generated-surface-census-v26.10.6.md`, ordering vs `ggen sync`); full plan text at `docs/claude/diataxis/reference/w849-census-relocate-plan.md`.
- **μ/diff (handwritten, 2 files)**:
  - NEW `docs/claude/diataxis/reference/w919-census-relocate-plan.md` — the W919 relocation plan (target selection, exact move steps, census artifact home, execution ordering, falsifiers), content copied verbatim from the w849-named plan with a provenance header noting both paths exist and this is the file W954's spec references.
  - MODIFIED `docs/sjira/v26.10.6/plans/w919-census-relocate-receipt.md` — Replay line now cross-references the new dispatch-named plan path (added W957, 2026-10-07).
- **Commands/exits**: none executed (docs-only lane; file reads/writes only).
- **Verification**: both files confirmed written on disk via tool success + receipt edit applied. Not run: falsifiers in the plan (they belong to the executing coordinator).
- **Standing**: PLAN-ONLY fix / docs surface created; relocation itself remains unexecuted (UNKNOWN, same as W919).
- **Replay**: create the two files as described above; plan content is byte-derived from `w849-census-relocate-plan.md` at HEAD (fab56ae1 worktree, 2026-10-07).
- **Not claimed**: the census relocation itself has not been executed; `generated-castle-bridge-errc.md` is untouched by this lane.
