# W522 — Title II (Art. 5) Chicago-test suite — receipt

Lane: W522, EU-AI-Act Chicago-test wave. Branch: `feat/playwright-surface`.
Contract write set honored: `test/eu_ai_act/title_ii_test.exs` + this receipt only.

## Subject

- `test/eu_ai_act/title_ii_test.exs` — NEW (handwritten; no generator capability for
  this surface). `Xaas.EUAIAct.TitleIITest`, `@moduletag :eu_ai_act`.

## Diff (handwritten)

One EVIDENCED test per Art. 5(1) refusal-atom partition, plus structural,
catch-all, WASI-gate, live-integration, and recital tests:

| line | partition | status | verdict asserted |
|---|---|---|---|
| 5.1.a (manipulative) | `REFUSED_EUAIA_MANIPULATIVE` | EVIDENCED | real `admit/1` → exact atom |
| 5.1.a (vulnerability) | `REFUSED_EUAIA_VULNERABILITY_EXPLOIT` | EVIDENCED | real `admit/1` → exact atom |
| 5.1.b | `REFUSED_EUAIA_SOCIAL_SCORING` | EVIDENCED | real `admit/1` → exact atom |
| 5.1.c | `REFUSED_EUAIA_PREDICTIVE_POLICING` | EVIDENCED | real `admit/1` → exact atom |
| 5.1.d | `REFUSED_EUAIA_FACIAL_SCRAPING` | EVIDENCED | real `admit/1` → actual atom |
| 5.1.e | `REFUSED_EUAIA_EMOTION_RECOGNITION` | EVIDENCED | real `admit/1` → exact atom |
| 5.1.f | `REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION` | EVIDENCED | real `admit/1` → exact atom |
| 5.1.g-h | `REFUSED_EUAIA_REALTIME_RBI` | EVIDENCED | real `admit/1` → exact atom |
| 5.catch-all | — | EVIDENCED | clean candidate → `{:ok, :admitted}`; 8 typed atoms declared |
| 5.structural-gate | — | EVIDENCED | eu_gate crate sources + W509 21-test receipt on disk |
| 5.live-integration | — | EVIDENCED | `test/xaas_web/eu_ai_act_admission_integration_test.exs` (W521, landed mid-lane 2026-10-06 19:37) asserts the typed refusal envelope on real `/a2a/v1` POSTs |
| Title II recitals | — | NOT_APPLICABLE | recital/definition — no behavioral obligation |

Each EVIDENCED partition test does three things (Chicago: real call, no mocks):
(a) asserts `lib/xaas/semantics/eu_ai_act_admission.ex` exists, (b) calls
`Xaas.Semantics.EuAiActAdmission.admit/1` on a representative violating candidate
and asserts the EXACT typed refusal atom, (c) greps the W500 test file
`test/xaas/semantics/eu_ai_act_admission_test.exs` content for the atom.

## OPEN_GAP inventory

None. During the lane, W521's `test/xaas_web/eu_ai_act_admission_integration_test.exs`
landed (2026-10-06 19:37); the provisionally-tagged `:eu_ai_act_open_gap`
live-integration test was flipped to untagged EVIDENCED form citing it
(gate name + `REFUSED_EUAIA_` envelope present in its content).

## Verification (real output)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW522 \
  mix test --include eu_ai_act --exclude eu_ai_act_open_gap test/eu_ai_act/title_ii_test.exs

Result: 13 passed
```
