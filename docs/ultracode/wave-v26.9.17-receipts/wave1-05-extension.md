# Wave 1 / Agent 5 — ZCode extension & config surface for reaching XaaS Ultracode

Scope: read-only mapping of how a running ZCode agent gets durable, configured access to XaaS/Ultracode. All tokens redacted. Evidence gathered 2026-09-16.

## 0. Headline finding: the connection ALREADY EXISTS in user config

`~/.zcode/cli/config.json` already registers XaaS for **every session** (user scope):

- `:89-98` — `mcp.servers."xaas-execution"`: `{ "type": "http", "url": "http://localhost:4000/internal-api/execution/mcp", "headers": { "Authorization": "***REDACTED***" } }`
- `:100-105` — `plugins.enabledPlugins."xaas-fabric@xaas-fabric-marketplace": true`
- `:138-154` — `hooks.enabled: true` with all seven event arrays present (currently empty)

Live check (no auth sent, read-only): `localhost:4000` is LISTENING; `GET /internal-api/execution/mcp` returns **HTTP 401** — endpoint exists, requires the bearer token.

A full **xaas-fabric plugin** is already checked out at
`~/.zcode/cli/plugins/marketplaces/xaas-fabric-marketplace/xaas-zcode-plugin/` with:
- `.zcode-plugin/plugin.json` — `name: xaas-fabric`, version 26.8.21
- `.mcp.json` — same `xaas-execution` server but token via `"Bearer ${ZCODE_XAAS_TOKEN}"`
- `hooks/hooks.json` — SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, PostToolUseFailure, Stop (all `node "${CLAUDE_PLUGIN_ROOT}/hooks/*.mjs"`)
- `hooks/xaas_common.mjs` — fail-closed admission court; token from env `ZCODE_XAAS_TOKEN`, never from the rendered tree
- `commands/xaas.md` — the `/xaas` slash command (claim_next → save lease → execute → verify → close_candidate)
- `skills/xaas-worker/SKILL.md` — worker doctrine skill
- `agents/xaas-worker.md` — subagent

So agent 5's answer is largely "wire already exists; here is its exact shape, gaps, and pitfalls."

## 1. Registering an MCP server exposing Ultracode (user scope)

Mechanism (zcode-configuration-guide SKILL.md:21-22, :32; diagnosing-mcp SKILL.md:97): user-scope servers live in `~/.zcode/cli/config.json` under `mcp.servers.<name>`. Fallback `~/.agents/mcp.json` → top-level `mcpServers` (compat only; `.zcode` wins within a scope — config guide :37).

Transport shapes (diagnosing-mcp SKILL.md:30-33):
- `stdio`: requires `command` (string); optional `args[]` (array of strings), `cwd`, `env` (object), `enabled`, `timeoutMs`
- `http` / `sse`: requires `url`; optional `headers`, `enabled`, `timeoutMs`
- `type` inferred if omitted (`command`→stdio, `url`→http); schema is strict — unknown keys silently drop the server (:77)

Example — stdio Ultracode server (user scope, every session):
```json
// ~/.zcode/cli/config.json (excerpt)
{
  "mcp": {
    "servers": {
      "ultracode": {
        "type": "stdio",
        "command": "/Users/sac/xaas/scripts/ultracode_mcp.sh",
        "args": [],
        "env": { "XAAS_URL": "http://localhost:4000" },
        "timeoutMs": 60000
      }
    }
  }
}
```
HTTP form is what already ships: see `xaas-execution` above (config.json:91-97). Tools appear to the model as `mcp__xaas-execution__<tool>` (bundle naming; diagnosing-mcp :94).

Pitfall (diagnosing-mcp :35): **`${...}` template expansion happens ONLY for plugin-provided MCP servers** (`${CLAUDE_PLUGIN_ROOT}`, `${ZCODE_PLUGIN_ROOT}`, `${user_config.KEY}`). Config-file servers do NOT expand templates — that is why the user config holds a literal token while the plugin's `.mcp.json` can use `${ZCODE_XAAS_TOKEN}`. Default connect timeout 30000 ms; raise via `timeoutMs` (:36, :79).

