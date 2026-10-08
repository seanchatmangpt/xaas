# W984nb — diataxis map verification probe (v26.10.6)

Subject: branch `feat/playwright-surface` (working tree, no commit). Files:
- `/Users/sac/xaas/docs/claude/diataxis/README.md`
- `/Users/sac/xaas/docs/claude/diataxis/reference/w849-census-relocate-plan.md`
- `/Users/sac/xaas/docs/claude/diataxis/reference/w919-census-relocate-plan.md`

## Method (real commands)

- `find docs/claude/diataxis -name '*.md'` → 34 files (incl. README.md).
- Parsed README's relative links and diffed against the tree.
- Link resolution re-verified after edit: `test -e <target>` from the diataxis
  directory for every README link; all resolve (the case-studies link is
  `../../case-studies/next-read/README.md` → exists at
  `docs/case-studies/next-read/README.md`).

## Diff table

| check | result | action |
|---|---|---|
| Listed-but-missing (broken links) | 0 | none needed |
| Present-but-unlisted (orphans) | 2 | added to README "Reference pages not previously indexed" |
| `reference/w849-census-relocate-plan.md` | orphan | added: "PLAN ONLY (not executed): relocation plan for the W849 census section out of the ggen-generated ERRC page." |
| `reference/w919-census-relocate-plan.md` | orphan | added: "PLAN ONLY (not executed): canonical copy of the W919 census-relocation plan at the dispatch-named path." |
| README edit | +2 lines (docs only) | no restructure |

## Standing

Docs-only change verified by real `find` + link existence checks on this
working tree. No commit made, per lane contract.
