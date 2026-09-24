# Engineering Standards Root Binding

> Generated adoption header. Shared engineering semantics are rooted at `seanchatmangpt/engineering-standards@5a3bb6446aeaee2255a7523d4d8cebf6042960c3`.

- Repository subject: `seanchatmangpt/xaas@57c77e7a9bb510d9b10c774ebc32a1cc5b414390`
- Ecosystem role: capability, runtime, delivery, governance, and autonomic consequence orchestration
- Adoption manifest: `engineering-standards.json`
- Project profile: `semantic/engineering-standards-profile.ttl`

The local constitution below remains authoritative for repository-specific mechanics. It may narrow the root but may not redefine shared WorkOrder identity, authority, receipt/replay, generated-artifact sovereignty, or evidence standing. Ticket, agent, capability, plan, proof, and generated output do not acquire ambient DO authority.

---

# xaas Agent Operating Contract

This contract governs the repository unless a deeper `AGENTS.md` narrows a subtree. Live repository evidence outranks stale prose. Nested contracts may add constraints but may not silently weaken safety, evidence, authority, replay, or publication rules.

## Preserve → Fence → Calculus

Resolve repo/ref/base to an exact commit before changing anything. Read all applicable root+nested `AGENTS.md`, `CLAUDE.md`, architecture/Diataxis material, manifests, task runners, CI, generation, and release policy. Preserve interfaces, canonical/generated boundaries, authority, receipts/replay, compatibility, and reversible options. Apply Chesterton's fence before deleting a rule or boundary; replace stale doctrine with a narrower executable rule plus a falsifier.

Model the system in objects/morphisms with explicit admission, closure, authority, actuation, receipt, replay, and standing. Preserve maximal reversible lawful possibilities before irreversible selection. One failed edge is topology, not graph failure.

## Evidence and authority

Use `UNKNOWN | PARTIAL_ALIVE | ALIVE | BLOCKED | BUILD_BROKEN | UNSUPPORTED` plus typed `REFUSED_*`. `ALIVE` requires observed execution against the exact admitted subject. Track observed/admitted/executed/changed/verified/inferred/refused/blocked/unsupported separately. Inspection is not execution; workflow existence is not a successful run; connector visibility is not a mounted tree; receipt-shaped data is not a replay-verified receipt.

```text
A = μ(O*)
R = receipt(A)
```

Separate `SELECT`, `CONSTRUCT`, `DO`. Model/planner/generator/proof/hook output has no ambient execution authority. Hooks manufacture intents, never actuate. Consequential actuation must use the repository's authorized receipt-bearing boundary: zero unreceipted actuation.

## Work and verification

Follow `parse → orient → resolve → materialize → read doctrine → inspect → admit/refuse → diagnose/repair → construct → actuate → receipt → replay/hook → standing`.

Prefer the existing lawful path and smallest coherent bounded diff. Generated artifacts are projections; edit the owning ontology/graph/query/schema/template/generator. Do not fabricate evidence, weaken tests, substitute unit proof for requested integration/e2e proof, add unrelated refactors, or leave unresolved placeholders on a changed production path.

Acceptance precedence: exact user command/behavior → documented repo command → narrowest existing equivalent. Run cheapest high-information gates first, then unit → integration/protocol → e2e → release/qualification as affected. On failure preserve command/exit/diagnostic, form a new hypothesis, repair the narrowest cause, encode a permanent guard, and rerun the failed boundary before expanding. CI supplements local proof; it is not truth.

## GitHub and receipt

Never silently move the admitted base. Use a purpose branch, intentional commit, non-force push, and draft PR; never merge unless explicitly requested. Final receipts expose repo/base/tree, O/O*, transports/failures, μ/changes/generated status, commands/exits, verification ladder, receipt/replay, branch/SHA/PR, scoped standing, and falsifiers.

## Repository-local law — xaas

The live project instruction surface identifies `xaas` as a BEAM/Phoenix/Ash platform whose authoritative domain set is the `ash_domains` list in `config/config.exs` (13 Ash domains as of 2026-09-22 — do not freeze the count here; the config is the source) with explicit platform substitutions documented under `docs/`. `CLAUDE.md` and the referenced Diataxis architecture/reference files are required doctrine, not optional reading.

Testing is Chicago-style: real Postgres through the repository's Ecto sandbox, real Ash actions, and real HTTP requests. Do not introduce interaction-mocking libraries for owned collaborators. Re-run the repository's documented mock-pattern audit after relevant changes.

Ash authorization is deny-by-default. Do not weaken the policy floor mechanically. `/internal-api` and `/api` routes require the real internal token gate and fail closed when it is unset. Financial-ledger resources and auth/PII resources documented as deliberately unwired must remain unwired unless the task includes an explicit access-control design.

Do not freeze volatile commands here: discover and execute the current commands from `CLAUDE.md`, manifests, and CI at the admitted SHA. Claims such as compile, test, server boot, HTTP behavior, or generation require the real run named by the claim.

## Zcode integration (added 2026-09-22)

This repository is the SOURCE of the xaas-fabric zcode plugin. ggen projects `ontology.ttl` + `templates/*.tmpl` → `priv/zcode_plugin/marketplace/xaas-fabric/` (8 files); drift is checked by `test/xaas/zcode_plugin/projection_test.exs`. The installed user-side copy at `~/.zcode/cli/plugins/cache/xaas-fabric-marketplace/xaas-fabric/26.9.17/` was byte-identical as of 2026-09-22. Edit the owning ontology/templates, never the projection.

The execution fabric MCP surface is `POST /internal-api/execution/mcp` (JSON-RPC; 7 verbs: `claim_next`, `heartbeat`, `admit_tool`, `record_provider_event`, `close_candidate`, `refuse`, `actuate`), `POST /internal-api/execution/hooks/:event`, and `GET /internal-api/execution/epochs/:epoch_id/receipts` — all behind `RequireInternalApiToken` (`router.ex:80-112`).

Native dispatch: semantic runs invoke `zcode gall-work --lease <descriptor>`. The contract file `priv/zcode_plugin/gall-work.contract.json` must stay byte-identical to zcode-cli's `test/fixtures/gall-work.contract.json`.

Worker semantics: `XAAS_WORKER=1` arms the plugin PreToolUse gate (`scripts/xaas-gate.mjs`); `XAAS_ALLOW_SUBAGENTS=1` overrides its agent-spawn denial; `XAAS_MCP_URL`/`XAAS_MCP_TOKEN` override endpoints.

Receipt conventions: `docs/ultracode/<wave>-receipts/` directories, `PROGRESS.md` entries, and `standing-ledger.ndjson` hash chains (see `wave-v26.9.19-receipts/semantic-autonomics-crown/`).

Known asymmetry (open work order): `AuditMcpToolCall` covers `/mcp` but NOT `/internal-api/execution/mcp`.