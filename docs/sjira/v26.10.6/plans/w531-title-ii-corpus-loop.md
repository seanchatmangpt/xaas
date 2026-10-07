# W531 — Title II corpus-loop receipt

Subject: `/Users/sac/xaas` @ `feat/playwright-surface` (canonical checkout, lane W531, private build root `_build-laneW531`)

Falsifier addressed (W527): Title II tests covered only the 8 synthetic partition atoms, not the corpus's 26 Title II lines. Post-W531: all 26 corpus `line_id`s have one test each, 0 uncovered.

## Change

`/Users/sac/xaas/test/eu_ai_act/title_ii_test.exs` (extend-only; W522 tests intact).

- Compile-time corpus loop (same shape as W523's Title III loop; direct `Jason.decode` of `docs/eu_ai_act/corpus.json` — the W526 `CorpusLoader` flat shape is not used, lane isolation).
- One test per corpus `line_id`, named `"EUAI-ACT <line_id>: <kind>"`, 26 total.
- Closure test `EUAI-ACT Title II corpus closure: every corpus line_id classified (W531/W527)` asserts evidenced + not-applicable == all 26.
- W522 synthetic ids kept as documented EXTRA ids (`5.catch-all`, `5.structural-gate`, `5.live-integration`, recitals test).

## Line → atom map (canonical map is `@line_atoms` in the test file)

EVIDENCED (10 lines) — each asserts a REAL `Xaas.Semantics.EuAiActAdmission.admit/1` call returning the exact typed atom, W500 test-file coverage, and `refusal_atoms/0` membership:

| corpus line_id | typed refusal atom |
|---|---|
| 5.1.a | `REFUSED_EUAIA_MANIPULATIVE` |
| 5.1.b | `REFUSED_EUAIA_VULNERABILITY_EXPLOIT` |
| 5.1.c / 5.1.c.i / 5.1.c.ii | `REFUSED_EUAIA_SOCIAL_SCORING` |
| 5.1.d | `REFUSED_EUAIA_FACIAL_SCRAPING` |
| 5.1.e | `REFUSED_EUAIA_EMOTION_RECOGNITION` |
| 5.1.f | `REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION` |
| 5.1.g, 5.1.h | `REFUSED_EUAIA_REALTIME_RBI` |

## NOT_APPLICABLE (16 lines), typed reasons

- `5.1` — enumerative prohibition-list header
- `5.1.h.i`, `5.1.h.ii` — Art.5(1)(h) exception carve-outs narrowing the prohibition (the prohibition itself is enforced via `REFUSED_EUAIA_REALTIME_RBI`); no separate deployer surface
- `5.1.s2` — cross-reference to Art.9 of Regulation (EU) 2016/672 (external law-enforcement directive); nothing to implement
- `5.2`, `5.2.a`, `5.2.b` — Art.5(2) law-enforcement authorization criteria; repo deploys no real-time RBI system
- `5.2.s2`, `5.3`, `5.3.s2`, `5.4`, `5.5`, `5.6`, `5.7` — authority-side machinery (judicial/administrative authorization, market-surveillance/data-protection reporting)
- `5.8` — savings clause

## Runs

Both under `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW531`:

```
mix test --include eu_ai_act --exclude eu_ai_act_open_gap test/eu_ai_act/title_ii_test.exs
mix test --include eu_ai_act test/eu_ai_act/title_ii_test.exs   # open gaps included
```

Both tails:

```
Result: 40 passed
```

Exit 0. 40 = 13 W522 originals + 26 corpus-line tests + 1 closure test. Open-gaps-included run identical (40 passed) ⇒ Title II open-gap/uncovered count post-fix = 0 (was 26 uncovered per W527).

## Standing

ALIVE (executed on the exact subject; both runs exit 0 over real `admit/1` calls, no mocks).
