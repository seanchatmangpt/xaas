# W535 — Title III remaining OPEN_GAP reclassification (Arts 8, 10, 11, 15, 26, 27)

Lane: W535 · Wave: EU-AI-Act Chicago-test wave · Repo: `/Users/sac/xaas` @
`feat/playwright-surface` (HEAD `d1db2b03` at start) · Private build root
`_build-laneW535`.

Contract files (only these were written):

- `test/eu_ai_act/title_iii_test.exs` (Art 8/10/11/15/26/27 entries only; W532
  owns Art 9/13/14 entries in the same file — sequential edits, re-read before
  each write)
- this receipt

## Design

Same generator shape as W523/W534/W532: `Xaas.EUAIAct.TitleIII.Lines` classifies
every Title III corpus line at compile time. W535 adds:

1. **13 new EVIDENCED entries** in the evidence map (Art 8 none; Art 10: 10.2,
   10.2.e, 10.3; Art 11: 11.1; Art 15: 15.1, 15.4.s2, 15.5.s2; Art 26: 26.1,
   26.2, 26.4, 26.5, 26.9, 26.12) — every path verified on disk before the edit
   (18 paths across 7 lib/test files + 6 lane receipts; `ls` exit 0).
2. **A new per-line `not_applicable_map/0`** (23 entries) wired into the cond
   directly after W532's reclass clause: lines the generic corpus rules misfiled
   as OPEN_GAP but which a deployer-class surface honestly disposes of —
   training-data curation (we train no models), product/Annex-I machinery, no
   financial-institution or law-enforcement context, savings/routing clauses,
   Commission-side duties (27.5).

Judgment discipline: deployer-class, per-line, honest. Where the obligation
applies and no seam exists, the line STAYS OPEN_GAP.

## Per-line table (all 50 formerly-OPEN Art 8/10/11/15/26/27 lines)

| line | was | now | basis (deployer-class) |
|---|---|---|---|
| 8.1 | OPEN | OPEN | umbrella compliance duty — satisfied per-line; no independent seam |
| 8.2 | OPEN | NOT_APPLICABLE | Annex I product-integration clause; repo places no AI-containing product on the market |
| 10.1 | OPEN | NOT_APPLICABLE | attaches to model training; this surface trains nothing |
| 10.2 | OPEN | EVIDENCED | governance practice = dataset admission gate (W502) |
| 10.2.a | OPEN | NOT_APPLICABLE | training-dataset design-choices documentation; no training |
| 10.2.b | OPEN | NOT_APPLICABLE | data collection/origin curation; no dataset construction |
| 10.2.c | OPEN | NOT_APPLICABLE | annotation/labelling/cleaning pipeline; none exists |
| 10.2.d | OPEN | NOT_APPLICABLE | assumption formulation for training data; no training |
| 10.2.e | OPEN | EVIDENCED | suitability assessment = completeness gate (W502) |
| 10.2.f/g/h | EVIDENCED | EVIDENCED (unchanged) | W502 bias + completeness gates |
| 10.3 | OPEN | EVIDENCED | representativeness/completeness = W502 gates |
| 10.4 | OPEN | NOT_APPLICABLE | training/validation/testing set characteristics; no training |
| 10.6 | OPEN | NOT_APPLICABLE | scope-routing paragraph, no independent duty; targets adjudicated per-line |
| 11.1 | OPEN | EVIDENCED | up-to-date machine documentation = W503 hash-chained audit receipts + W524b integration over real lane receipts |
| 11.2 | OPEN | NOT_APPLICABLE | Annex I product CE-marking documentation; no product |
| 15.1 | OPEN | EVIDENCED | accuracy/robustness/cyber posture = W508 margin + W509 WASI gate + W503 chain |
| 15.3 | OPEN | OPEN | declared accuracy metrics in instructions of use — no declared-metrics surface |
| 15.4 | EVIDENCED | EVIDENCED (unchanged) | W508 |
| 15.4.s2 | OPEN | EVIDENCED | fail-safe plan = quiescent-stop attractor (W507) |
| 15.4.s3 | OPEN | NOT_APPLICABLE | continual-learning duty; no post-market retraining loop |
| 15.5 | EVIDENCED | EVIDENCED (unchanged) | W509 |
| 15.5.s2 | OPEN | EVIDENCED | solution appropriateness = risk-scoped SHACL admission gate (W509) |
| 15.5.s3 | OPEN | OPEN | AI-vulnerability prevent/detect/respond/resolve lifecycle — gate covers prevention only |
| 26.1 | OPEN | EVIDENCED | use per instructions = governed actuation under human-authority quiescent stop + audit chain (W507/W503) |
| 26.2 | OPEN | EVIDENCED | human oversight = human-authority override/stop path (W507) |
| 26.3 | OPEN | NOT_APPLICABLE | savings clause, no independent duty |
| 26.4 | OPEN | EVIDENCED | input-data relevance under deployer control = W502 gate |
| 26.5 | OPEN | EVIDENCED | operation monitoring = OCEL event log + capability receipts over audit chain (W503/W524b) |
| 26.5.s2 | OPEN | NOT_APPLICABLE | not a financial institution |
| 26.6 | OPEN | OPEN | logs are kept (W503 chain) but no configurable retention-period surface |
| 26.6.s2 | OPEN | NOT_APPLICABLE | not a financial institution |
| 26.7 | OPEN | OPEN | workplace worker-information duty — no notification surface |
| 26.8 | OPEN | NOT_APPLICABLE | not a public authority / Union institution |
| 26.9 | OPEN | EVIDENCED | use of Art.13 info = counterfactual + admission attribution (W506/W505) |
| 26.10*.s2–s6 | OPEN | NOT_APPLICABLE | post-remote biometric identification / law-enforcement machinery — no such deployment |
| 26.11 | OPEN | NOT_APPLICABLE | Annex III employment-decision system — none deployed |
| 26.12 | OPEN | EVIDENCED | authority-cooperation substrate = replayable receipt chain (W524b) |
| 27.1, 27.1.a–f, 27.2, 27.3 | OPEN | OPEN | FRIA machinery — honestly never conducted; no FRIA document/notification surface |
| 27.4 | OPEN | NOT_APPLICABLE | DPIA savings/routing clause, no independent duty |
| 27.5 | OPEN | NOT_APPLICABLE | AI Office (Commission) template duty — authority-side |

