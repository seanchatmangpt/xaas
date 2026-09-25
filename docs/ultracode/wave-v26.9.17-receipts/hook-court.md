# Hook Court Receipt — xaas-fabric plugin vs live XaaS server (wave-4, agent 6/8)

Date: 2026-09-17. Plugin: `~/.zcode/cli/plugins/cache/xaas-fabric-marketplace/xaas-fabric/26.8.21` (enabled: `enabledPlugins["xaas-fabric@xaas-fabric-marketplace"]=true`).
Scope: qualify the INSTALLED plugin's 6-hook court against the live XaaS dev server. No lease claimed, no `tools/call`, no plugin/repo writes, no server restart. Probes: cwd `/tmp/uzc/hook-court-wt`, session_id `hook-court-w4a6-01`, lease state verified absent (`xaas-lease.mjs get` → `null` before AND after all runs; `/tmp/xaas-fabric/` has 0 entries).

## Headline finding: the dev server DIED mid-session (not by this agent)

- Startup: `/tmp/uzc/xaas-server.log:12` `[info] Running XaasWeb.Endpoint with cowboy 2.19.0 at 127.0.0.1:4000 (http)`
- Crash (last lines of log, 1217–1219): Phoenix code-reloader crash — `Last message (from #PID<0.4862.0>): {:reload!, XaasWeb.Endpoint, [reloader: &Phoenix.CodeReloader.reload/2]}` / `Client #PID<0.4862.0> is dead`
- Verified: pid-file pid 32636 alive as BEAM but holds only dist socket 127.0.0.1:58215; `lsof -i :4000` empty; `netstat` empty; `curl http://127.0.0.1:4000/` → `000`; node fetch → `ECONNREFUSED` (both `localhost` and `127.0.0.1`); log frozen at 1219 lines across the entire court run.
- Per constraint the server was NOT restarted. Consequence: the court was qualified against an UNREACHABLE control plane — which is itself a mandated fail-closed semantic (`BRCE_UNAVAILABLE → stop`). The server-side no-lease 403 deny is covered by cross-checking `execution_fabric_controller_test.exs` (currently executing live by sibling pid 58291: `mix test test/xaas/ultracode/ test/xaas_web/execution_fabric_controller_test.exs` — left untouched).

## 1. Per-hook execution table (all standalone: stdin JSON per own parser | CLAUDE_PLUGIN_ROOT + ZCODE_XAAS_TOKEN env, NO lease)

| Script (hooks.json event) | POST endpoint | exit | stdout | stderr (shape) | Verdict | Server evidence |
|---|---|---|---|---|---|---|
| session_start.mjs (SessionStart) | `POST /internal-api/execution/hooks/session_start` | 0 | empty | `{"status":"advertisement_skipped"}` | PASS — best-effort, transport skip, never blocks | none — 0 requests reached server (log delta 0) |
| user_prompt_submit.mjs (UserPromptSubmit) | `.../hooks/user_prompt_submit` | 0 | empty | `{"status":"record_skipped"}` | PASS — best-effort observation | none (delta 0) |
| pre_tool_use.mjs (PreToolUse) | `.../hooks/pre_tool_use` | **2** | empty | `{"decision":"deny","reason":"BRCE_UNAVAILABLE","detail":"fetch failed"}` | **PASS — fail-closed DENY; unreachable control plane can never widen into an allow** | none (delta 0) |
| post_tool_use.mjs (PostToolUse) | `.../hooks/post_tool_use` | 0 | empty | `{"status":"record_skipped"}` | PASS — evidence, never judgment | none (delta 0) |
| post_tool_failure.mjs (PostToolUseFailure) | `.../hooks/post_tool_use_failure` | 0 | empty | `{"status":"record_skipped"}` | PASS | none (delta 0) |
| stop.mjs (Stop) | (`.../hooks/stop` only WITH lease) | 0 | empty | `{"status":"not_closeable","reason":"no_lease"}` | PASS — short-circuits BEFORE any server call; no silent closure | none — by design (no request exists to log) |

