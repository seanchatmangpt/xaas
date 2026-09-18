# Receipt — zcode↔xaas executor connection, P0+P1 (wave agent 10/10, 2026-09-17)

Base: /Users/sac/xaas @ `feat/execution-actuation-fabric`, parent `fd68647` (unchanged base, no push, no server restart, no lease/hook/tool mutations).

## 1. P0 — committed + re-rendered + synced

**Commit `a11bf7a`** `fix(zcode-plugin): match execution-fabric controller contract` (local only, on the existing branch):
- `priv/templates/zcode_plugin/commands/xaas.md.eex` — close_candidate key `standing`→`outcome`
- `priv/templates/zcode_plugin/hooks/post_tool_failure.mjs.eex` — URL `post_tool_use`→`post_tool_use_failure` + flat body
- `priv/templates/zcode_plugin/hooks/post_tool_use.mjs.eex` — flat body (nested `event:{}` removed)
- `priv/templates/zcode_plugin/hooks/user_prompt_submit.mjs.eex` — flat body
- `priv/templates/zcode_plugin/hooks/xaas-lease.mjs.eex` — lease state 0o600 file in 0o700 dir
- `priv/templates/zcode_plugin/hooks/xaas_common.mjs.eex` — same perms hardening

**Left untouched and uncommitted (incoherent with the template fix, per scope):**
- `M HANDWRITTEN.md` (ledger rows documenting both template AND controller fixes — belongs with the server-side commit)
- `M lib/xaas_web/controllers/execution_fabric_controller.ex` (atom-table DoS fix: `String.to_atom`→`to_existing_atom` on attacker-controlled `refuse` reason)
- `M test/xaas_web/execution_fabric_controller_test.exs` (matching tripwire test)
- Untracked: `.agents/rules/`, `docs/adr/`, `docs/architecture.md`, `docs/context/`, `docs/target-architecture.md`, `generated/`

