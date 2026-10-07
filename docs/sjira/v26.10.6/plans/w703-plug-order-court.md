# W703 — Plug Mount Order Court (SyntheticMarkingPlug before EuAiActAdmissionPlug)

- **Subject**: /Users/sac/xaas @ a0723bf6, branch feat/playwright-surface, lane W703
- **Backlog**: W533 documented that SyntheticMarkingPlug must be registered
  BEFORE EuAiActAdmissionPlug on the /a2a surface (refusal envelopes must be
  marked); nothing courted the ordering.
- **Standing**: ALIVE (observed execution on the exact subject)

## New file

`test/xaas_web/plug_mount_order_court_test.exs` — Chicago-style, real
`XaasWeb.Endpoint` pipeline via `XaasWeb.ConnCase`, real JSON-RPC bodies,
no mocks. `@moduletag :eu_ai_act`. In-file evidence comment names
lib/xaas_web/endpoint.ex:99-100 and the Art. 50(2) marking disclosure
(Regulation (EU) 2024/1689).

## Courts

1. **(a) Order-sensitive composition**: Art-5-refused POST /a2a
   (`techniques: ["subliminal"]`) is BOTH refusal-enveloped
   (JSON-RPC -32600, `REFUSED_EUAIA_MANIPULATIVE`) AND marked
   (`x-ai-generated: true` header + `"ai_generated": true` body field).
2. **(b) Marked-but-admitted path**: lawful structural params pass the
   gate (reach the 401 token floor) and the response stays marked.
3. **(c) Reorder-kill observable**: documents and asserts that an Art-5
   refusal envelope must be marked. If the plugs were reordered
   (admission first), the refusal halts before the marking plug
   registers its `register_before_send` — Plug.Builder skips remaining
   plugs on halt — and the envelope ships unmarked. The exact kill is:
   refused response missing `x-ai-generated: true` or `"ai_generated":
   true`. Both asserted with named failure messages pointing at
   endpoint.ex:99-100.
4. **(d) Reorder mutation witnessed, not just derived**: test (d)
   actually executes the reordered composition (EuAiActAdmissionPlug
   first, direct `Plug.Conn`-level calls, no endpoint edit) and observes
   the halted refusal envelope shipping UNMARKED — the live side of the
   kill observable that (c) pins the real endpoint to.

## Verification (real tails)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW703 \
  mix test test/xaas_web/plug_mount_order_court_test.exs --include eu_ai_act
Including tags: [:eu_ai_act]
...
Finished in 0.2 seconds (0.00s async, 0.2s sync)
Result: 4 passed
```

Grafana/PromEx nxdomain warnings during boot are pre-existing ambient
noise (no Grafana locally), unrelated to this court.

Pre-existing sibling coverage (not a substitute; this court adds the
ordering pin): test/xaas_web/synthetic_marking_test.exs (W533),
test/xaas_web/eu_ai_act_admission_integration_test.exs (W521).

## μ/diff

Handwritten test only (irreducible residue; no generator profile for
plug-order courts). 1 new file, 0 modified, not committed per lane
contract — coordinator owns integration.

## Falsifier status

- Reorder mutation: both killed and witnessed — test (c) fails on any
  endpoint.ex reorder that puts the admission plug first; test (d)
  executes the reordered composition directly and observes the
  unmarked-refusal kill observable for real. No endpoint.ex mutation
  was applied (lane is read-only on lib/ per contract).

## Cleanup

`_build-laneW703` deleted at lane end per fanout cleanup law.
