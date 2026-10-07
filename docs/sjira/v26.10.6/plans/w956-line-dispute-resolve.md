# W956 Receipt — W849 Census Section Line-Dispute Resolution

- **Lane**: W956, xaas v26.10.6 campaign; subject = docs-only resolution note, no code, no commit, no build root
- **O**: W954 receipt (`w954-sync-gate-spec.md`) discrepancy note — w918 says census section is generated-page lines 22-41, w919 says 23-41
- **μ/diff (handwritten, 1 edit + this receipt)**:
  - Appended one-line resolution note to `docs/sjira/v26.10.6/plans/w919-census-relocate-receipt.md` (the w919 lane's plan/receipt file; note: task named `w919-census-relocate-plan.md`, which does not exist — the only w919 file on disk is the receipt)
- **Commands/exits** (real, at working tree = HEAD fab56ae1):
  - `grep -n "SIBLING generated projections coverage" docs/claude/diataxis/reference/generated-castle-bridge-errc.md` → `23:## SIBLING generated projections coverage (W849 census)`
  - `wc -l` on the page → 41; line 41 is non-empty content (`regen-and-compare; ontology-source conformance remains an open CI/regen leg (P2-2).`) → section end = 41
- **Resolved facts**: exact bounds of the W849 census section in `docs/claude/diataxis/reference/generated-castle-bridge-errc.md` at HEAD = **lines 23-41** (start 23, end 41 = last content line of the page). w919 was correct; w918's "22-41" is off by one on the start line. Numbers may shift ±1 if another lane edits the page — W954's locate-by-H2-text instruction governs.
- **Verification ladder**: narrow (grep) + direct read of line 41; no executable claim beyond line numbers.
- **Standing**: OBSERVED / verified line numbers as of HEAD fab56ae1; fact is time-of-observation (caveat above).
- **Replay**: rerun the single grep above; expect line 23.
