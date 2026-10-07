# W533 — Art. 50(2) synthetic-content marking (lane receipt)

Subject: `/Users/sac/xaas` @ `feat/playwright-surface`, lane build root
`_build-laneW533`. Closes the single OPEN_GAP in `w524-title-iv-v.md`
(Art. 50(2) flips to CLOSED on the next generator pass over this receipt).

## Seam choice

`XaasWeb.Plugs.SyntheticMarkingPlug` — a new endpoint plug in
`lib/xaas_web/endpoint.ex`, placed immediately after
`XaasWeb.Plugs.EuAiActAdmissionPlug` (W521) — i.e. immediately BEFORE it,
not after (finding from the first court run: a W521 refusal halts in that
gate and Plug.Builder skips remaining plugs once halted, so a plug placed
after it never registers its `before_send` on the refusal path). Keyed on
`%{method: "POST", path_info: ["a2a" | _]}` / `["mcp" | _]` — exactly the
W521 path-keying idiom. No router/scope/forward change; GETs (agent card),
SSE, and all non-AI surfaces pass through unmarked.

Marking is applied AFTER the handler via `register_before_send`, so every
response from the AI surfaces is marked: success, token-floor 401, and the
W521 Art. 5 refusal envelope (which halts in an earlier plug —
`before_send` callbacks still run).

Marking = `x-ai-generated: true` response header (always, on both
surfaces) plus `"ai_generated": true` injected as a top-level field into
JSON **object** bodies (idempotent, non-destructive: decode → put →
encode; non-object JSON, SSE chunks, and empty bodies get header only).

Zero-config: unconditional, no operator knobs, no application env.

## Diff

- `lib/xaas_web/plugs/synthetic_marking_plug.ex` (new)
- `lib/xaas_web/endpoint.ex` (one plug + comment block added after W521)
- `test/xaas_web/synthetic_marking_test.exs` (new)

## Courts (test/xaas_web/synthetic_marking_test.exs)

1. POST `/a2a/v1` response carries header + field.
2. POST `/mcp` response carries header + field.
3. W521 Art. 5 refusal envelope (`REFUSED_EUAIA_*`, code -32600) is
   marked too.
4. Non-AI surface (`POST /internal-api/anything` → 401) carries no header
   and no injected field.
5. Plug-level: GET on the agent-card path and POST to a non-AI path are
   unmarked (no `before_send` registered).

## Verification (real output)

```
$ MIX_BUILD_ROOT=_build-laneW533 MIX_ENV=test mix compile --warnings-as-errors
(exited 0; only a pre-existing ash_affidavit @envelope_domain_tag warning
from the shared dep, not lane W533's files)

$ MIX_BUILD_ROOT=_build-laneW533 MIX_ENV=test mix test \
    test/xaas_web/synthetic_marking_test.exs \
    test/xaas_web/eu_ai_act_admission_integration_test.exs
.........
Finished in 0.09 seconds
Result: 9 passed   (5 W533 + 4 W521)

$ MIX_BUILD_ROOT=_build-laneW533 MIX_ENV=test mix test test/xaas_web/
Result: 367 passed, 1 excluded (exit 0)
```

## Court findings (first run — repaired in this receipt)

Two real defects found by the courts and fixed in the same lane:

1. **Iodata body**: Phoenix `json/2` sends `resp_body` as iodata, not a
   binary, so the original `is_binary` guard silently skipped the field
   injection on the real pipeline. Fix: `IO.iodata_to_binary/1` before
   `Jason.decode/1`.
2. **Halt ordering**: registered after the W521 admission gate, the
   marking never ran on refusal envelopes — `Plug.Builder` skips
   remaining plugs once `halt()`ed, so `register_before_send` was never
   called on that path. Fix: register BEFORE the W521 gate.

## OPEN_GAP closure note

w524-title-iv-v.md's single OPEN_GAP (Art. 50(2) synthetic-content
marking) is closed by this receipt: the marking is live, machine-detectable
(header + JSON field), zero-config, unconditional on the AI surfaces
including refusals. Art. 50(2) flips OPEN_GAP → CLOSED on the next
generator pass over this receipt.
