# W892 — diataxis index cross-check receipt

Lane: W892, v26.10.6 campaign. Subject: `docs/claude/diataxis/README.md` @ branch `feat/playwright-surface`.

## Evidence commands

```bash
cd /Users/sac/xaas/docs/claude/diataxis
find tutorials how-to reference explanation case-studies -name '*.md' | sort
# → 29 files (tutorials 2, how-to 4, reference 9, explanation 14; case-studies/ does NOT exist under diataxis/)
grep -o '`\([a-z-]*/[a-z0-9-]*\.md\|../../[^`]*\.md\)`' README.md | tr -d '\`' | sort -u | while read f; do [ -f "$f" ] || echo "MISSING: $f"; done
# → no MISSING output (all 30 link targets resolve; the 30th is ../../case-studies/next-read/README.md → docs/case-studies/next-read/README.md, confirmed present)
```

## Result

- **Added index lines: none.** Every one of the 29 on-disk diataxis pages (including the wave additions `reference/eu-ai-act-semantics.md` and `reference/standing-vocabulary.md`) already has an index line in README.md.
- **Dangling index lines: none.** All 30 link targets in README.md resolve to existing files.
- Case Studies quadrant: no `case-studies/` dir under diataxis; the README already indexes `docs/case-studies/next-read/README.md` via the correct relative path `../../case-studies/next-read/README.md`.

## Anomalies

- Task premise ("wave added many unindexed pages") was tested and refuted: index is already complete on this branch. No edit to README.md was required; file left untouched.

## Standing

- W892: **ALIVE** — real `find` + grep + per-target `[ -f ]` check executed on the exact working tree; no-op result admitted by evidence above.
