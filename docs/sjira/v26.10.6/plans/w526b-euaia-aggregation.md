# W526b — EU AI Act aggregation runner receipt

Lane: W526b (terminal aggregation). Repo: /Users/sac/xaas @ feat/playwright-surface.
Build root: `_build-laneW526b` (private, MIX_BUILD_ROOT). Toolchain: asdf shims prepended to PATH.
Poll budget: 45 min; all six title receipts landed before expiry.

## Per-title receipt status (docs/sjira/v26.10.6/plans/)

| lane | receipt file | title | status |
|---|---|---|---|
| w521 | w521-art5-integration.md | Art.5 integration | landed |
| w522 | w522-title-ii.md | Title II | landed |
| w523 | w523-title-iii.md | Title III | landed |
| w524 | w524-title-iv-v.md | Title IV+V | landed w/ 1 open-gap-tagged test |
| w524b | w524b-audit-chain-integration.md | Art.12 audit-chain integration (adjacent) | landed |
| w525 | w525-title-vi-xiii.md | Title VI-XIII | landed |
| w525b | w525b-title-i.md | Title I | landed |

All six title receipts + w524b landed. None missing.

## Run 1 — compliance gate (open gaps excluded by design)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW526b \
  mix test --include eu_ai_act --exclude eu_ai_act_open_gap test/eu_ai_act/
```

Tail:
```
Finished in 0.7 seconds (0.7s async, 0.00s sync)

Result: 955/965 passed, 107 excluded
Failed: 10 tests
```

**Suite green: NO** — all 10 failures are in `Xaas.EUAIAct.TitleITest`
(`test/eu_ai_act/title_i_test.exs`, w525b lane's surface). Titles II, III, IV+V,
VI-XIII are green (955 passed) with open gaps excluded. Two typed failure classes:

1. **OPEN_GAP tests not tagged `:eu_ai_act_open_gap`** — 6 tests (3.49, 3.49.a,
   3.49.b, 3.49.d, 3.49.c, 4.1) `flunk("OPEN_GAP: ...")` unconditionally with no
   exclusion tag, so `--exclude eu_ai_act_open_gap` cannot skip them. Emit site:
   `test/eu_ai_act/title_i_test.exs:343-344`
   (`code: flunk("OPEN_GAP: " <> unquote(detail))`).
2. **EVIDENCED tests with an implementation API mismatch** — 4 tests (3.29 training
   data, 3.30 validation data, 3.31 validation data set, 3.32 testing data) call
   `Xaas.Semantics.DatasetAdmission.admit/2` with a `:seed` opt the implementation
   does not accept: `KeyError key :seed not found in [required_fields: ["x0"]]` /
   `[projections: 8]` at `lib/xaas/semantics/dataset_admission.ex:65`. This is a
   test-vs-implementation contract mismatch, not a flake (reproduced identically
   across 3 runs).

## Run 2 — honest census (open gaps included)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW526b \
  mix test --include eu_ai_act test/eu_ai_act/
```

Tail:
```
Finished in 0.9 seconds (0.9s async, 0.00s sync)

Result: 995/1072 passed
Failed: 77 tests
```

## Census failure attribution (77 total)

| module | failures | class |
|---|---|---|
| TitleIIIOpenGapsTest | 51 | typed open gaps (flunk-by-design) |
| TitleVIXIIIOpenGapsTest | 15 | typed open gaps |
| TitleIVVTest | 1 | typed open gap (tagged; runs only in census) |
| TitleITest | 10 | REAL failures (6 untagged open-gap flunks + 4 KeyError API mismatches) |

## Open-gap census headline

67 typed open gaps (51 Title III + 15 Title VI-XIII + 1 Title IV/V) surface in the
census run — this is the typed gap inventory the implementation backlog must close.
Additionally, 10 title-I tests are BROKEN-not-typed: 6 open-gap tests missing their
`:eu_ai_act_open_gap` tag (belong in the 67, not separate) and 4 EVIDENCED tests
asserting a `:seed` opt that `Xaas.Semantics.DatasetAdmission.admit/2` does not accept.

## Verdicts

- **EVERY-CORPUS-LINE-TESTED: NO (NOT_MET)** — 77 census failures / 965+107 corpus
  lines are not all EVIDENCED or honestly typed; the 4 `:seed` KeyError tests assert
  an API the implementation does not have (test claims EVIDENCED of nonexistent API).
- **Suite green (open gaps excluded): NO** — 10 title-I failures; 6 are mis-tagged
  (tag fix) and 4 are a test/impl API mismatch on
  `lib/xaas/semantics/dataset_admission.ex:65` (`:seed` opt).
- **Open-gap census headline**: 67 typed open gaps + 10 title-I defects (6 missing
  tags, 4 API mismatches). 995/1072 pass in census; 955/965 pass in gated run.
