# R4 — ash_a2a surface audit & wiring plan (v26.10.5 fleet wiring)

Lane R4 · 2026-10-06 · READ-ONLY survey. Subject: `/Users/sac/ash_a2a` @ `07180bd3`
(branch `feat/tck-vuln-hardening`). Consumers surveyed: `/Users/sac/xaas` @ `d1db2b03`
(`feat/playwright-surface`) and `/Users/sac/ash_surface` (hex dep, `runtime: false`).

## 1. Subject identity

| field | value |
|---|---|
| repo | `/Users/sac/ash_a2a` |
| branch | `feat/tck-vuln-hardening` @ `07180bd3` — 61 commits ahead of the v26.10.4 release commit `86214551` (tag `v26.10.4`) |
| self-declared version | `26.10.5` (mix.exs:29) |
| TCK standing | committed verdict: 235/30/0, 79.0% compatibility (b6b79dea), deflake fixes (07180bd3) |
| dirty state | only untracked `docs/thesis/`; no source dirty |

## 2. Standing (real evidence, witnessed)

- **ALIVE (protocol core)**: `lib/ash_a2a/protocol/` wire codec + `AshA2A.Protocol.Plug`
  (JSON-RPC 2.0 over POST, SSE message/stream (A2A v1 wire method served by the ash_a2a dependency), agent card at
  `GET /.well-known/agent-card.json`), gRPC binding `AshA2A.Transport.GRPC.Server`
  (`lf.a2a.v1.A2AService`, 9 unary + 2 server-streaming RPCs) —
  contract documented in `docs/reference/a2a-endpoint-contract.md`.
- **PARTIAL_ALIVE (TCK)**: TCK verdict 235/30/0, 79.0% committed at `b6b79dea`
  (`docs/reference/a2a-v1-conformance.md`). 79.0% — 30 remaining failures, not CONFORMANT.
- **ALIVE (courts)**: conference_sim suite (61-commit delta: EV1–EV16 courts —
  red-team, interop, SSE multitrack, push lifecycle, OCEL observability, load,
  governance) all landing on the real plug pipeline over `AshA2A.Protocol.Plug`.
- **ALIVE (CI)**: AGNTCon court suite wired into CI (d2f05303).

## 3. Consumer-side state (the actual fleet-wiring gap)

### xaas
- `mix.exs:103-105` pins `ash_a2a` by **git ref `3325032d`** — the 26.9.8-era
  hardening ref, **61+ commits behind** the branch head. `mix.lock:7` confirms.
- xaas does **not** mount the ash_a2a surface at all. `/a2a` scope in
  `lib/xaas_web/router.ex:193-209` mounts the **hex `a2a` 0.2.0 package's** `A2A.Plug`
  (`A2A.Plug`, `A2A.Agent` behaviour — see `XaasWeb.A2A.NextReadUserAgent`
  `use A2A.Agent` and `XaasWeb.A2A.ZoeEventPlug`) — a *different, older protocol
  implementation* than ash_a2a's `AshA2A.Protocol.Plug`.
- Playwright is installed (`package.json` `@playwright/test ^1.62.1`,
  `playwright.config.cjs` webServer `http://localhost:4000`, testDir `./e2e`) but
  **zero e2e specs touch `/a2a`** (e2e/ contains smoke, marketplace, admin, ml, wd-fa-cs2).

### ash_surface
- `mix.exs:133` consumes ash_a2a as a **Hex `~> 26.9`, `runtime: false`** dep —
  compile-time only (dialyzer plt_add_apps), no runtime protocol surface mounted,
  no card, no transport. Effectively not fleet-wired at runtime.

## 4. Standing summary

| capability | standing | evidence |
|---|---|---|
| ash_a2a protocol core (HTTP+SSE+gRPC) | ALIVE | courts + TCK verdict doc + CI |
| TCK conformance | PARTIAL_ALIVE | 79.0%, 30 open failures committed b6b79dea |
| fleet runtime wiring (xaas) | **BLOCKED** | wrong pin (3325032d) + wrong surface (hex `a2a` Plug mounted, not `AshA2A.Protocol.Plug`) |
| fleet runtime wiring (ash_surface) | **BLOCKED** | hex `~> 26.9` runtime:false — compile-time only |
| Playwright E2E validation of a2a | **GAP** | 0 specs hit `/a2a` |

## 5. Proposed edits (exact)

### A. Pin alignment (X4 seam owner executes)
1. `/Users/sac/xaas/mix.exs:103-105`: git ref `3325032d...` → `07180bd3...`
   (full SHA `07180bd3...` — coordinator resolves exact full SHA at integration;
   full sha: `git -C /Users/sac/ash_a2a rev-parse 07180bd3`).
2. `mix.lock` regen (`mix deps.update ash_a2a` under pinned toolchain).

### B. xaas: mount the real ash_a2a surface (coordinator seam, router.ex)
3. `/Users/sac/xaas/lib/xaas_web/router.ex:206-209`: replace the `A2A.Plug` forward
   with `AshA2A.Protocol.Plug, agent: <adapter>, base_url: ...` **or** mount alongside
   at `/a2a/v1` — recommended: **additive mount at `/a2a/v1`** (no breaking change to
   existing Next Read / Zoe consumers), pipe_through `[:api, :require_internal_api_token]`.
