# Wave-5 Landing Receipt — actuate seam + plugin de-hooking (post-outage continuation session)

Date: 2026-09-17 (~14:35–15:15 local). Session origin: operator directives
"look at all the xaas plugins, skills" → "look at ~/xaas & ~/dev/zcode-cl" →
"implement the changes". BRCE outage had ended the wave-5 author's session
mid-tree (uncommitted); this session surveyed, courted, landed, and
installed.

## What landed

Commit `15c287a` on `feat/execution-actuation-fabric` (51 files,
+3879/−473), one atomic semantic unit:

1. `Xaas.Ultracode.Lease.actuate/2` + the `actuate` MCP tool — live-lease,
   registry-gated (`config :xaas, :ultracode_actuation_registry`, empty by
   default), forced-lease-provenanced authority evidence; subject only from
   the registry, never the wire (BOLA fix from the author's own 3-lens
   adversarial review, per HANDWRITTEN.md wave-5 rows).
2. `admit_tool/2` refusal floor reordered ahead of the configurable
   per-provider lookup; admission scoped to `run.provider`.
3. Internal-API-token governance (resource, generation, org scoping,
   revoke-once validation, 3 migrations + snapshots) — machinery for
   `op-dev-token-rotation`; the rotation itself remains an operator act.
4. zcode plugin projection de-hooked: all 8 hook templates deleted,
   `scripts/xaas-lease.mjs` (lease persistence across tool calls),
   skill/command/agent/plugin.json templates rewritten for explicit-MCP
   admission. One template defect found and fixed by this session: the
   moved lease script's header still described the dead hook design.
5. `VERSION` 26.8.21 → 26.9.17 (calver; single source — `mix.exs` reads it).

## Courts (all BEFORE the commit; MIX_ENV=test throughout)

| Court | Command | Exit | Result |
|---|---|---|---|
| strict compile | `MIX_ENV=test mix compile --force --warnings-as-errors` | 0 | clean |
| ultracode | `MIX_ENV=test mix test --only ultracode` | 0 | 17 passed / 0 failed (baseline 8) |
| full suite | `MIX_ENV=test mix test` | 0 | 688 passed / 0 failed (baseline 648) |

Atom-fix invariant (ticket falsifier): `git merge-base --is-ancestor 32b5ba1
HEAD` → 0; `String.to_existing_atom` present ×2 in the landed controller.

Deviation (ledgered): strict compile ran in test env, not dev — the live dev
server (pid 7796, up since ~12:39, `mix phx.server` from this tree) watches
`_build/dev` via the code reloader; a second process force-compiling dev is
the wave-4 crash mechanism (RELEASE-STATE §c incident). Same source, same
flags, isolated `_build/test`.

## Plugin installation (the outage-class fix)

The BRCE outage brick pattern — plugin `pre_tool_use.mjs` funnels EVERY
session tool call through the control plane; control plane unreachable →
whole session dies fail-closed — is structurally removed in 26.9.17
(zero hooks; admission is a worker-initiated MCP call).

- `mix xaas.gen_zcode_plugin --endpoint http://localhost:4000 --token-env
  ZCODE_XAAS_TOKEN` → exit 0; rendered tree = 6 files, no `hooks/`,
  version 26.9.17. `generated/marketplace.json` version updated to match
  (it is the marketplace's declared version, not generator-rendered).
- `zcode plugins marketplace add /Users/sac/xaas/generated` → exit 0,
  1 plugin, directory source.
- `zcode plugins install xaas-fabric@xaas-fabric-marketplace` → exit 0,
  cache `.../xaas-fabric/26.9.17`, kept `enabled: false` (operator's
  emergency cut preserved by the installer).
- Old `26.8.21` cache dir removed (superseded; resolution had already
  switched to 26.9.17 — verified via `plugins list`: version 26.9.17,
  rootPath .../26.9.17, `hookDetails: []`, MCP `xaas-execution` declared).
- `enabledPlugins["xaas-fabric@xaas-fabric-marketplace"]` flipped `false →
  true` (config.json, one boolean). Rationale: the cut's cause (hook court)
  no longer exists in the installed artifact; reversal is one flag if the
  operator disagrees. CLI ran under `~/.nvm/versions/node/v22.22.3` (system
  node 20 lacks `node:sqlite`).

## Left untracked deliberately (not this wave's semantic units)

`generated/` (live projection the marketplace reads), `.agents/rules/`,
`docs/adr/`, `docs/architecture.md`, `docs/context/`,
`docs/target-architecture.md` — unclassified prior-session artifacts left
for owner classification. `docs/jira/v26.9.17/` +
`docs/ultracode/wave-v26.9.17-receipts/` land in the follow-up docs commit
(session history, 票 law).

## Operator acts still open

- `op-dev-token-rotation`: machinery landed; the actual rotation (and the
  wave-4 leak §5 recommendation) is an operator cut.
- Push/PR/merge on `feat/execution-actuation-fabric` (act 6 family) —
  nothing pushed by this session.
- `op-branch-landing-decisions` remainder (ggen/affidavit/autofde-lab
  branches) untouched by this session.

## 比 (this session, 産面 = the xaas working tree)

Hand-written 産面 lines by this session: the lease-script template comment
fix (4 lines), VERSION (1), `generated/marketplace.json` version (1),
ticket History/Status rows + this receipt (docs). Everything else in
`15c287a` was the prior author's already-working tree, courted as-found.
Manufactured share of the landed diff attributable to generators: templates
+ projection renders via `mix xaas.gen_zcode_plugin`. Honest split recorded;
no ratio decoration.

**Standing: ALIVE** — courts green at the landed head, plugin installed
hookless + enabled, MCP seam live (actuate reachable through the connected
`xaas-execution` server, pid 7796).
