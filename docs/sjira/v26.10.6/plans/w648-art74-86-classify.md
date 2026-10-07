# W648 — Titles VI-XIII classification flip: Art 74.12/74.13.a/74.13.b + 86.2/86.3

- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface`, lane build root `_build-laneW648`
- **File (only files touched)**: `test/eu_ai_act/title_vi_xiii_test.exs` (cond branches + moduledoc rules 4 and 6) and this receipt
- **Coordination**: read the file fresh before editing (W625c Art 73 flips present on disk and left untouched); only the 5 contracted entries changed.

## Classifications (per-line receipt)

| line_id | corpus text (trimmed) | addressee | verdict | typed reason (cites corpus + surface reality) |
|---|---|---|---|---|
| 74.12 | "the market surveillance authorities shall be granted full access by providers to the documentation as well as the training, validation and testing data sets" | provider | NOT_APPLICABLE | authority access procedure — the durable record exists (sealed receipt corpus `docs/sjira/*/plans`, OCEL event log `lib/xaas/telemetry/ocel_ndjson.ex` + envelope/ash-emitter siblings, audit chain `lib/xaas/witness/audit_chain.ex`); the access request/grant procedure runs on the authority side and is not a system obligation of this repo |
| 74.13.a | "access to source code is necessary to assess the conformity of a high-risk AI system" | both | NOT_APPLICABLE | condition the AUTHORITY evaluates on its own reasoned request (Art 74.13 source-code access gate); the source of truth is public in this repo and the access procedure itself is authority-side |
| 74.13.b | "testing or auditing procedures and verifications based on the data and documentation provided by the provider have been exhausted or proved insufficient" | provider | NOT_APPLICABLE | exhaustion condition tested by the market-surveillance authority; our auditable substrate (receipt corpus + OCEL + audit chain) is the record such testing consumes, the exhaustion determination is authority-side |
| 86.2 | "Paragraph 1 shall not apply to the use of AI systems for which exceptions from, or restrictions to, the obligation under that paragraph follow from Union or national law" | both | NOT_APPLICABLE | legal scoping provision — the law-derived exception determination is authority/legal-side; the explanation seam itself is already evidenced (86.1, W506 counterfactual surface `lib/xaas/semantics/counterfactual.ex`) |
| 86.3 | "This Article shall apply only to the extent that the right referred to in paragraph 1 is not otherwise provided for under Union law" | both | NOT_APPLICABLE | legal scoping provision — applicability of the Art 86 right where Union law already provides it is a legal determination, not a system obligation; no law-derived exception handling exists or is required in-repo |

## Commands / exits (verification ladder, narrow first)

```
PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW648 \
  mix test test/eu_ai_act/title_vi_xiii_test.exs --include eu_ai_act --exclude eu_ai_act_open_gap
  # -> Result: 476 passed (exit 0)

PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW648 \
  mix test test/eu_ai_act/title_vi_xiii_test.exs --include eu_ai_act --include eu_ai_act_open_gap
  # -> Result: 476 passed, 0 failures (exit 0) — the open-gap module now generates zero tests
```

## Standing

- Classified this session: **5** (74.12, 74.13.a, 74.13.b, 86.2, 86.3 — all to `:not_applicable` typed).
- Still open on this file: **0** — `Xaas.EUAIAct.TitleVIXIIIOpenGapsTest` generates no tests after this flip.
- Pre-existing failure note: bare `mix test test/eu_ai_act/title_vi_xiii_test.exs` (no includes) excludes all 476 via test config tag policy — transport detail, not a failure; both contracted directions run green as above.
- Generated-vs-handwritten: handwritten test-code edits only (typed reason strings); no generator profile exists for this surface.
