# priv/zcode_plugin — gall-work lease contract

Canonical home of the zcode-cli gall-work lease contract. This directory is the
source; every consumer pins a copy of it and verifies by sha256.

## Canonical contract

- File: `gall-work.contract.json` (this directory)
- Canonical sha256:
  `5515775861807cdd7394ef74b1ee38679dd24279224515178702bb6652a95fc4`
- Verified against this exact checkout: 2026-09-26 (wave v26.9.26)

## Consumer pin locations

The single consumer repo is `/Users/sac/zcode-cli`:

- Runtime consumer: `/Users/sac/zcode-cli/src/gall-work.ts` (xaas claim → close
  lease lifecycle; drives the contract's verbs)
- Pinned fixture: `/Users/sac/zcode-cli/test/fixtures/gall-work.contract.json`
  (byte-identical copy of the canonical file above)

Per `/Users/sac/zcode-cli/AGENTS.md`, the fixture is contractually
byte-identical to this file, sha256-pinned in both repos.

## Sync procedure

1. Byte-copy the canonical file over the consumer fixture:
   `cp /Users/sac/xaas/priv/zcode_plugin/gall-work.contract.json \
       /Users/sac/zcode-cli/test/fixtures/gall-work.contract.json`
2. Sha-verify BOTH sides after the copy:
   `shasum -a 256 /Users/sac/xaas/priv/zcode_plugin/gall-work.contract.json \
                  /Users/sac/zcode-cli/test/fixtures/gall-work.contract.json`
   Both lines must print `5515775861807cdd7394ef74b1ee38679dd24279224515178702bb6652a95fc4`.
3. Any mismatch is drift: the copy is stale or corrupt — redo the byte-copy, do
   not hand-edit either side.

Never regenerate the contract by hand-editing. The contract is authored here
(ggen/ontology side); consumers only receive projections.

## Drift notice — RESOLVED 2026-09-26 (wave v26.9.26)

The drift ran the opposite way from what an earlier revision of this file
assumed: the consumer fixture in zcode-cli held the NEWER contract (provider
selection, capability discovery handshake/degrade, idempotency_key,
origin_authority), while this owning-repo copy was the stale one
(`390c9a3b…0f6a`). Repair forwarded the contract here: the owning copy was
byte-replaced from the consumer fixture and both sides now hash
`5515775861807cdd7394ef74b1ee38679dd24279224515178702bb6652a95fc4`
(dual sha-verify witnessed 2026-09-26). Byte-identity: ALIVE. The stale
`390c9a3b` value must not be re-introduced; future contract edits happen
here and flow outward by the procedure above.

## Related surfaces (read-only notes)

- Installed plugin cache (v26.9.17) with the MCP registration + PreToolUse gate:
  `~/.zcode/cli/plugins/cache/xaas-fabric-marketplace/xaas-fabric/26.9.17/`
  (`.mcp.json` registers `mcpServers.xaas-execution` → the internal-api MCP
  endpoint with `Bearer ${user_config.zcode_xaas_token}`; the token VALUE is
  user config and must never be written into any file in this repo.)
- Recovery baseline + upgrade path: see `plugin-src/README.md`.