## 2. Skill / slash command to drive Ultracode

Skills (diagnosing-skills SKILL.md:25-31): a directory with `SKILL.md`. Frontmatter = flat `key: value` block; recognized keys `name`, `description`, `when_to_use`, `license`, `metadata`. **Load is dropped if `name` or `description` missing, or `description` > 1024 chars.** Triggering is model-decided from `description`/`when_to_use` (first ~250 chars surfaced) — no keyword matcher. Locations, first-match-wins (config guide :51-60): explicit roots (`skills.roots`, config.json:109-114 currently `[]`) → `~/.zcode/skills/` (does not exist yet) → `~/.agents/skills/` → workspace `.zcode/skills/` (cwd up to repo root, every level) → workspace `.agents/skills/` → plugin roots.

Commands (config guide :31, :63): a `.md` file; frontmatter needs `description`, optional `argument-hint`; nested dirs colon-join (`review/code.md` → `/review:code`). First normalized-name match wins; user scope overrides workspace. Locations mirror skills (`~/.zcode/commands/` etc.; does not exist yet).

Concrete prior art — the plugin already ships both:
- `commands/xaas.md:1-4` — `description: Claim and execute one admitted XaaS work contract…`, `argument-hint: [work-id]`; body scripts the 6-step claim/lease/execute/verify/close loop against `xaas-execution` MCP tools (`claim_next`, `heartbeat`, `close_candidate`, `refuse`).
- `skills/xaas-worker/SKILL.md:1-4` — `name: xaas-worker` + trigger description.

A thinner `/ultracode` query command would be `~/.zcode/commands/ultracode.md` (user scope) with the same two-line frontmatter, body instructing the agent to call `mcp__xaas-execution__*` tools. Plugins' commands (like the existing `/xaas`) are already visible in every session while `xaas-fabric@xaas-fabric-marketplace` stays enabled (config.json:104).

## 3. Hooks surface (sync Ultracode state on session start / tool use)

Yes. Two sources (diagnosing-hooks SKILL.md:14-15):
- Config-file hooks: `hooks` key in `~/.zcode/cli/config.json` (or workspace `<repo>/.zcode/config.json`), shape `{ enabled?, timeoutMs?, maxOutputBytes?, events: { <Event>: [ { matcher?, hooks: [...] } ] } }`. **Disabled by default — must set `hooks.enabled: true`.** (This install already has `hooks.enabled: true`, config.json:138-154.)
- Plugin hooks: `hooks/hooks.json` in the plugin; appended after config matchers; any plugin hook auto-enables the runner (why the existing install works).

Exactly seven events (config guide :72): `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PermissionRequest`, `PostToolUse`, `PostToolUseFailure`, `Stop`. Matcher = case-sensitive regex on tool name for tool events; omitted = match all (:27-31). `type:"command"` (shell string; `timeout` in **seconds**) vs `type:"process"` (`command`+`args[]`, `timeoutMs` ms; most portable) (:32-33). Template vars in command/args and env: `${ZCODE_PROJECT_DIR}`, `${ZCODE_SESSION_ID}`; plugin hooks additionally get `${ZCODE_PLUGIN_ROOT}` (:35).

Example (config-file, would need `enabled:true` already set):
```json
{ "hooks": { "enabled": true, "events": { "SessionStart": [
  { "hooks": [ { "type": "process", "command": "node",
                 "args": ["/Users/sac/xaas/scripts/ultracode_sync.mjs"],
                 "timeoutMs": 5000 } ] }
] } } }
```
The xaas plugin already does this end-to-end via `hooks/hooks.json` + `xaas_common.mjs` (POSTs to `http://localhost:4000/internal-api/execution/hooks/<event>` with bearer from `ZCODE_XAAS_TOKEN`; admission paths fail closed to deny, observations best-effort).

## 4. How zcode spawns MCP servers / what an XaaS-side server must implement

