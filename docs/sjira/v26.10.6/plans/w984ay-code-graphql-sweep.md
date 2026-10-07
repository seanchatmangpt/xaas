# W984ay — Code + GraphQL Straggler Sweep (receipt)

- **Lane**: W984ay, xaas v26.10.6, checkout `/Users/sac/xaas`, branch `feat/playwright-surface` @ `5f7f70d9` (dirty tree shared with W984ao's in-flight edits).
- **Standing at write time**: PARTIAL_ALIVE (static sweep OBSERVED/exhaustive; mix census BLOCKED — see Verification).
- **Scope**: check-only. No source edits. No commit.

## Method

Exhaustive grep across `lib/ test/ config/ mix.exs priv/`, patterns
`AshGraphql|Absinthe|absinthe|graphql_schema|"graphql do"|:graphql|graphql`,
case-insensitive, unrestricted file types (second pass; first pass with
`--include=*.ex,*.exs` missed `.eex`). `graphlaw` does NOT match any pattern
(word-boundary verified: `lib/xaas/graphlaw/capability.ex` contains the token
`graphql` only inside a "SPEC-31 deepening" comment; the package name itself
never matched).

## Sweep table (every hit, classified)

**Zero live graphql code surfaces remain**: no `AshGraphql`/`Absinthe`/`ash_graphql`
tokens in lib/ test/ config/ mix.exs (case-insensitive), no `graphql do` DSL
block in any `.ex`/`.exs`, no `:graphql` config key, no `graphql_schema`,
no `Xaas.GraphqlSchema` file, no router scope, no mix.exs dep, no formatter/
credo/alias mention.

| file | hit class | classification |
|---|---|---|
| `priv/packs/xaas_library_pack/templates/manufacture.ex.eex` L92,228,260,454,486,609,644,838,868,974,991 | `AshGraphql.Domain/Resource` in extensions lists + six `graphql do` DSL blocks rendered by the pack template | **(c) STRAGGLER** — the xaas_library_pack template still generates AshGraphql extensions + graphql DSL into every manufactured resource. W984ao's lib/ enumeration cannot see .eex templates. Last touched by 83b43341. |
| `mix.lock` L4,5,17,20,154 | `absinthe`, `absinthe_plug`, `ash_graphql`, ash_money's ash_graphql optional dep, prom_ex's optional absinthe | **(c) STRAGGLER (mechanical)** — deps removed from mix.exs but lockfile not re-resolved. Self-resolves on next `mix deps.get` (prom_ex/ash_money entries are optional-dep listing, legal). Not hand-editable by policy. |
| `lib/xaas/semantics/vkg.ex` L12,65-67 | `alias AshR2RML.VKG.Consumer.{Engineering, GraphQL}` + `def graphql/2` + test `test/xaas/semantics/vkg/integration_test.exs` (`VKG.graphql/2`) | **(b) legitimate non-surface** — AshR2RML VKG read-only projection consumer (dep pinned 0d5320f6), unrelated to the removed SPEC-30 /api/graphql HTTP surface. Not in W984ao's deletion set. |
| `priv/ash_surface/surface_contract.json` | "GraphQL-safe canonical JSON projection..." action description | **(b)** — generated manifest carrying the measurement action's description text; self-resolves on regeneration. |
| `lib/xaas/a2a/agent.ex:17`, `lib/xaas/graphlaw/capability.ex:12`, `lib/xaas/temporal_memory/observation.ex:40,50`, `lib/xaas/coupling/coupling_run.ex:31`, `lib/xaas/generation/projection_record.ex:19` | "SPEC-31 deepening (lane W984l/W983h): real GraphQL read surface." comments | **(c)-lite STRAGGLER (comments only)** — stale comments pointing at the removed SPEC-31 GraphQL read surface on ETS resources; no code behind them (extensions `[]`, no DSL block). Cosmetic deletion set. |
| `lib/xaas/library/book.ex:61`, `lib/xaas/sa2a/execution.ex:24`, `lib/xaas/operations/route_castle_run.ex:6`, `lib/xaas/operations/audit_log_entry.ex:20`, `lib/xaas/operations/project_measure/measurement.ex:12-13,77` | prose/comment mentions ("No route, GraphQL or RPC surface...", "API, GraphQL, show/edit forms", "GraphQL-safe...") | **(b) legitimate prose** — accuracy-preserving doc/comments; keep (they describe surfaces that correctly do not exist). |
| `test/xaas/operations/route_castle_run_surface_test.exs:195-207` | asserts `/api/graphql` unrouted and `Xaas.GraphqlSchema` gone | **(a)** — removal court, keep. |
| `test/xaas_web/sensitive_resource_route_absence_test.exs:5`, `test/xaas/governance/audit_export_token_actor_policy_depth_test.exs:11`, `test/xaas/perf/graphlaw_smoke_perf_test.exs:8` | "no GraphQL..." prose / "GraphQL-assess path" prose | **(a)/(b)** — removal courts + perf-path prose; keep. |

## Deletion set for a follow-up lane

1. **`priv/packs/xaas_library_pack/templates/manufacture.ex.eex`** — strip `AshGraphql.{Domain,Resource}` from the extensions lists and delete the six `graphql do` blocks (L260, 486, 644, 868, 991, and the extensions-list variants) — **the one load-bearing straggler**.
2. Stale SPEC-31 comment lines at `lib/xaas/a2a/agent.ex:17`, `lib/xaas/graphlaw/capability.ex:12`, `lib/xaas/temporal_memory/observation.ex:40,50`, `lib/xaas/coupling/coupling_run.ex:31`, `lib/xaas/generation/projection_record.ex:19`.
3. `mix deps.get` to re-resolve mix.lock (optional-dep entries for prom_ex/ash_money legitimately remain).

## Verification

- **Executed**: exhaustive greps above (real output shown in session).
- **Attempted, stopped**: targeted court census (`route_castle_run_surface_test` +
  `sensitive_resource_route_absence_test`) under
  `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ay` — stopped after 600s+ because
  W984ao was concurrently editing shared `lib/` mid-compile; any red/green would be
  non-attributable to graphql residue. Census standing: BLOCKED(concurrent-lane-edit),
  not BUILD_BROKEN.
- **Transport failure**: `rm -rf _build-laneW984ay` denied by permission layer; the
  empty lane build root `/Users/sac/xaas/_build-laneW984ay` remains on disk —
  coordinator should delete per the lane-lease cleanup law.

## Falsifier for the follow-up lane

`grep -rIn -iE 'ash_?graphql|absinthe|graphql_schema|graphql[[:space:]]+do' lib test config mix.exs priv` →
zero hits outside mix.lock (mix.lock clean after `mix deps.get`), and
`mix test test/xaas/operations/route_castle_run_surface_test.exs` green on a quiet tree.
