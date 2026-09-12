# Innovation Exploration — Cycle Report (v26.9.1 Capstone)

Version: v26.9.1 · Last updated: 2026-08-26

## 1. Top 3 Candidates

### 1. OCEL process-mining resources populated but not exposed via MCP/JSON:API/GraphQL — score 10

- **Location:** `control-plane/lib/chatgpt_cloud_control_plane/process_intelligence/resources.ex:154-208`, `domain.ex:34-58`, `queries.ex:41-46`
- **Scores:** Novelty 2 · Feasibility 5 · Leverage 3
- **Justification:** 8 of 10 domain resources (Agent, Run, Event, Object, EventObject, ObjectObject, Receipt, ConformanceResult, Refusal, ProcessVariant) use `ResourceHelpers` with a bare `:read` action, are populated live by the ingestor, and are already summarized numerically in the LiveView dashboard. Only `Qualification` and `CostObservation` get `json_api` routes, GraphQL queries, and AshAi `tool()` declarations. Wiring `ConformanceResult`/`Refusal`/`ProcessVariant` into `domain.ex`'s `tools` block (mirroring the existing `list_qualifications` pattern) lets an MCP client query real process-conformance evidence, refusal history, and discovered process variants directly instead of only via HTTP-basic-auth-gated AshAdmin. This is mechanical repetition of an established pattern across three resources — no new abstractions, trivially completable in one session — which is why feasibility is 5 despite novelty being only 2.

### 2. SwarmTeam/SwarmWorkItem velocity aggregate exists but has no consumer — score 10

- **Location:** `control-plane/lib/chatgpt_cloud_control_plane/process_intelligence/swarm_team.ex:1-59`
- **Scores:** Novelty 2 · Feasibility 5 · Leverage 3
- **Justification:** A complete, working Ash resource computes team velocity (sum of completed work items' priority, filtered by `status == :completed`) as the typed replacement for swarmsh's `velocity_log.txt`. It is not referenced by `domain.ex`'s `json_api`/`graphql`/`tools` blocks, not queried by any LiveView, and absent from `mcp-tools.md`'s tool table. Wiring it into the MCP tool set or a small LiveView panel converts an already-built schema+aggregate with zero consumers into a working swarm-coordination velocity readout. Bounded, single-session exposure work; no new domain modeling required.

### 3. project_memory_proxy.py exposes memory.query/archive/delete not surfaced as MCP tools — score 10

- **Location:** `scripts/project_memory_proxy.py:25-35` vs `docs/reference/mcp-tools.md` tool table
- **Scores:** Novelty 2 · Feasibility 5 · Leverage 3
- **Justification:** The Python proxy CLI supports `memory.query`, `memory.archive`, and `memory.delete` as allowed operations, but the AshAi MCP tool table only wraps `read`/`upsert`/`snapshot`/`list_project_items` — no `archive_dfcm_memory` or `delete_dfcm_memory` MCP tool, and no `query_dfcm_memory` distinct from `read`'s basic Ash filter. If matching generic actions already exist in the Elixir `DfcmMemory` domain, exposing them as MCP tools closes an agent-ergonomics gap: no more out-of-band CLI drop-down for memory lifecycle management. Bounded — add 2-3 MCP tool wrappers around existing Ash actions/CLI ops, shippable in one session.

## 2. Full Ranked Table

| # | Score | Title | Location | Novelty | Feasibility | Leverage |
|---|-------|-------|----------|---------|--------------|----------|
| 1 | 10 | OCEL process-mining resources populated but not exposed via MCP/JSON:API/GraphQL | control-plane/.../process_intelligence/resources.ex:154-208 | 2 | 5 | 3 |
| 2 | 10 | SwarmTeam/SwarmWorkItem velocity aggregate exists but has no consumer | control-plane/.../process_intelligence/swarm_team.ex:1-59 | 2 | 5 | 3 |
| 3 | 10 | project_memory_proxy.py exposes memory.query/archive/delete not surfaced as MCP tools | scripts/project_memory_proxy.py:25-35 | 2 | 5 | 3 |
| 4 | 10 | rules-crosslink-check: enforce bidirectional See Also links across ~/.claude/rules | ~/.claude/audit-loop/01-rules-contradictions.md, ~/.claude/rules/*.md | 2 | 5 | 3 |
| 5 | 9 | swarmsh-v2 emits OTEL coordination events but never posts to control-plane's OCEL ingest endpoint | vendors/swarmsh-v2, control-plane/.../swarm_agent.ex, ingestor.ex | 2 | 4 | 3 |
| 6 | 9 | Promote hasChildWorkflow/hasParentActivity out of bench-gated path into unconditional G_OCEL module | crates/cng/src/measurement.rs:184-190 | 2 | 4 | 3 |
| 7 | 9 | Refresh stale memory files against current code (increments 1 and 4 already done) | ~/.claude/projects/-Users-sac-praxis/memory/autonomic-recursive-workflow.md, cng-cli.md | 1 | 5 | 3 |
| 8 | 9 | config-drift-sweep: parameterize the 25 hand-run audit-loop passes into one reusable skill | ~/.claude/audit-loop/*.md, ~/.claude/skills/config-audit/ | 2 | 4 | 3 |
| 9 | 8 | swarmsh v1 file-based coordination artifacts never ingested into dfcm_memory | vendors/swarmsh, control-plane/.../dfcm_memory | 2 | 4 | 2 |
| 10 | 8 | Convert one concrete CNG_R05/CNG_R12 refusal into a bounded A/B/C admission with resume | crates/cng/src/runner.rs:319-397, main.rs:929-1075 | 2 | 3 | 3 |
| 11 | 8 | praxis README quickstart has no verified transcript | /Users/sac/praxis/README.md:158-176 | 1 | 5 | 2 |
| 12 | 8 | ggen README has no cargo install / working binary path for the CLI | /Users/sac/ggen/README.md:50 | 1 | 5 | 2 |
| 13 | 8 | clap-noun-verb README pinned to stale pre-announcement version | /Users/sac/clap-noun-verb/README.md:7-33 | 1 | 5 | 2 |
| 14 | 7 | manufacturing ggen/RDF pipeline doesn't ingest swarmsh-v2's semantic-conventions registry | manufacturing/(ontology.ttl, ggen.toml, queries/sources.rq), vendors/swarmsh-v2/semantic-conventions | 2 | 3 | 2 |

## 3. Recommended Next Action

Ship candidate #1 first: wire `ConformanceResult`, `Refusal`, and `ProcessVariant` into `control-plane/lib/chatgpt_cloud_control_plane/process_intelligence/domain.ex`'s `tools` block, copying the existing `list_qualifications` pattern used for `Qualification`/`CostObservation` at `domain.ex:34-58`. Concretely:

1. In `domain.ex`, add three `tool()` declarations (e.g. `list_conformance_results`, `list_refusals`, `list_process_variants`) pointing at each resource's existing `:read` action, matching the argument/filter shape already used for `list_qualifications`.
2. Add matching `json_api` routes and `graphql` queries for the same three resources, mirroring `Qualification`'s block in the same file.
3. Run `mix compile --force` and `mix test`, then verify with a real MCP client call (or `mix test test/xaas/actuation_test.exs`-equivalent for process_intelligence) that `list_conformance_results` returns live ingested data, not an empty set.

This is the highest-leverage/highest-feasibility item among four tied-at-10 candidates because it directly unblocks external MCP-based audit and conformance queries against data that is already flowing through the ingestor today — the smallest gap between "done" and "exposed" in the entire ranked set.
