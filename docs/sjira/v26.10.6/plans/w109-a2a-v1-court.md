# W109 — /a2a/v1 ExUnit court (receipt)

Lane: W109 (wave 2). Subject: /Users/sac/xaas @ feat/playwright-surface. Written by the coordinator from the lane's completion report (2026-10-06).

## What landed
- `test/xaas_web/a2a/v1_protocol_test.exs` — ConnCase court through the real router (`:api` + `:require_internal_api_token`) → `AshA2A.Protocol.Plug` → `XaasWeb.A2A.NextReadAshAgent` → `NextReadUserAgent` GenServer dispatch. Structural JSON asserts, no string-scraping.

## Courts (all passing)
1. `GET /a2a/v1/.well-known/agent-card.json` → 200 + name/description/version/skills (id/name/description/tags)/capabilities/input-modes/supportedInterfaces + ETag + `Cache-Control: public, max-age=300` (plug.ex's documented cache contract).
2. `POST /a2a/v1` `message/send` with real skill `hddl:plan` → JSON-RPC 2.0 success, `task` wrapper, `TASK_STATE_COMPLETED`, agent reply in `history` as `ROLE_AGENT` text parts.
3. Unknown method → `-32601` (echoed id). 4. Malformed JSON → `-32700` (raw-body reader path). 5. No bearer token → 401 at the floor.

## Gate (real, verbatim)
`mix test test/xaas_web/a2a/v1_protocol_test.exs` → **5 passed** (0.4s).

## Finding acted on
`NextReadAshAgent` was unsupervised outside tests — coordinator added it to `Xaas.Supervisor` (lib/xaas/application.ex, next to NextReadUserAgent) with compile+court re-verified.
