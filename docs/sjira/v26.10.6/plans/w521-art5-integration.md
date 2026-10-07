# W521 — Art. 5 Admission Live-Surface Integration

Lane: W521 (EU-AI-Act wave), repo `/Users/sac/xaas` @ `feat/playwright-surface`, build root `_build-laneW521`.

## Seam choice (why minimal)

`XaasWeb.Plugs.EuAiActAdmissionPlug` — an endpoint plug in `lib/xaas_web/endpoint.ex`,
inserted immediately after `Plug.Parsers`, mirroring the W150
`XaasWeb.Plugs.A2AParseFloor` idiom exactly:

- Same keying: `%{method: "POST", path_info: ["a2a" | _]}` — only `/a2a` POSTs
  are gated; GETs (agent card), SSE, and non-/a2a paths pass untouched.
- No router, scope, or forward change. The scope's
  `:require_internal_api_token` stays the single auth floor; the gate grants
  no authority — it only refuses.
- Placement after `Plug.Parsers` guarantees `body_params` is the decoded
  JSON-RPC map (A2AParseFloor fetched it before `Plug.Parsers`, which honors
  already-fetched bodies, `deps/plug/lib/plug/parsers.ex:288,325`).

## Behavior

- Runs `Xaas.Semantics.EuAiActAdmission.admit/1` over the JSON-RPC `params`
  map before agent dispatch.
- Normalization converts ONLY the nine schema keys + the 19-term
  prohibited-practice vocabulary via a compiled string→atom map (deterministic;
  `String.to_existing_atom/1` was tried first and proved nondeterministic across
  fresh test nodes — the compiled map removes any atom-table dependency).
  Unknown keys and free text are never atomized or inspected: same structure +
  different text ⇒ same verdict (courted in test 3).
- Refusal envelope mirrors the surface's JSON-RPC 2.0 shape: HTTP 200,
  request `id` echoed, `error.code` -32600, message, and the machine-detectable
  typed atom in `error.data.refusal` (+ `error.data.article` via
  `EuAiActAdmission.describe/1`).

## Diff

- `lib/xaas_web/plugs/eu_ai_act_admission_plug.ex` (new)
- `lib/xaas_web/endpoint.ex` (+15 lines: comment + one `plug/1` line)
- `test/xaas_web/eu_ai_act_admission_integration_test.exs` (new, 4 courts)

## Courts (Chicago: real endpoint pipeline, real JSON-RPC bodies, no mocks)

1. Lawful `message/send` params pass the gate untouched (reach the auth floor
   → 401 proves no halt at the gate).
2. Art. 5(1)(b) social-scoring structural shape → HTTP 200 envelope, exact
   atom `REFUSED_EUAIA_SOCIAL_SCORING` in `error.data`, article text in
   `error.data.article`, id echoed.
3. Content-blindness: same structure/different text ⇒ identical refusal;
   `subliminal` technique ⇒ exact `REFUSED_EUAIA_MANIPULATIVE` atom.
4. Non-/a2a paths, GETs, and params-less POSTs pass through untouched
   (direct `Plug.Test` conn through the real plug).

## Verification (real command tails)

- `mix compile` (MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW521): exit 0.
- `mix test test/xaas_web/a2a/ test/xaas_web/eu ai_act...` — final: `28 passed`
  (24 pre-existing a2a + 4 new W521), three consecutive green runs of the
  W521 file (`4 passed` x3) after removing a nondeterministic
  `String.to_existing_atom` dependency.

## Standing

ALIVE — gate observed refusing/executing on the real endpoint pipeline on the
exact lane subject. W507's quiescent_stop.ex blocker never intersected this
lane (compile and tests green throughout). Lane build root `_build-laneW521`
is a lease — delete at integration.