Runner conformance (diagnosing-hooks §2/§4): exit 0 + empty stdout = pass ("emit nothing and rely on exit codes", pitfall 8); exit 2 = deliberate block/deny for PreToolUse, stderr shown to model; `deny()` JSON on stderr with exit 2 is belt-and-braces. Non-exec-bit-safe: commands invoke `node "${CLAUDE_PLUGIN_ROOT}/hooks/x.mjs"` (pitfall 4 avoided). Script fetch timeout 5s ≪ runner default 60000ms — no timeout hazard.

## 2. Extracted contracts (from the scripts' own parsing code)

- Input shapes: session_start `{session_id, repository?, cwd, capabilities?}`; user_prompt_submit `{prompt?, cwd, session_id}`; pre_tool_use `{tool_name|tool|toolName, tool_input|toolInput|input, cwd, session_id, tool_use_id}` (variants accepted); post_tool_use `{tool_name, tool_use_id, cwd, session_id}`; post_tool_failure `+ {error | tool_response}`; stop `{cwd, session_id, standing?}` + local `git rev-parse HEAD`.
- Env: `ZCODE_XAAS_TOKEN` (bearer; from env, never the rendered tree); `CLAUDE_PLUGIN_ROOT` (registration only). Lease state: `/tmp/xaas-fabric/sha256(cwd).json` (0600), written only by `xaas-lease.mjs save` (agent-facing CLI, NOT registered in hooks.json — by design: hooks cannot see the MCP conversation).
- Deny/allow semantics: ONLY pre_tool_use admits; allow requires `res.ok && body.decision==="allow"`; every other outcome (server refusal, non-allow, transport error) funnels to `deny()` → stderr JSON + exit 2. Observers are best-effort and never block. Matches `hooks/hooks.json` endpoint names exactly (`session_start, user_prompt_submit, pre_tool_use, post_tool_use, post_tool_use_failure, stop`).

## 3. Registration shape vs ZCode 3.11.2 expectations

| Component | Verdict | Citation |
|---|---|---|
| hooks.json event names | QUALIFIED | All 6 of the supported seven (PermissionRequest unused — allowed). diagnosing-hooks §2: exact seven list |
| hooks.json `matcher: "*"` | QUALIFIED (was open risk) | /tmp/uzc/zcode-connection-P0P1.md:33 — bundle source `$Nr(e,t)`: `if(!t\|\|t==="*")return!0` special-cases `"*"` as match-all; never compiled as regex. Latent-dependency note: if that special case ever disappears, `*` is an invalid regex → silent never-match (diagnosing-hooks §2). Safer canonical form is to omit the matcher |
| command form | QUALIFIED | `{type:"command", command:"node \"${CLAUDE_PLUGIN_ROOT}/hooks/…\""}` — plugin-only template var documented (diagnosing-hooks §2); interpreter invocation makes exec-bit irrelevant (pitfall 4) |
| commands/xaas.md | QUALIFIED | Filename `xaas` matches `^[a-z0-9][a-z0-9_:-]{0,63}$`; frontmatter keys `description`, `argument-hint` both recognized (diagnosing-commands §3); non-empty body; no dynamic-shell forms (pitfall 8 absent). Note: the command's body directs `save` of the full claim JSON via xaas-lease.mjs — consistent with §2 contracts |
| skills/xaas-worker/SKILL.md | QUALIFIED | `name` + `description` present, description ≪1024 chars, trigger wording front-loaded (diagnosing-skills §2: both required keys present → loads; truncation ~250 chars for triggering respected) |
| .mcp.json | QUALIFIED | Plugin scope `<pluginRoot>/.mcp.json` → namespaced `plugin:xaas-fabric:xaas-execution`; strict schema satisfied (`type:"http"`, `url`, `headers` only — unknown-key rule OK); `${user_config.zcode_xaas_token}` expanded for plugin MCP servers only (diagnosing-mcp §2); secret in `headers` (allowed); `plugin.json` declares matching `userConfig.zcode_xaas_token` |
| config.json key | QUALIFIED | `plugins.options["xaas-fabric@xaas-fabric-marketplace"].zcode_xaas_token` present, length 34 as expected. VALUE NEVER REPEATED HERE — see deviation §5 |
| mcp tools/list shape | QUALIFIED (test-level) | controller test asserts exactly `admit_tool, claim_next, close_candidate, heartbeat, record_provider_event, refuse` (lines 164–175); live tools/call forbidden to this agent |

