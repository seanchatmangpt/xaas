# wave1-07: prior-art discovery — XaaS Ultracode ↔ ZCode connection

Read-only sweep 2026-09-16. Marketplace located at `/Users/sac/ggen-marketplace` (`~/.ggen-marketplace` does not exist). `/Users/sac/xaas/ggen.toml` vendors ontology from `packs/xaas-ash-core-pack/ontology.ttl`; no marketplace path config needed.

## 1. Connection prior art, per side

### XaaS side (all verified)

| Artifact | Path | Verdict |
|---|---|---|
| ZCode plugin EEx templates (14 files: plugin.json, hooks.json + 7 hook .mjs, .mcp.json, command, skill, agent) | `/Users/sac/xaas/priv/templates/zcode_plugin/` | **reusable** — full plugin topology already projected |
| Plugin projection generator (`mix xaas.gen_zcode_plugin`) | `/Users/sac/xaas/lib/mix/tasks/xaas.gen_zcode_plugin.ex:1-98` | **reusable** — becomes the pack's render step (HANDWRITTEN.md:16) |
| Rendered plugin `xaas-fabric` v26.8.21 + local marketplace manifest | `/Users/sac/xaas/generated/xaas-zcode-plugin/`, `/Users/sac/xaas/generated/marketplace.json` | **partial** — rendered but unqualified against live ZCode |
| MCP JSON-RPC + hook HTTP transport (claim_next, heartbeat, admit_tool, record_provider_event, close_candidate, refuse) | `/Users/sac/xaas/lib/xaas_web/controllers/execution_fabric_controller.ex` | **reusable** — the server-side seam |
| ActuationLease kernel (claim/admit/close over Run/Epoch/Receipt) | `/Users/sac/xaas/lib/xaas/ultracode/lease.ex` (307 lines) | **reusable** — admission court semantics |
| Ultracode epoch loop (Run→Epoch→EpochReactor→Receipt, NextEpoch, MissedEpochs) | `/Users/sac/xaas/lib/xaas/ultracode/{run,epoch,epoch_reactor,next_epoch,missed_epochs,receipt,reactor}.ex` | **reusable** — the thing being connected; proven in-process (docs/ultracode/PROGRESS.md) |
| Target milestone: `ClaudeRoutine → XaaS.Ultracode.Run`, invariant `Remove(ClaudeCode) ⇒ Behavior(Ultracode) = Unchanged` | `/Users/sac/xaas/docs/ultracode/c4-architecture.md:17,20,25` | **prior art (law)** — Claude hourly routine is explicitly bootstrap/migration infrastructure to be deleted |

### ZCode side

| Artifact | Path | Verdict |
|---|---|---|
| grep `xaas\|ultracode` in `src/ docs/ test/` | zero hits | **none** — no CLI-source prior art |
| Plugin **enabled in live config**: `plugins.enabledPlugins = {"xaas-fabric@xaas-fabric-marketplace": true}`; `xaas-execution` string also present (mcp section) | `/Users/sac/.zcode/cli/config.json` (key paths only inspected; no secret values printed) | **partial** — registration exists; qualification (do hooks fire?) unproven |
| ZCode version | `/Users/sac/dev/zcode-cli/package.json` → `3.11.2-25` | matches HANDWRITTEN.md's qualification target "ZCode 3.11.2" |
| Hook event names (`SessionStart`/`PreToolUse`/...) in CLI docs/src | no hits for those exact names; `docs/CONFIGURATION.md` has no "hook" lines; `docs/HOST_INTEGRATION.md:113` mentions plugins once | **gap** — hook-event-name qualification is a real open falsifier, exactly as the ledger predicts |

### Claude-vs-zcode: how the existing Claude integration expresses itself

- `/Users/sac/xaas/CLAUDE.md` — project instructions (hand-written, NOT in ledger).
- `/Users/sac/xaas/.claude/settings.json` — permissions allow-list + `outputStyle: Proactive` (hand-written, not ledgered).
- `/Users/sac/xaas/skills/xaas-dev/SKILL.md`, `/Users/sac/xaas/skills/xaas-ontology/SKILL.md` — hand-written skills, not ledgered (unledgered hand-writing on the routine surface — note for the ledger owner).
- Hourly Claude cloud routine — bootstrap infra per c4-architecture.md:20.
- **The rendered plugin is the only rendered projection** (templates + generator); its `hooks/hooks.json` still uses `${CLAUDE_PLUGIN_ROOT}` and Claude hook event names — the ZCode-flavor facts (plugin-root expansion variable, event names, `.mcp.json` env-header support) are the unqualified delta, per HANDWRITTEN.md paydown item 1.

## 2. Marketplace ladder verdict

Marketplace-wide grep: `grep -ril "zcode" packs/ ontologies/ ecosystem/` → **0 files**. No admitted pack expresses ZCode plugin topology.

- **REUSE: FAILS.** Failed edge: no pack or ontology mentions "zcode"; nearest packs (`claude-code-pack`, `agent-fleet-isolation-pack`, `governed-runtime-adapter-pack`) have zero ZCode facts.
- **COMPOSE (partial):** `ggen-ecosystem-mcp-surface-pack` (pack.toml: "MCP tool-surface projection ... read/do consequence classification") already named at HANDWRITTEN.md:12 as owner of the transport fact; `agent-fleet-isolation-pack` (worktree/fleet isolation) composes on the worker side; `semantic-manufacture-epoch-pack` owns epoch contract semantics. No combination yields plugin topology.
- **EXTEND:** the MCP-transport edge extends the `ggen-ecosystem-mcp-surface-pack` family (already ledgered). Plugin topology has **no family to extend** — `claude-code-pack` is the nearest neighbor (renders Claude Code Workflow JS harness from RDF, pack.toml version 26.7.19) but it is a different capability family (workflow scripts, not plugin.json/hooks/commands/skills/agents projection); failed edge recorded.
- **INVENT → admit `zcode-plugin-pack`:** already planned at HANDWRITTEN.md:14,16 + paydown plan item 2 (lines 24-26): promote `priv/templates/zcode_plugin/**` + the generator as the pack's render step, gated on live qualification against ZCode 3.11.2 (hook event names, plugin-root variable, .mcp.json env-header support). Admission source = the proven in-repo shape. Also planned: `ultracode-actuation-lease-pack` (HANDWRITTEN.md:10,18, paydown item 3).

**Net verdict: EXTEND `ggen-ecosystem-mcp-surface-pack` for the transport fact + INVENT (admit) `zcode-plugin-pack` for plugin topology** — the ledger already made this decision; the wave should execute the paydown plan, not re-derive it.

## 3. ~/.zcode automations touching xaas

**None.** Evidence:
- `~/.zcode/workspace/default/capacity-ride/log.ndjson`: 0 "xaas" matches; `state.json`: no xaas.
- No automation/cron-named files anywhere under `~/.zcode` (maxdepth 3 find: 0 hits).
- `~/.zcode/cli/config.json` top-level keys: provider, model, modelCatalog, modelStream, permission, storage, network, features, subagents, memory, mcp, plugins, skills, skill, command, logging, ui, toolConcurrency, modelAnomalyGuard, hooks — no automation section; no xaas hook events registered.
- Only incidental doc mentions: `~/.zcode/workspace/default/agile-protocol-specification/` (2 doc files reference xaas; not executable).
- The config.json hit is `xaas-fabric@xaas-fabric-marketplace` under `plugins.enabledPlugins` (plugin registration, not an automation).
