# W699 — A2A v1 Wire Deepening Court

- **Standing**: ALIVE (9/9 real test assertions, exit 0)
- **Subject**: `/Users/sac/xaas` @ branch `feat/playwright-surface`, HEAD `a0723bf6` (canonical checkout, no worktree)
- **Lane**: W699, v26.10.6 campaign
- **Written**: `test/xaas_web/a2a_v1_wire_deepening_test.exs` (new file, only file written besides this receipt)
- **Command**:
  `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW699 mix test test/xaas_web/a2a_v1_wire_deepening_test.exs --include eu_ai_act`
- **Real tail**:
  ```
  Running ExUnit with seed: 724974, max_cases: 32
  Excluding tags: [:stress, :kind, :requires_cnv_deploy, :requires_semantic_jira_api, :external, :external_llm, :subprocess, :property, :castle_kernel]
  Including tags: [:eu_ai_act]

  .........
  Finished in 1.1 seconds (0.00s async, 1.1s sync)

  Result: 9 passed
  ```
- **Verification ladder**: narrow (single-file ExUnit run) over the real endpoint
  pipeline (`XaasWeb.Endpoint` -> A2AParseFloor -> Plug.Parsers -> SyntheticMarkingPlug
  -> EuAiActAdmissionPlug -> router -> :require_internal_api_token -> V1TransportPlug),
  real ConnCase HTTP, real GenServer agent, real decoded JSON-RPC bodies. No mocks,
  no interaction assertions (Chicago). Env-var 503 tests follow the existing
  `test/xaas_web/plugs/require_internal_api_token_test.exs` delete/restore
  (`on_exit`) idiom.
- **μ/diff**: +1 test file (`test/xaas_web/a2a_v1_wire_deepening_test.exs`), +1 receipt.
  Handwritten (no generator profile exists for ExUnit wire courts). Not committed,
  per lane instructions.

## Court cases pinned

1. **Malformed envelope** (valid JSON, missing `jsonrpc` member) → HTTP 200,
   `error.code == -32600` from the transport, echoed request id.
2. **-32600-family consistency**: transport invalid-request envelope and the
   `EuAiActAdmissionPlug` Art. 5 refusal envelope share identical error-object
   keys (`jsonrpc`/`id`/`error` shape, HTTP 200) — `MapSet` key equality asserted;
   refusal carries typed `data.refusal == "REFUSED_EUAIA_SOCIAL_SCORING"`.
3. **Plug ordering (endpoint vs router)**: an Art. 5 refusal (`subliminal` →
   `REFUSED_EUAIA_MANIPULATIVE`) preempts the 401 token floor — admission gate
   halts at the endpoint before router auth.
4. **Marking composition (W533)**: refusal envelope is marked too
   (`x-ai-generated: true` header + `"ai_generated": true` top-level body field)
   because SyntheticMarkingPlug registers `before_send` before the halting gate.
5. **Agent card** (GET `/a2a/v1/.well-known/agent-card.json`, authed): required v1
   members (name/version/description/skills/capabilities/defaultInputModes/
   defaultOutputModes/supportedInterfaces), card `url` =~ `/a2a/v1`,
   `cache-control: public, max-age=300` (§8.6.1 wrapper contract) + ETag present.
6. **Marking on success + -32601 envelopes**: both carry the marking header and
   body field; success result is a `TASK_STATE_COMPLETED` task.
7. **Bearer gate fail-closed**: unset `INTERNAL_API_TOKEN` → 503 with exact body
   `{"error":"internal_api_misconfigured","detail":"INTERNAL_API_TOKEN is not set on the server"}`,
   both with no header and with a wrong bearer token.

## EU AI Act anchor

`@moduletag :eu_ai_act` with in-file comment naming Art. 14 transparency /
Art. 50.1 disclosure class; evidenced lines: `lib/xaas_web/plugs/synthetic_marking_plug.ex`
(Art. 50(2) marking), `lib/xaas_web/plugs/eu_ai_act_admission_plug.ex` (typed Art. 5
refusal envelope), `lib/xaas_web/a2a/v1_transport_plug.ex` (§8.6.1 card caching).

## Environment notes

- Cold lane build (fresh `_build-laneW699`); PromEx Grafana dashboard-uploader
  warnings (`:nxdomain`) during boot are pre-existing ambient noise, unrelated.
- `_build-laneW699` could NOT be deleted at lane end: `rm -rf` was denied by the
  session permission system (twice). Left for the coordinator per the lane-lease
  law — this integration is incomplete without deleting
  `/Users/sac/xaas/_build-laneW699`.

## Falsifiers (all held)

- A missing required card member, a wrong cache-control value, an unmarked
  response, a -32601/-32600 shape drift, or a 401-instead-of-503 would fail
  the corresponding test.
- Re-run gate: the exact command above; expect `Result: 9 passed`.