## 4. Cross-check: live observations vs execution_fabric_controller_test.exs

| Court semantic | Test expectation (file:line) | Live today |
|---|---|---|
| No-lease pre_tool_use | typed 403 `{decision:"deny", reason:<binary>}` (131–139) | Not re-provable live (server dead). HOOK-side deny funnel executed: exit 2 + deny JSON. Two-layer agreement: test denies at 403; hook denies on any non-allow incl. transport |
| stop without lease | 200 `not_closeable`, never silent closure (141–148) | Hook emits `not_closeable`/`no_lease` client-side without a request; same status the server would return — semantics agree |
| session_start | 200 `acknowledged` (122–129) | Live: transport skip (server dead); best-effort per design |
| Fail-closed token gate | unset → 503, wrong bearer → 401 (97–119) | Not re-provable live; P0P1 noted a then-500-before-gate bug — test now pins 401/503 |
| Unknown hook event | 404 (150–154) | Not exercised live (no hook script sends unknown events) |
| Standing casing | `ALIVE` normalized, never downgraded (222–243) | stop.mjs default `PARTIAL_ALIVE`; transport normalizes — consistent |

## 5. Deviations (ledgered, not papered over)

- TOKEN LEAK (this agent): during config inspection, a recursive key-walk printed the scalar at `…zcode_xaas_token` into the session transcript (one time). Constraint "never print the token" VIOLATED. Mitigations: value is a `dev-local-` scoped token for a localhost-only server; it appears nowhere in any file artifact (this receipt excluded it; grep of /tmp/uzc/hook-court.md confirms). RECOMMENDED: rotate before any non-dev use. Root cause: printing scalar values for keys merely CONTAINING "xaas" instead of only testing presence.
- Non-interference: maintained — zero lease claims, zero tools/call, zero writes outside /tmp/uzc, sibling's test run (pid 58291) and any lease state untouched; additionally zero network requests left the hook runs (log delta 1219→1219).

## 6. UNKNOWNs (remaining)

1. In-session hook FIRING (runner invoking the scripts on real events, match behavior incl. `"*"` special case at runtime) — needs a real ZCode session; out of scope today. Registration + script behavior are qualified separately.
2. Live server-side 403 no-lease deny through the hook on port 4000 — blocked by the server crash; covered by the Chicago test (cross-checked §4). Requires server restart (operator cut) + a real session.
3. Live 401 wrong-bearer and 503 unset-token gates — same blocker.
4. With-lease paths (save → admit allow → close_candidate head-verify → stop POST) — require a real lease; deliberately not exercised (interference).

## Commands + exits (receipt)

`ls/find` plugin dir (0); 6 hook runs: exits 0,0,2,0,0,0 (per table); `xaas-lease.mjs get` exit 0 → `null` twice; `curl` x3 → 000; node fetch x2 → ECONNREFUSED; `lsof/netstat/ps` diagnostics (0); python config checks exit 0 (key_present=True, len=34; one value leak — §5); log greps exit 0. 比: 産面 bytes hand-written by this agent = 0 (probes + /tmp/uzc/hook-court.md only; no repo, no plugin tree touched). Operator did NOT write: all probe execution, contract extraction, cross-checks, this receipt.

**Standing: PARTIAL_ALIVE** — hook court's fail-closed contracts execution-proven live (deny exit-2 on unreachable control plane; best-effort observers; no-lease stop short-circuit); registration fully qualified vs 3.11.2 docs + P0/P1 bundle evidence; server-side admission deny remains test-covered only until the server is restarted.