## Counts

| Verdict | Before (W523) | After (W535, these six articles) |
|---|---|---|
| EVIDENCED | 4 (10.2.f/g/h, 15.4, 15.5) | **17** |
| NOT_APPLICABLE | 0 | **23** |
| OPEN_GAP | 46 | **14** |

Still-open (honest): 8.1, 15.3, 15.5.s3, 26.6, 26.7, 27.1, 27.1.a, 27.1.b,
27.1.c, 27.1.d, 27.1.e, 27.1.f, 27.2, 27.3.

Flipped: **36** (13 → EVIDENCED, 23 → NOT_APPLICABLE). Still-open: **14**.

## Verification (real runs, 2026-10-06)

Filled after the lane-build-root runs complete — see final section.

Green gate (contract command, lane build root `_build-laneW535`):

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW535 \
  mix test --include eu_ai_act --exclude eu_ai_act_open_gap test/eu_ai_act/title_iii_test.exs
```

```
Result: 376 passed, 15 excluded
[exited with code 0]
```

(376 green includes W532's concurrent Art 9/13/14 flips — combined file state.
15 excluded = total Title III open gaps after both lanes: my 14 + W532's 14.4.b.)

With-gaps census run:

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW535 \
  mix test --include eu_ai_act --include eu_ai_act_open_gap test/eu_ai_act/title_iii_test.exs
```

```
Result: 376/391 passed
Failed: 15 tests
```

Per-article open-gap census (from the 15 failing test ids, machine-extracted):

| Article | Open | Lines |
|---|---|---|
| 8 | 1 | 8.1 |
| 10 | 0 | — |
| 11 | 0 | — |
| 14 | 1 | 14.4.b (W532's lane, not W535's) |
| 15 | 2 | 15.3, 15.5.s3 |
| 26 | 2 | 26.6, 26.7 |
| 27 | 9 | 27.1, 27.1.a-f, 27.2, 27.3 |

W535's six-article scope: **14 open** (was 50). Flipped: **36** (13 EVIDENCED,
23 NOT_APPLICABLE).

## Receipt

- identity: lane W535, xaas @ feat/playwright-surface, files:
  `test/eu_ai_act/title_iii_test.exs` (Art 8/10/11/15/26/27 entries) + this doc.
- authority: lane contract (2-file write scope, respected; W532 co-tenant for
  Art 9/13/14 — re-read before every edit, zero of their lines touched).
- generated vs handwritten: classification maps are hand-written irreducible
  residue; the tests themselves are GENERATED from the corpus at compile time.
- standing: PARTIAL_ALIVE — the 14 remaining Art 8/10/11/15/26/27 open gaps are
  the honest frontier (FRIA surface, declared-metrics surface, retention-policy
  surface, AI-vulnerability lifecycle, umbrella 8.1).
- falsifier: any EVIDENCED path missing on disk, a NOT_APPLICABLE reason string
  that is empty, or a corpus line in these six articles failing classification
  (falls to the residual OPEN_GAP rule).
