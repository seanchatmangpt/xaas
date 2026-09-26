# plugin-src — xaas-fabric plugin source baseline

Recovery baseline for the installed xaas-fabric plugin. The installed cache is
the projection; this directory records what to restore if the cache is lost or
corrupted.

## Installed snapshot (as observed 2026-09-26)

- Location: `~/.zcode/cli/plugins/cache/xaas-fabric-marketplace/xaas-fabric/26.9.17/`
- Version: `26.9.17`
- Contents: `agents/` (`agents/xaas-worker.md`), `commands/` (`commands/xaas.md`),
  `hooks/` (`hooks/hooks.json`), `scripts/` (`scripts/xaas-gate.mjs`,
  `scripts/xaas-lease.mjs`), `skills/` (`skills/xaas-worker/`),
  `.mcp.json`, `.zcode-plugin/plugin.json`

`.mcp.json` registers `mcpServers.xaas-execution` pointing at the local
internal-api MCP endpoint, authorized with
`Bearer ${user_config.zcode_xaas_token}` (resolved from user config at load —
the token VALUE never appears in any repo file).

## Manifest verbatim — `.zcode-plugin/plugin.json` (v26.9.17 recovery baseline)

```json
{
  "name": "xaas-fabric",
  "version": "26.9.17",
  "description": "XaaS execution-fabric worker plugin: claims receipted work contracts via MCP (claim_next/admit_tool/close_candidate/refuse), closes with head verification, and enforces admission on the host with a PreToolUse gate in dispatcher-launched (XAAS_WORKER=1) sessions.",
  "userConfig": {
    "zcode_xaas_token": {
      "type": "string",
      "sensitive": false,
      "default": "unset",
      "description": "Bearer token for the XaaS internal API (/internal-api). Set with: zcode plugins configure xaas-fabric@<marketplace> --options-file"
    }
  }
}
```

## Upgrade path: 26.9.17 → 26.9.26

The registered marketplace source for the installed cache is currently EMPTY —
there is no in-place upgrade path today. Sequence to reach 26.9.26:

1. Restore/author the marketplace source so a registry entry for xaas-fabric
   exists at version `26.9.26` (source of truth: the local marketplace tree —
   see below). Bump `version` in `plugin.json`, keeping `name`,
   `description`, `userConfig` schema stable unless the fabric verbs change.
2. Re-sync the plugin payloads (`.mcp.json`, `hooks/hooks.json`,
   `scripts/xaas-gate.mjs`, `scripts/xaas-lease.mjs`, `agents/xaas-worker.md`,
   `commands/xaas.md`, `skills/xaas-worker/`) from the source tree.
3. Install/upgrade through the plugin machinery (marketplace → cache), never by
   hand-editing `~/.zcode/cli/plugins/cache/...`.
4. Verify: the installed `.zcode-plugin/plugin.json` reports `26.9.26`, the MCP
   server resolves, and the PreToolUse gate is inert without `XAAS_WORKER=1`
   (denies/defers, never grants, fails closed when active).

If the cache is destroyed: reinstall from the restored marketplace source; use
the manifest above as the recovery baseline for `plugin.json`.

## Marketplace source note

The marketplace source for this plugin lives at `.ggen/marketplace/` (sibling
of this directory, under `priv/zcode_plugin/`). It is currently empty/not
populated and is owned by ANOTHER LANE — this lane does not restore or modify
it. `ggen.lock` / `ggen.toml` beside it pin the ggen projection state.

Never write the bearer token value into any file in this tree; it lives only in
user config (`zcode_xaas_token`).
