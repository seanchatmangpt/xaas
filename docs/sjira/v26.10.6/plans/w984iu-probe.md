# W984iu — unclaimed-family probe: EU-AI-Act HTTP plug seams

Lane: W984iu · repo /Users/sac/xaas · branch feat/playwright-surface · 2026-10-07 · NO commit (per dispatch).

## Subject

- `lib/xaas_web/plugs/eu_ai_act_admission_plug.ex` (W521)
- `lib/xaas_web/plugs/synthetic_marking_plug.ex` (W533)
- Mounted in `lib/xaas_web/endpoint.ex:99-100` (marking BEFORE admission, order-sensitive; W703 pins this).

## Census (branch -> disposition)

EuAiActAdmissionPlug:
- POST /a2a, map body+params, admit-ok pass-through — COVERED (W521 t1)
- admit error -> JSON-RPC -32600 refusal envelope — COVERED (W521 t2/t3)
- body_params non-map -> else pass-through — **COVERED HERE (t2)**
- body_params map without "params" — COVERED (W521 t4)
- non-POST / non-/a2a pass-through — COVERED (W421 t4)
- request_id string-key "id" — COVERED (W521 t2)
- request_id atom-key `%{id: id}` clause — **COVERED HERE (t3)**
- request_id missing -> nil envelope id — **COVERED HERE (t4)**
- normalize non-binary-key pair passthrough — **COVERED HERE (t5)**

SyntheticMarkingPlug:
- POST /a2a + /mcp marking (header + body field) — COVERED (W533 t1/t2)
- refusal envelopes marked (incl. halted W521 refusal) — COVERED (W533 t3, W703 a/c/d)
- non-AI surface / GET pass-through — COVERED (W533 t4/t5)
- non-JSON body on marked surface: header only, no injection — **COVERED HERE (t6)**
- empty/nil body guard on marked surface — **COVERED HERE (t7)**

## New court file

`test/xaas_web/eu_ai_act_plugs_court_w984iu_test.exs` — 7 tests (t2..t7 + describe blocks; 6
new-branch tests), Chicago-style real conn construction through the real plug modules, zero
mocks. W521/W533/W703 already cover the endpoint-mounted path; this file courts the plug-function
branches those courts do not reach. Mutation rationale in each comment block.

Notable finding (pinned in t5): value atomization in `normalize/1` is coupled to the binary-key
clause — an atom-keyed `:techniques => ["subliminal"]` pair passes through with its string value
un-atomized, so the gate ADMITS a shape that would refuse if string-keyed. Not a defect (atom-keyed
params are not the wire format), but the coupling is now witnessed.

## Gates (real output)

- `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984iu mix test test/xaas_web/eu_ai_act_plugs_court_w984iu_test.exs` → `Result: 6 passed` (first run found one mis-specified test, t5, which asserted refusal where the real behavior is admit; corrected to pin observed behavior)
- Mock gate: `scan_mock_usage(["test","lib"])` → `[]`
- Regression: `mix test --include eu_ai_act` over admission_integration + synthetic_marking + plug_mount_order_court + w984iu courts → `Result: 19 passed`

All under pinned asdf toolchain (elixir 1.20.2-otp-28), exit 0.

## Standing

ALIVE — all courts executed on the exact subject, exit 0.
