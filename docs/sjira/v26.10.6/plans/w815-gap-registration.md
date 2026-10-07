# W815 — open-gap registration in corpus-README (doc-only receipt)

- **Lane**: W815, xaas v26.10.6, branch `feat/playwright-surface`, HEAD
  `a0723bf6`, canonical checkout `/Users/sac/xaas` (shared, live campaign).
- **Task**: per W779's receipt (`w779-opengap-tag.md`), register Art. 49(3) as
  the corpus's single real typed open gap in
  `docs/eu_ai_act/corpus-README.md`, correct any "zero open gaps" claim,
  witness the census-vs-gate delta mechanism, and re-stamp totals.
- **Standing**: ALIVE (doc-only lane; every fact cited from `test -f`-verified
  receipts, real numbers copied verbatim from `w779-opengap-tag.md`).

## Diff (one file)

`docs/eu_ai_act/corpus-README.md` — appended a "Current status (W815 refresh,
2026-10-07)" section, rewriting nothing earlier:

1. **Typed open-gap census: exactly 1 — 49.3** (deployer EU-database
   registration duty, Art. 49(3)); binding, unevidenced, no registration seam
   in this repo — honest refusal shape = the flunk row itself. Generating
   honestly since W779's scope fix (dead `@open_gaps["49.3"]` declaration →
   9 NOT_APPLICABLE + 1 OPEN_GAP row across 10 Art. 49 lines).
2. **"One typed open gap (49.3) + zero others"**, explicitly correcting
   W760's "0 open gaps is real" reading (now marked superseded in-place by
   pointer, earlier sections untouched).
3. **Census-vs-gate delta mechanism witnessed**: 1348 − 1347 = 1 = the real
   open-gap count; table of W779's three real runs copied verbatim.
4. **Totals re-stamped 1347/1348** (was 1200 at W760), with the additive
   decomposition from W779's receipt: +10 this-lane (Art. 49 scope fix),
   +137 other lanes' consolidation waves. Pre-existing F2 failure noted as
   owned by the W540/W623 lane, untouched.

## Facts base (all verified this lane)

- `docs/sjira/v26.10.6/plans/w779-opengap-tag.md` — present (`test -f`), read
  in full; source of the 1-selection/1346-1348 counts, the 49.3 typed content,
  the +10/+137 attribution, and the W760-reading correction.
- `docs/sjira/v26.10.6/plans/w760-gate.md` — present (`test -f`); the
  pre-fix baseline (0 selected / 1200 excluded) it cites.

## No-execution scope note

Doc-only lane by assignment: no test run, no build root, no commit
(coordinator owns commits). Nothing here adds a test or changes a verdict;
all counts are W779's measured outputs, not this lane's runs. The README's
mandatory run-convention section is unchanged.

## Replay

```bash
test -f /Users/sac/xaas/docs/eu_ai_act/corpus-README.md
test -f /Users/sac/xaas/docs/sjira/v26.10.6/plans/w779-opengap-tag.md
grep -n "W815 refresh" /Users/sac/xaas/docs/eu_ai_act/corpus-README.md
grep -n "one typed open gap (49.3) + zero others" /Users/sac/xaas/docs/eu_ai_act/corpus-README.md
```
