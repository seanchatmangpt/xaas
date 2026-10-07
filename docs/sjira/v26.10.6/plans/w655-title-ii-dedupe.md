# W655 — Title II dedupe consolidation (receipt)

Subject: `/Users/sac/xaas` @ `feat/playwright-surface`, lane build root `_build-laneW655` (seeded from `_build`; fresh-root dep compile fails on ash_a2a `:capability_release_closure_missing` — pre-existing, unrelated).

Files touched (contract): `test/eu_ai_act/title_ii_test.exs` only.

## W606 finding, confirmed

The synthetic `@partitions` layer and the W531 corpus loop both drive the REAL
`EuAiActAdmission.admit/1` with byte-identical candidate maps for the same
refusal atoms. 6 duplicated (atom, candidate) pairs (W606 counted 5 lines b/c/d/e/f;
a 6th pair, the two 5.1.a lines, was found and included):

| synthetic partition | refusal atom | synthetic candidate | identical corpus line |
|---|---|---|---|
| 5.1.a-manipulative | MANIPULATIVE | `%{techniques: [:deceptive]}` | 5.1.a |
| 5.1.a-vulnerability | VULNERABILITY_EXPLOIT | `%{techniques: [:exploit_vulnerability]}` | 5.1.b |
| 5.1.b | SOCIAL_SCORING | `%{data_domains: [:social_behavior], context_joins: [:unrelated_context_join]}` | 5.1.c |
| 5.1.d | FACIAL_SCRAPING | `%{data_domains: [:facial_images], provenance: :scraped}` | 5.1.d |
| 5.1.e | EMOTION_RECOGNITION | `%{data_domains: [:affective], setting: :workplace}` | 5.1.e |
| 5.1.f | BIOMETRIC_CATEGORIZATION | `%{data_domains: [:biometric], inferences: [:political_opinion]}` | 5.1.f |

(5.1.c PREDICTIVE_POLICING and 5.1.g-h REALTIME_RBI were not exact dupes — the
synthetic candidates already differ from the corpus ones.)

## Resolution: differentiation, not deletion

Task preference honored — every pair kept, synthetic candidate changed to a
distinct violating shape proving a different facet of the same invariant:

| pair | action | new synthetic candidate | distinct facet proven |
|---|---|---|---|
| 5.1.a-manipulative | differentiated | `%{techniques: [:subliminal]}` | :subliminal technique class refuses, not just :deceptive |
| 5.1.a-vulnerability | differentiated | `%{techniques: [:target_vulnerable_audience], context_joins: [:age_slice_join]}` | :target_vulnerable_audience technique refuses, not just :exploit_vulnerability |
| 5.1.b | differentiated | `%{purpose: :credit_decisions, data_domains: [:social_behavior], context_joins: [:unrelated_context_join]}` | a declared purpose does NOT rescue the unrelated-context join |
| 5.1.d | differentiated | `%{data_domains: [:facial_images], provenance: :publicly_scraped}` | ANY non-`:consented` provenance refuses, not just `:scraped` |
| 5.1.e | differentiated | `%{data_domains: [:affective], setting: :education}` | the `:education` setting also prohibits `:affective` data |
| 5.1.f | differentiated | `%{data_domains: [:biometric], match_token_type: :raw_embedding}` | a non-boolean match token refuses even with no `:inferences` |

Near-miss controls (W616) unchanged — each is still ADMITTED by the suite run.

## Census

- Tests before: 40. Tests after: 40 (no test added or removed).
- Coverage claim intact: 8 partitions + near-miss controls + sub-line
  candidates (5.1.c.i, 5.1.c.ii, 5.1.g, 5.1.h) + catch-all + corpus closure
  (26/26 line_ids classified) — no line lost.
- Exact (atom, candidate) dupes between the two layers: 6 before, 0 after.

## Green gate

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW655 \
  mix test test/eu_ai_act/title_ii_test.exs --include eu_ai_act
Finished in 0.2 seconds
Result: 40 passed
```
