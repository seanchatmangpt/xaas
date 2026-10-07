# W524 — Title IV + V generator (corpus Titles IV+V, Arts 50-55)

- Repo: /Users/sac/xaas @ feat/playwright-surface (HEAD d1db2b03 at generation)
- Lane: W524, build root `_build-laneW524`
- Contract files: `test/eu_ai_act/title_iv_v_test.exs` (only write surface), this receipt.
- Standing: **ALIVE** — both falsifier runs executed, real output below.

## Scope note (honest corpus mapping)

The task brief described Title IV as Arts 28-39 and Title V as Arts 40-55. The landed
corpus (`docs/eu_ai_act/corpus.json`, W520) numbers differently: corpus Title IV = Art 50
(transparency), Title V = Arts 51-55 (GPAI). The coordinator confirmed the on-disk scope
fix during the session: this suite covers corpus Titles IV+V (articles 50-55, 50 lines),
one test per line_id `EUAI-ACT <line_id>`. Arts 28-49 remain under W523's Title III
generator.

## Tag discipline (coordinator discovery, applied)

ExUnit applies exclude BEFORE include, so a `@moduletag :eu_ai_act` resurrects gap tests
under `--include eu_ai_act --exclude eu_ai_act_open_gap`. Tags are therefore per-test:
`:eu_ai_act` on EVIDENCED/NOT_APPLICABLE tests, ONLY `:eu_ai_act_open_gap` on OPEN_GAP
tests (no moduletag), so the exclusion actually holds.

## Mapping table (50 corpus lines, Arts 50-55)

| Verdict | Lines | Basis |
|---|---|---|
| EVIDENCED (5) | `50.1`, `50.5` | typed refusal envelope + disclosure content: `lib/xaas/semantics/eu_ai_act_admission.ex`, `lib/xaas_web/plugs/eu_ai_act_admission_plug.ex`, `lib/xaas/actuation/refusal.ex`, `docs/cro/artifacts/end-user-disclosure-v26.10.6.md`, `docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json`, w500 receipt; paths asserted via `File.exists?/1` in-test |
| EVIDENCED (5) | `53.1.b`, `55.1.a`, `55.1.d` | W512 authority-decoupling pins (`test/xaas/semantics/authority_decoupling_test.exs` + `docs/sjira/v26.10.6/plans/w512-gpai-decoupling.md`); W509 WASI gate (`/Users/sac/wasm4pm/crates/eu_gate` + w509 receipt) |
| NOT_APPLICABLE (44) | all remaining Arts 50-55 lines | typed reasons: authority procedure (Commission/AI Office machinery — not an addressee); GPAI provider-classification / provider-duty (not a GPAI provider, no model placed on the Union market); Art 50 lines for system classes not deployed (emotion recognition, biometric categorisation, deepfake generation, published-to-inform-public text); savings/clarification lines |
| OPEN_GAP (1) | `50.2` | Art.50(2) machine-readable synthetic-content marking: synthetic agent text IS generated on this surface and no marking seam exists (OS-16 disclosure mount also open) |

## Command receipt

    PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW524 \
      mix test test/eu_ai_act/title_iv_v_test.exs --include eu_ai_act --exclude eu_ai_act_open_gap

    Excluding tags: [:eu_ai_act_open_gap, ...]
    Including tags: [:eu_ai_act]
    Result: 49 passed, 1 excluded

With gaps included (honest open-gap count run):

    PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW524 \
      mix test test/eu_ai_act/title_iv_v_test.exs --include eu_ai_act --include eu_ai_act_open_gap

    Result: 49/50 passed  (exactly 1 failure: EUAI-ACT 50.2 OPEN_GAP, by design)

## Verdict

ALIVE. Counts: **EVIDENCED 5 / NOT_APPLICABLE 44 / OPEN_GAP 1** over 50 corpus lines (Arts 50-55).