**Re-render:** serialized on `/tmp/uzc/xaas-mix.lock` (held ~85 min by a sibling's `mix test`; acquired 07:44:58Z, released after). `mix xaas.gen_zcode_plugin --endpoint http://localhost:4000 --token-env ZCODE_XAAS_TOKEN --output generated/xaas-zcode-plugin` → 14 files, `MIX_RC=0`. Token VALUE never rendered or printed (only the env-var NAME).

**Render-freshness proof:** all 14 rendered files diff-empty vs templates under assign substitution (endpoint `http://localhost:4000`, token_env `ZCODE_XAAS_TOKEN`, name `xaas-fabric`, version `26.8.21`). Match RC=0.

**Installed-copy sync:** `rsync -a --delete /Users/sac/xaas/generated/xaas-zcode-plugin/ → ~/.zcode/cli/plugins/marketplaces/xaas-fabric-marketplace/xaas-zcode-plugin/`. Pre-sync drift confirmed installed copy was PRE-fix (nested `event:{}`, wrong failure URL, `standing` key). Post-sync `diff -r` **exit 0** (byte-equal). Spot checks: `post("post_tool_use_failure"`, 0 nested-event occurrences, `mode: 0o700/0o600`, `"outcome"` key.

## 2. P1 — qualification vs ZCode 3.11.2-25 (citations: the three zcode-guide SKILL.md diagnosing-* docs + vendor/zcode.cjs bundle)

| Component | Verdict | Evidence |
|---|---|---|
| Manifest | QUALIFIED (shape) | `.zcode-plugin/plugin.json` is the preferred probe location (diagnosing-plugins §2); `name: xaas-fabric` matches `^[a-z0-9][a-z0-9._-]{0,127}$`; components relative + inside root; `marketplace.json` `{name, pluginRoot, plugins[].source:"./xaas-zcode-plugin"}` is schema-valid |
| Hook event names | QUALIFIED | hooks.json uses exactly `SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, PostToolUseFailure, Stop` — all in the supported seven (diagnosing-hooks §2); `PermissionRequest` unused (allowed) |
| `matcher: "*"` | QUALIFIED (was the open risk) | Bundle `$Nr(e,t)`: `if(!t\|\|t==="*")return!0` — `"*"` is special-cased match-all; simple alnum/pipe strings = literal list; real regex otherwise; invalid regex → never matches (fail-closed). `new RegExp("*")` alone WOULD throw, but the runtime never compiles `"*"` |
| Hook command style | QUALIFIED | `type:"command"`, invoked via `node "${CLAUDE_PLUGIN_ROOT}/hooks/*.mjs"` — interpreter invocation, executable bit irrelevant (diagnosing-hooks pitfall 4); `${CLAUDE_PLUGIN_ROOT}` expanded for plugin hooks (§2 template vars) |
| Plugin `.mcp.json` env-header expansion | QUALIFIED (semantics) | Bundle `Bm(e,t,r)`: `${ZCODE_PLUGIN_ROOT}`/`${CLAUDE_PLUGIN_ROOT}` → rootPath; any `${ZCODE_*}` → `t.env[o]`, missing env throws typed "Missing environment variable" (fail-closed, stronger than silent `Bearer `); `${user_config.*}` gated by `allowSensitive`. So `Bearer ${ZCODE_XAAS_TOKEN}` is valid FOR PLUGIN SERVERS ONLY (diagnosing-mcp §2: config-file servers never expand — why config.json holds a literal) |
| **Plugin discovery/install** | **REFUSED-INPLACE / BLOCKED — the load-bearing finding** | `zcode plugins list` (real CLI, node v22.22.3) shows 8 official plugins; **xaas-fabric is NOT discovered**; `/xaas` absent from `commands list`; no xaas skill in `skills list`. Root cause: discovery of marketplace installs reads `~/.zcode/cli/plugins/installed_plugins.json` (`{version:1, plugins:{id:[{installPath,version,installedAt,scope}]}}`, bundle `rbe/abe/H4o/UA`; default install root = `cache/<marketplace>/<plugin>/<version>`, bundle `tat`) — **that file does not exist on this host**. The marketplace IS registered (`known_marketplaces.json`, source directory `/Users/sac/xaas/generated`) and `enabledPlugins["xaas-fabric@xaas-fabric-marketplace"]=true`, but an enable entry cannot fabricate an install record. The manual file copy is INERT. Repair requires either the real `zcode plugins install` path (BLOCKED by the confirmed 3.11.2-25 install bug, HANDWRITTEN.md:27-33) or a ZCode-side fix; hand-creating installed_plugins.json would fabricate install state — not done |

## 3. P1 — live MCP handshake: BLOCKED (environmental, forbidden repair)

- Token extracted from `~/.zcode/cli/config.json mcp.servers["xaas-execution"].headers.Authorization` into a shell var only (length 41, never printed).
- **No-token POST → HTTP 500** (not 401); **initialize with token → HTTP 500**; **tools/list → HTTP 500**. Zero tool names obtainable.
- Diagnostic preserved (both probes): `** (RuntimeError) could not compile application: xaas. You must restart your server after changing configuration files or your dependencies. In particular: * _build/dev/lib/xaas/.mix/compile.lock` (first probe) / `* config/dev.exs * config/config.exs` (final probe) — `Phoenix.CodeReloader.Server.mix_compile_unless_stale_config/4`, phoenix 1.7.24. Listener: beam.smp PID 40973 on 127.0.0.1:4000.
- Cause: sibling agents' concurrent builds in the same tree stale-keyed the dev server's code reloader. **Restart of :4000 is outside my authority (STOP boundary)** — refusal recorded, not silently worked around. DESIGN.md's 2026-09-16 401-fail-closed and MCP-ALIVE receipts (HANDWRITTEN.md:24-26) predate this breakage; re-receipt must happen post-restart.
- The 6 expected tool names (`claim_next heartbeat admit_tool record_provider_event close_candidate refuse`) remain from controller source + ConnCase tests (execution_fabric_controller.ex:28-96), NOT re-proven live today.

## 4. P1 — CLI probes (non-mutating)

- `--version`: `zcode-app-cli 3.11.2-25`, `zcode-runtime 0.16.5` (bin/zcode.js; requires node ≥22 — v22.22.3 via nvm; system node 20.13.0 lacks `node:sqlite`; bun 1.3.7 fails on `node:sea`).
- `doctor`: clean (node v22.22.3, darwin/arm64, sea:no, node-bundle).
- `plugins list`: 8 official plugins, statuses as configured; **no xaas-fabric** (see §2).
- `commands list`: "No custom commands found." `skills list`: 14, none from xaas.
- No `zcode mcp` CLI subcommand exists; MCP inspection is the `/mcp [list|status|…]` slash command (TUI) + Settings → MCP.

## 5. Still UNKNOWN (honest residue)

1. Live `initialize`/`tools/list` over HTTP with the real token — blocked by the stale dev server (needs operator-authorized restart, then re-probe).
2. Whether runtime (not install-time) `${ZCODE_XAAS_TOKEN}` expansion works for an INSTALLED plugin — moot until an install record exists; the bundle code path says yes (env lookup), but `inspection ≠ execution`.
3. Hook firing end-to-end (PreToolUse court admit/deny against a live lease) — needs discovery fixed + server alive.
4. Whether `zcode plugins install` succeeds for directory-source marketplaces after the ZCode install bug is fixed.
5. The 3 server-side dirty files (controller atom fix + test + ledger) remain uncommitted — their commit is a separate operator-authorized act (they are coherent with each other, not with my template commit).

## 6. What the operator did NOT have to write

Everything in P0: the commit (6 files, conventional message), the render (generator-owned), the sync (rsync + diff gate), all qualification evidence (skill docs + bundle extraction), the probes, this receipt. Hand-written by agents: zero lines of plugin/template/code content. The operator's remaining keystrokes: server restart authority (P1 completion) + the server-side commit (3 files) + eventually the ZCode-side install-bug fix.

## Standing

- P0: **complete and receipted** (commit a11bf7a, template-match RC=0, diff -r exit 0).
- P1: **PARTIAL_ALIVE** — qualification verdicts delivered (incl. the installed_plugins.json discovery blocker); live handshake BLOCKED by the stale dev server (restart forbidden in-scope).
- Falsifiers attempted: matcher `"*"` validity (survived — special-cased in bundle); plugin discovery via enabledPlugins alone (FALSIFIED — install record required); fail-closed 401 (not re-provable today — 500 precedes the gate).
