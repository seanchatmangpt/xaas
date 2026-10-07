# W525b — Title I generator (EU AI Act Arts 1-4)

Lane: W525b of the EU-AI-Act Chicago-test wave, xaas @ feat/playwright-surface,
build root `_build-laneW525b`. Contract files: `test/eu_ai_act/title_i_test.exs`
+ this receipt.

## Shape

Mirrors W522's landed generator idiom (compile-time corpus read from
`docs/eu_ai_act/corpus.json`, lane W520 substrate; one ExUnit test per corpus
`line_id`; typed verdicts EVIDENCED / NOT_APPLICABLE / OPEN_GAP; open gaps
tagged `:eu_ai_act_open_gap`).

## Verdict mapping

- **Art. 1 (9 lines)** — legislative purpose/scope statements.
  `1.2.b` EVIDENCED (W500/W522 Art.5 refusal corpus + real admit/1 call);
  rest NOT_APPLICABLE("legislative scope/purpose statement").
- **Art. 2 (21 lines)** — scope rows: all NOT_APPLICABLE("legislative scope
  statement"); the obligations they scope are courted by the per-title suites
  (W522/W523/W525/W526).
- **Art. 3 (80 lines)** — definitions, `kind:"definition"`. Each line is a
  typed-vocabulary assertion:
  - EVIDENCED (16): 3.1 AI system, 3.2 risk, 3.12 intended purpose
    (candidate `:purpose`), 3.29-3.33 data definitions (W502
    DatasetAdmission, real sample-list admits), 3.39-3.43
    emotion/biometric systems (real refusal atoms from
    `EuAiActAdmission.admit/1`), 3.63 GPAI model (W512 decoupling pin),
    plus real `refusal_atoms/0`/`describe/1` typed-vocabulary assertions.
  - OPEN_GAP (6): 3.49 + 3.49.a-d (serious incident — no incident surface)
    and 4.1 (AI literacy) — flunk by design, excluded via
    `--exclude eu_ai_act_open_gap`.
  - NOT_APPLICABLE (58): definitional lines with no typed counterpart
    (market-placement/authority/notified-body concepts); typed reason string.
- **Art. 4 (1 line)** — 4.1 OPEN_GAP (AI literacy duty applies to
  deployers; no seam).

A corpus-pin test asserts the census: 30 Art.1-2 scope rows, 111 Title I
lines total, pinned at generation time.

## Verification (real run, 2026-10-06, pinned asdf toolchain)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW525b \
  mix test --include eu_ai_act --exclude eu_ai_act_open_gap \
  test/eu_ai_act/title_i_test.exs
# => Result: 106 passed, 6 excluded
```

With gaps included (`--include eu_ai_act --include eu_ai_act_open_gap`):
6 failures by design — EUAI-ACT 3.49, 3.49.a, 3.49.b, 3.49.c, 3.49.d,
4.1 (all in `Xaas.EUAIAct.TitleIOpenGapsTest`).

## Structure note (include-over-exclude)

Like W523's Title III, the file is split across two modules: ExUnit resolves
includes OVER excludes, so per-test `@tag :eu_ai_act_open_gap` alongside a
`@moduletag :eu_ai_act` resurrects the gap tests under the green-gate command
(observed 2026-10-06: 10/112 failing before the split). The gap tests live in
`Xaas.EUAIAct.TitleIOpenGapsTest`, which carries ONLY the
`:eu_ai_act_open_gap` moduletag, so the exclude actually holds.

## Verdict census (111 Title I corpus lines + 1 census-pin test = 112 tests)

| verdict | count | lines |
|---|---|---|
| EVIDENCED | 15 | 1.2.b, 3.1, 3.2, 3.12, 3.29-3.33, 3.39-3.43, 3.63 (13 with real typed admit/admission calls; 1.2.b and 3.63 paths+receipt pins) |
| NOT_APPLICABLE | 90 | Art.1-2 scope/purpose statements (29) + definitional lines with no typed counterpart (61) |
| OPEN_GAP | 6 | 3.49, 3.49.a-d (serious incident — no incident-reporting seam), 4.1 (AI literacy) |

Standing: PARTIAL_ALIVE (suite green under the wave exclude; open gaps are
the honest residual inventory).
