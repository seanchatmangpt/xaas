# W619 — Evidenced-line deepening, Titles IV+V and VI–XIII (EU AI Act corpus)

Lane: W619, EU-AI-Act wave. Date: 2026-10-06. Branch: `feat/playwright-surface` (xaas).
Contract: write ONLY `test/eu_ai_act/title_iv_v_test.exs`,
`test/eu_ai_act/title_vi_xiii_test.exs`, and this receipt. Tags and verdict mapping
preserved byte-for-byte; deepening is spliced INTO the existing EVIDENCED test bodies
after the (retained) path-existence assertions.

## Vapor replaced

The w522-era EVIDENCED pattern asserts `File.exists?/1` over paths — evidence of
*presence*, not *behavior*. W619 adds a real call per deepened line so a corrupted or
drifted seam fails the corpus line, not just a deleted file.

## Deepened lines (13)

Mechanism: per-line_id compile-time splice. `Xaas.EUAIAct.TitleIVV.Deepenings.deepening/1`
(titles IV+V) and `Xaas.EUAIAct.TitleVIXIII.Deepenings.deepening/1` (titles VI-XIII)
return quote blocks unquoted into the EVIDENCED test bodies; unknown ids splice `:ok`
(no-op), so every non-deepened line is unchanged.

| line | before (assertion set) | after (added real call) |
|---|---|---|
| 50.1 | 5 paths exist | Direct `XaasWeb.Plugs.SyntheticMarkingPlug.call/2` (no HTTP): POST `/a2a/v1` + `send_resp` → `x-ai-generated: true` header AND `ai_generated: true` JSON field; GET + non-AI path pass-through unmarked |
| 50.5 | 3 paths exist | `EuAiActAdmission.admit/1` returns exact typed atoms (`REFUSED_EUAIA_MANIPULATIVE`, `REFUSED_EUAIA_EMOTION_RECOGNITION`); 8 refusal atoms, each with non-empty `describe/1` |
| 53.1.b | 2 paths exist | W512 pin shape asserted in `lib/xaas/actuation.ex` source (`admit_authority` gate first; `argument(:admission, result(:admit))`); content-independence called: `admit(%{"authority" => "all"})` == `{:ok, :admitted}` (content is not a prohibited shape) |
| 55.1.a | 2 paths exist | Real 50-shape adversarial fuzz over `EuAiActAdmission.admit/1` (deterministic corpus, cycled to 50); every verdict lawful |
| 55.1.d | 2 paths exist | W509 `eyerun_wasi` binary (`/tmp/w509-target/release/eyerun_wasi`) over REAL tempfiles: `{"verdict":"ADMITTED"}` exit 0 and `REFUSED_REQUIRED_FIELD_MISSING`; fallback (binary absent) = crate source + w509 receipt's real 16+5 test counts |
| 72.1 | 5 paths exist | w511/w545 receipt exact numbers asserted (`drift_decision(5/6, 0.1) == :DRIFT`, `(1.0,0.1)`/`(0.9,0.1) == :NO_DRIFT`, `== 1.0`) + the drift rule CALLED inline (strict `C < 1 - eps`): 1.0→NO_DRIFT, 5/6@0.1→DRIFT, 0.9@0.1→NO_DRIFT, 11/15@0.05→DRIFT; w545 integration test's asserted values present in its source |
| 72.2 | 4 paths exist | same art72() block |
| 72.3 | 4 paths exist | same art72() block (the DRIFT decision IS the 72.3 monitoring-plan basis) |
| 72.4 | 4 paths exist | same art72() block |
| 72.4.s2 | 4 paths exist | same art72() block |
| 86.1 | 3 paths exist | `Xaas.Semantics.Counterfactual.run/2` + `evaluate/3` on a canonical record: same-input replay `changed? == false`; counterfactual (drop `pii_fields`) `outcome == :admitted`, `changed? == true`, explanation names `pii_minimized` |
| 99.3 | 3 paths exist | Zero-liability total-function property: `admit/1` never raises on 50 seeded adversarial candidates (every Art.5 shape + malformed non-maps); every verdict `{:ok,:admitted}` or `{:error, atom ∈ refusal_atoms}`; malformed → `REFUSED_EUAIA_MALFORMED_CANDIDATE` |
| 99.4 | 4 paths exist | Same property plus operator-posture: ≥5 distinct refusal atoms observed, each with non-empty human partition via `describe/1` |

## What was NOT changed

* Tags (`:eu_ai_act` per-test; `:eu_ai_act_open_gap` only on gap tests), verdict
  mapping, corpus load, open-gap inventory: untouched.
* Non-deepened evidenced lines: splice is `:ok`.
* No lib/ or other-repo edits. eu_gate binary consumed read-only from the W509
  private target dir.

## Verification (real output, 2026-10-06, _build-laneW619)

```
# Direction A (compliance run — evidenced + NA admitted):
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW619 \
  mix test test/eu_ai_act/title_iv_v_test.exs test/eu_ai_act/title_vi_xiii_test.exs \
  --include eu_ai_act --exclude eu_ai_act_open_gap
  ==> Result: 536 passed, 5 excluded        # exit 0

# Direction B (default run — :eu_ai_act globally excluded by test.exs):
  ... mix test <same two files> --exclude eu_ai_act_open_gap
  ==> Result: 0 tests, 541 excluded         # exit 0, green
```

All 13 deepened EVIDENCED tests pass inside the 536 (none excluded: they carry
only `:eu_ai_act`). The 5 excluded are the by-design OPEN_GAP flunks (Art 73-family
exclusions notwithstanding, current corpus gap count for these two files = 5).

## Standing

EVIDENCED lines in these two files are now behavior-qualified, not
path-qualified, for the 13 lines above. Remaining evidenced lines keep the
w522-era pattern (honest, disclosed).
