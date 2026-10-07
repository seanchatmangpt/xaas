# W620 — OS-14 Runtime Export API (GAP(NO_RUNTIME_EXPORT_API) closure)

Lane W620, EU-AI-Act wave, 2026-10-06, repo `/Users/sac/xaas` @ `feat/playwright-surface`.

## Gap

The coverage map (`docs/sjira/v26.10.6/eu-ai-act-nist-coverage-map.md`) carried
`GAP(NO_RUNTIME_EXPORT_API)` under Art. 12(3): the EU AI Act conformance
evidence pack existed only as a CLI (`mix xaas.eu_ai_act_pack`, W513) — no
in-app export surface existed.

## Closure

- `lib/xaas_web/controllers/eu_ai_act_export_controller.ex` (new) — serves
  `GET /internal-api/eu-ai-act/pack` by calling the W513 task's public
  `build/1` directly (same fail-closed semantics: missing evidence path /
  missing coverage map / empty typed-gaps → typed refusal, never a
  fabricated pack). A refused build returns 503 with a typed
  `xaas.eu_ai_act_pack_refusal/v1` body.
- `lib/xaas_web/router.ex` — one route line added inside the existing
  pre-forward token-gated `/internal-api` scope (same shadowing reason as
  siblings). No new auth surface: the existing `RequireInternalApiToken`
  floor gates it (no token → 401; unset token config → 503, preserved).
- `test/xaas_web/eu_ai_act_export_controller_test.exs` (new) — real
  Chicago-style ConnCase tests: tokened GET → 200 with
  `schema == "xaas.eu_ai_act_pack/v1"`, non-empty typed-gaps lines
  containing `GAP(`, real `subject` (branch + head_sha); every cited
  evidence path verified to exist on disk; two GETs identical modulo
  `generated_at`; no-token → typed 401.

## Receipt

- Remaining gap: narrowed to retention/persistence (the pack is generated
  on request from on-disk evidence; no persisted/retained export artifact
  yet). `GAP(NO_RUNTIME_EXPORT_API)` no longer holds — the runtime export
  API now EXISTS.
- Test/compile receipts: see lane report (MIX_BUILD_ROOT=_build-laneW620,
  strict compile + `mix test` on the new file + internal-api floor tests).
