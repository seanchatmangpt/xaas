# W526 — EU AI Act suite wiring (receipt)

Subject: /Users/sac/xaas @ feat/playwright-surface, lane W526, private build root `_build-laneW526`.

## Diff (handwritten; no generator capability for this surface)

- `test/eu_ai_act/support/corpus_loader.ex` — NEW. `Xaas.EUAIAct.CorpusLoader`:
  `lines/0`, `line/1`, `counts/0` over `docs/eu_ai_act/corpus.json`. Absent
  corpus raises typed `REFUSED(EUAIA_CORPUS_MISSING_W520)` naming lane W520.
- `test/eu_ai_act/smoke_test.exs` — NEW. `@moduletag :eu_ai_act`; structure
  gate: corpus loads, every line has `line_id` + `text` + `kind`; typed-absent
  path asserted while W520 has not landed.
- `test/test_helper.exs` — MODIFIED: `:eu_ai_act` added to the ExUnit exclude
  list (was: stress/kind/requires_cnv_deploy/requires_semantic_jira_api/
  external/external_llm/subprocess/property/castle_kernel). Default-suite
  runtime stays neutral; the compliance suite runs explicitly:

  ```
  PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW526 \
    mix test --include eu_ai_act test/eu_ai_act/
  ```

## Per-title test contract (for every per-title generator lane)

Each obligation corpus line gets exactly one test named:

```
test "EUAI-ACT <line_id>: <kind> — <short>"
```

with one of three statuses asserted in the body:

| status        | body                                                        |
|---------------|-------------------------------------------------------------|
| EVIDENCED     | assert the real product path exists and its test passes     |
| NOT_APPLICABLE| typed reason string (e.g. provider-in-the-loop obligation)  |
| OPEN_GAP      | `flunk "OPEN_GAP: <what is missing>"` — FAILS BY DESIGN until implemented; this is the executable compliance pressure |

The integration receipt of the wave must list every OPEN_GAP by line_id.

## Verification (real, lane build root `_build-laneW526`, pinned asdf toolchain)

Corpus state moved during the lane: W520's `docs/eu_ai_act/corpus.json` landed
mid-lane (schema `{titles[].articles[].lines[]}` — NOT the assumed flat
`lines`), so the loader was adjusted to the real schema. Command + output:

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW526 \
  mix test --include eu_ai_act test/eu_ai_act/smoke_test.exs --seed 0
=> Finished in 0.06 seconds
=> Result: 3 passed (structure gate green on the real corpus)
```

Corpus counts (CorpusLoader.counts/0): **1068 lines**
kinds: definition=80, obligation=518, procedure=439, prohibition=31.

Full per-title dir state at lane end (sibling lanes' files included,
`mix test --include eu_ai_act test/eu_ai_act/`): 957/1081 passed, 124 failed —
failures are sibling per-title lanes' tests (OPEN_GAP-by-design and in-flight
per-title work), not the W526 structure gate, which passes 3/3.

## OPEN_GAPs

None — smoke/structure gate only. OPEN_GAP inventory begins when per-title
generators land.
