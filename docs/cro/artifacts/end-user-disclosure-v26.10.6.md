# End-User Disclosure Content — v26.10.6 (OS-16 prep)

Lane W424, 2026-10-06. Repo `/Users/sac/xaas` @ `feat/playwright-surface`.
Document only. Content authored; surface NOT built — OS-16 stays open until a
mount lands.

## 1. Disclosure problem (from the wire evidence)

`docs/cro/artifacts/agent-obliviousness-demo.md` (W407, 2026-10-06): on the
`/mcp` surface, an unadmitted call (`delete_all_books`) returns
`{"error":{"code":-32602,"message":"Tool not found: delete_all_books"}}` —
HTTP 200, standard JSON-RPC envelope. The refusal is wire-indistinguishable
from tool absence: an end user or agent operator cannot tell "policy refused
this" from "this tool does not exist" from the wire alone. Art. 50 requires
the end user know they are interacting with an AI system and why an action did
not proceed; today neither is carried on the wire.

## 2. Disclosure text blocks (content, not yet mounted)

### 2a. Short form — API error envelope / tool-result metadata

> This endpoint is part of an AI-mediated system (xaas). Requests are evaluated
> by a policy admission layer before execution. When a request is refused, the
> response carries a typed reason code (`REFUSED_*`) identifying the failing
> gate. A missing tool is reported as `TOOL_NOT_FOUND`; a policy refusal is
> never reported as a missing tool.

### 2b. Long form — documentation surface

> **AI-mediated interaction disclosure (EU AI Act Art. 50)**
> You are interacting with an AI-mediated system (xaas). Tool calls are
> admitted or refused by a deterministic, typed policy layer before any
> consequential action executes. Refusals are first-class outcomes, not
> errors: each carries a machine-readable reason (`REFUSED_*`, 62-token
> vocabulary with negative-fixture coverage, delta 0 — see
> `docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json`) and the system state
> is unchanged after a refusal (pre==post asserted per
> `test/xaas/actuation_refusal_negative_test.exs`). This surface never
> silently degrades a refusal into a generic "tool not found" and never
> silently proceeds where policy refuses. Audit trail: per-actuation OCEL
> records (`lib/xaas/telemetry/ocel_ndjson.ex`); machine-readable ledger:
> `docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json`.

## 3. Typed mount-point recommendation (no code edited)

Every path below verified to exist at this HEAD.

1. **`/mcp` tools/list + tools/call metadata** —
   `/Users/sac/xaas/lib/xaas_web/controllers/execution_fabric_controller.ex`
   (`tools/list` handler at line 373; tool-level refusal already rendered as
   `isError:true` + typed reason via `tool_error/1`; `post("/execution/mcp",
   ExecutionFabricController, :mcp)` in `/Users/sac/xaas/lib/xaas_web/router.ex:103`).
   Mount: carry the short-form block as tool-descriptor metadata and a
   `disclosure` field on refused tool results. The `-32602 Tool not found`
   envelope for policy refusals originates in
   `/Users/sac/xaas/deps/ash_ai/lib/ash_ai/mcp/server.ex` — a typed-refusal
   envelope there is a dependency change, flagged as such.

2. **A2A agent card `capabilities`** —
   `/Users/sac/xaas/lib/xaas/a2a/agent.ex` (`Xaas.A2a.Agent`, the
   `GET /.well-known/agent-card.json` projection) served through
   `/Users/sac/xaas/lib/xaas_web/a2a/v1_transport_plug.ex` (W305 wrapper over
   `AshA2A.Transport.Plug`). Mount: an Art. 50 disclosure field on the card
   (AI-mediated interaction + typed-refusal behavior), so any A2A v1 consumer
   receives the disclosure at card-fetch time.

3. **ash_surface client chrome** —
   `/Users/sac/xaas/lib/mix/tasks/xaas.ash_surface.ex` (JS client projector;
   generated JS currently throws untyped `REFUSED_UNKNOWN_ACTION` /
   `REFUSED_NOT_DO_BOUNDARY` strings — w321, machine-readability gap). Mount:
   short-form disclosure banner in the generated client chrome plus typed
   refusal surfacing in the projector, folded into the generator so generated
   output is not hand-edited.

## 4. Scope line (honest)

Content authored only. No surface built; no code touched (write scope was
this file). `GAP(NO_END_USER_DISCLOSURE)` is narrowed, not closed: OS-16
remains open until the disclosure text is mounted on at least one of the
three surfaces in §3 and the mount is witnessed by a test on the mounted
surface.