The engine is the bundled `vendor/zcode.cjs` (12.6 MB, official MCP SDK):
- `vendor/zcode.cjs:~11933259` — `protocolVersion:"2026-07-28"` — the negotiated MCP protocol revision.
- `StdioClientTransport` (2 refs) — stdio servers are spawned as child processes (`command`+`args`+`env`, stdio piped); HTTP/SSE servers use the SDK's streamable-HTTP client (bundle shows reconnection scheduler, retry, per-request streams).
- Transports in bundle: `type:"stdio"`, `type:"http"`, `"sse"`; schema strict.

XaaS-side server contract:
- stdio: speak MCP over stdin/stdout (JSON-RPC, protocol 2026-07-28 negotiable — SDK falls back per spec), respond to `initialize`, `tools/list`, `tools/call`; stderr is captured into the zcode log for debugging (diagnosing-mcp :69).
- http: serve MCP streamable-HTTP at the URL; must accept `Authorization` header (401 observed without it). Existing implementation: Phoenix endpoint at `http://localhost:4000/internal-api/execution/mcp`.
- Startup must complete within `timeoutMs` (default 30000 ms) or the server is marked failed (:79).

## 5. Precedence / pitfalls

- MCP override order for same-named server: **CLI → environment → user → workspace → system defaults**; plugin servers form the base layer (config guide :67, diagnosing-mcp :24). So a user-scope `xaas-execution` (config.json:91) overrides the plugin's `.mcp.json` twin — and it does: the user entry carries the literal token, the plugin entry the `${ZCODE_XAAS_TOKEN}` form.
- All scopes auto-connect and are trusted at session start, including workspace (config guide :68) — only open trusted workspaces.
- Skills/commands: identity is path (skills) / normalized name (commands); **first in discovery order wins**, user scope beats workspace beats plugin (config guide :30-31, :62-63). A `~/.zcode/commands/ultracode.md` would shadow a plugin `/ultracode`.
- Config-file hooks silently no-op without `hooks.enabled: true` (diagnosing-hooks :46); matcher is case-sensitive regex; `timeout` (command) is seconds but `timeoutMs` is ms (:51).
- Skill `description` > 1024 chars = dropped; empty description = discovered but never triggers (:27-31).
- Strict MCP schema: extra keys or mixed field styles silently drop servers (diagnosing-mcp :77; hooks :52).
- Secrets: plugin servers can use `${ZCODE_XAAS_TOKEN}` env expansion; config-file servers cannot — putting a literal bearer in config.json is the current deviation (keep config.json out of any synced/committed tree).

## 6. Recommendation — minimal durable config set for "ZCode talks to Ultracode"

Already 95% in place; the durable set is:
1. **MCP** (exists): `mcp.servers.xaas-execution` in `~/.zcode/cli/config.json:91-97` — every session gets `mcp__xaas-execution__*`. Optional hardening: move the literal token to a plugin-scoped entry or rotate to `${ZCODE_XAAS_TOKEN}` via a thin wrapper plugin, since config-file servers don't expand templates.
2. **Plugin** (exists): `xaas-fabric@xaas-fabric-marketplace` enabled (config.json:104) supplying `/xaas` command, `xaas-worker` skill+agent, and the six-event hook court. Keep this; it is the load-bearing piece (hooks auto-enable via plugin presence).
3. **Hooks** (exists): `hooks.enabled: true` (config.json:138). No further config needed while the plugin ships the hooks.
4. **Gap, optional**: nothing exists at `~/.zcode/skills/` or `~/.zcode/commands/` — if wave work wants a lighter `/ultracode` query command independent of the execution plugin, create `~/.zcode/commands/ultracode.md` (frontmatter: `description`, `argument-hint`) that instructs the agent to call the `mcp__xaas-execution__*` read tools. One file, user scope, zero code.
5. Do NOT duplicate the MCP server at workspace scope — it would be shadowed by the user entry anyway and adds a second trust surface.

## Standing

ALIVE — exact subject: user-scope `xaas-execution` MCP entry (config.json:91-97) + enabled `xaas-fabric` plugin (config.json:104); verified endpoint listening + HTTP 401 challenge in this session; plugin files and all skill/docs evidence read directly.
