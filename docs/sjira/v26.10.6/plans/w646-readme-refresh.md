# W646 — corpus-README falsifier refresh

Lane W646, EU-AI-Act wave, 2026-10-06. Repo `/Users/sac/xaas` @ `feat/playwright-surface`
(one canonical checkout).

## Scope (contract)

Written only:
- `docs/eu_ai_act/corpus-README.md` (append-only "Current status" section)
- `docs/sjira/v26.10.6/plans/w646-readme-refresh.md` (this receipt)

## Change

Appended a `## Current status (W646 refresh, 2026-10-06)` section to
`docs/eu_ai_act/corpus-README.md` immediately before `## See Also`. The original
test-mapping contract text is untouched (append-only, no history rewrite).

Citations added:

| item | receipt (all `test -f` verified) | claim |
|---|---|---|
| Aggregation-4 | `docs/sjira/v26.10.6/plans/w622-euaia-aggregation-4.md` | 1100/1110, exit 2 unexcluded run = exactly the 10 `eu_ai_act_open_gap` failures; typed gap census 10 (was 19 at W605) |
| Aggregation-8 | (none — W645c in flight) | cited as in-flight with explicit no-path note; fail-closed, no unverified path cited |
| Deepening | `w616-deepening.md`, `w623-title-iii-deepening.md`, `w626c-deepening-iv-xiii.md` | evidenced-line deepening, 90+ lines across Titles I–XIII |
| Flips | `w607-349-41-closures.md`, `w625c-art73-flips.md` | Art 3(49)+4.1 and Art 73-family OPEN_GAP→EVIDENCED flips vs W538 incident builder + W625 authority registry |
| Vendored-TTL pin | `w621b-airo-pin.md` | AIRo vendored vocabulary pin test |
| Falsifier-class example | `w636-rpc-repoint.md` | rpc-check repoint (W632 STALE-AUDIT-REFERENCE): stale reference survived inspection, failed a real run |

## Verification (real output)

```
$ python3 -c "import json;d=json.load(open('docs/eu_ai_act/corpus.json'));print(sum(len(a['lines']) for t in d['titles'] for a in t['articles']))"
1068
```

Corpus count unchanged: 1068. Receipt path existence (see session transcript
`test -f` batch): all 7 cited files exist under `docs/sjira/v26.10.6/plans/`;
W645c intentionally uncited.

## Verdict

ALIVE — README refreshed append-only, every cited receipt path verified on disk,
corpus counts re-verified at 1068.