4. New file `lib/xaas_web/a2a/next_read_ash_agent.ex`: adapter implementing
   `AshA2A.Protocol.Agent` behaviour (`@callback agent_card/0`,
   `handle_message/2`, `handle_cancel/1` — `lib/ash_a2a/protocol/agent.ex:203-213`),
   delegating to `XaasWeb.A2A.NextReadUserAgentSkills` so both plugs share one skill
   surface. This is the irreducible hand-written residue (adapter between two agent
   behaviours); no generator applies.
5. Mix env: ash_a2a is an all-env git dep in xaas already — no dep-shape change.

### C. ash_surface: runtime surface
6. `/Users/sac/ash_surface/mix.exs:133`: `runtime: false` → `true` (or a dedicated
   `AshSurface.A2A` bridge module mounting `AshA2A.Protocol.Plug` on the
   ash_surface router, gated by app env `:ash_surface, :a2a_enabled`).
7. New `lib/ash_surface/a2a_bridge.ex`: mounts `AshA2A.Protocol.Plug` with an agent
   module exposing ash_surface's capability surface as the agent card skills list.

### D. Playwright E2E (xaas e2e/, lane X1 seam)
8. New spec `e2e/a2a-v1.spec.cjs`:
   - `GET /a2a/v1/.well-known/agent-card.json` → 200, `protocolVersion: "1.0"`,
     name/skills present, `capabilityIndex`/extensions fields per endpoint contract.
   - `POST /a2a/v1` JSON-RPC `message/send` → 200, result.task, happy path.
   - `POST /a2e/v1` malformed JSON → JSON-RPC -32700.
   - `POST /a2a/v1` with bad token → 401 (auth floor holds through the mount).
   - `GET /a2a/v1/.well-known/agent-card.json` wrong method (POST) → 405 Allow: GET.
   - SSE message/stream smoke: open stream, ≥1 frame, close.
   - A2A base URL env: `A2A_BASE_URL` already honored in router.ex:203/208 — extend to the new mount.
9. Wire spec into `playwright.config.cjs` projects if a project split exists;
   otherwise runs under the default project.

## 6. Verification ladder (falsifiers)

1. `cd /Users/sac/xaas && mix compile` (MIX_ENV=dev, pinned toolchain) — 0 errors.
2. `mix test test/xaas_web/` — no regression from the router seam.
3. `MIX_ENV=dev INTERNAL_API_TOKEN=<token> mix phx.server` + `npx playwright test e2e/a2a-v1.spec.cjs` — all green = a2a surface ALIVE on xaas.
4. ash_a2a side unchanged: `git -C /Users/sac/ash_a2a status` — no mutations (this lane is read-only).
5. ash_surface compile + its own test suite after the runtime flip.

## 7. Risks

- **Behaviour mismatch**: `A2A.Agent` (hex) vs `AshA2A.Protocol.Agent` callbacks differ
  (message shape `AshA2A.Protocol.Message` struct vs hex a2a's types). Adapter (edit #4)
  is mandatory; direct swap would break Zoe/Next Read at runtime.
- **Auth-pipeline assumptions**: hex `A2A.Plug` sits behind `:require_internal_api_token`;
  `AshA2A.Protocol.Plug` has its own auth (`AshA2A.Protocol.Plug.Auth.get_identity/1`).
  Two auth layers stacked can 401 twice or bypass the token gate — needs an explicit
  decision: keep token gate + bare protocol plug (its Auth sees no identity → check
  behavior), or pass identity through. Highest-risk edit; court before integration.
- **Card `base_url`** must be absolute at runtime (endpoint contract: nil `base_url`
  raises ArgumentError; card builder defaults to `http://localhost:4000`) — set
  `A2B_BASE_URL` env in playwright webServer config.
- **Mix env leaks**: ash_a2a requires stream_data/igniter in every env (per ash_surface
  mix.exs comments) — flipping `runtime: true` in ash_surface must not narrow deps.
- **61-commit pin jump**: 26.9.8 → 26.10.5 is a large jump; changelog/regression risk on
  xaas compile. Compile court after pin bump before any router edit.
- **Untracked `docs/thesis/` and 50+ `_build-*` lane roots** in ash_a2a — cleanup is a
  separate admitted transition; not this lane.

## 8. Handoff to coordinator

- Seam lines for mix.exs/router.ex/ash_surface mix.exs are in §5 edits 1, 3, 6.
- New files (adapter, ash_surface bridge, playwright spec) are per-lane-owned content
  but live in seam-adjacent dirs (`lib/xaas_web/a2a/`, `e2e/`) — coordinator places them.
- Playwright spec inventory is X1's surface; R4 defers spec-count claims to X1.
- Falsifier for the lane: `e2e/a2a-v1.spec.cjs` green against a server running the
  pinned `07180bd3` ash_a2a. Until then fleet wiring of a2a = **BLOCKED (pin + surface)**.
