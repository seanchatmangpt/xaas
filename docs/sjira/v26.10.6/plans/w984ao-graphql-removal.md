# W984ao — GraphQL surface removal (fix-forward)

Lane: W984ao, xaas v26.10.6 campaign, 2026-10-07.
Directive: "check and remove graphql code without reverting, fix forward."

## Standing

**ALIVE** (removal landed + gated; see SHAs below).

## Enumeration (Phase 1)

- SPEC-30 = 691e0a93 (router /api/graphql scope, absinthe_plug dep,
  graphql_http_surface court). SPEC-31 = 39e9d77f (graphql_schema 16→19
  domains, resource `graphql do` blocks on Org/Event/FreezeWindow/Pack/
  Webhook/PricingOverride, speaker keynote? public?: false).
- Batches W982a/W982u/W983h/W984l added more resource graphql blocks +
  deny-by-default policy floors (uncommitted at lane start).
- Full grep (`AshGraphql|graphql do|Absinthe|absinthe` over lib/ test/
  e2e/ mix.exs config/) found 100+ files; scaffold-era AshGraphql wiring
  predated the campaign (062f3d07, book-scaffold era), so the sweep is
  total: every AshGraphql extension, every graphql block, schema, dep,
  config, courts.

## Removals

- lib/xaas_web/router.ex — /api/graphql scope (Absinthe.Plug forward +
  SPEC-30 comment) deleted; catch-all /api forward now absorbs
  /api/graphql with 404/no_route_found (pinned by the rewritten probe
  in route_castle_run_surface_test.exs).
- mix.exs — `{:ash_graphql, "~> 1.0"}`, `{:absinthe_plug, "~> 1.5"}`
  dropped (absinthe pulled only by ash_graphql → both orphaned);
  scaffold dep-set comment token removed; config/config.exs
  `config :ash_graphql` block dropped.
- lib/xaas/graphql_schema.ex deleted (scaffold-era schema, campaign
  wired 19 domains).
- 88 resource/domain files: every `graphql do ... end` block +
  AshGraphql.Domain/Resource extension token removed
  (12d5f6d3, 98 files).
- lib/mix/tasks/xaas.library.manufacture.ex template swept; registry
  pin re-pinned in registry_drift_guard_test.exs with receipt note.
- Deleted courts: graphql_schema_test, graphql_domain_wiring_court,
  graphql_http_surface_test (tracked, git rm); keynote_graphql_surface_
  court_test.exs + e2e/graphql-http.spec.cjs (untracked, rm'd from
  tree).
- test/xaas_web/sensitive_resource_route_absence_test.exs: graphql
  query/mutation absence test removed (AshGraphql no longer loadable).
- test/xaas/operations/project_measure_test.exs: GraphQL projection
  assertions dropped, JSON:API GET-only pin kept.
- speaker.ex keynote? reverted to public?: true (pre-graphql state);
  graphql rationale comment removed; conference suite green.

## Keeps (with reasons)

- Deny-by-default policy floors (W982a/W983h/W984l batches) on the
  batch resources — landed inside 12d5f6d3 with fan-out disclosure;
  Xaas.Security.ingest gains `authorize?: false` system-context creates
  so the finding/register floors keep ingest lawful (InternalApiToken
  pattern).
- LimitGate + registry engine_limits (bridge surface, w976/w981k) —
  untouched; graphlaw suites green.
- AshJsonApi / AshAdmin extensions and all non-graphql courts.

## Gates (real output)

- Fresh strict compile: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test
  MIX_BUILD_ROOT=_build-laneW984ao mix compile --force
  --warnings-as-errors` → EXIT=0 (942 files).
- conference + conference_deepening + sensitive_resource + project_
  measure + route_castle_run_surface + registry_drift_guard → 46/47
  then 47/47 after fixes (castle probe rewritten to pin the unrouted
  404 envelope).
- governance/billing/graphlaw/ocel/witness/coupling/operations/a2a/
  igniter/security suites → 376/379 → 379/379 after the
  Xaas.Security.ingest authorize?: false repair (the 3 failures were
  the uncommitted batch floors forbidding system ingest — fixed
  forward, disclosed).
- EU-AI-Act: `mix test test/eu_ai_act --include eu_ai_act --exclude
  eu_ai_act_open_gap` → **1352 passed, 1 excluded** (≥ 1352 floor).

## SHAs

- c0ba9f20 — group 1: router scope + deps + config + schema + HTTP
  courts deleted.
- 12d5f6d3 — group 2: 98-file resource sweep + batch policy floors
  (disclosed) + Security.ingest authorize?: false.
- group 3 SHA: see `git log --oneline -3` after landing (test edits +
  registry re-pin + this receipt).

## Fan-out disclosures

- W984u's billing integration (32487e08) swept the working-tree
  pricing_override/approval graphql removals into their commit mid-lane;
  removal landed under their SHA.
- `git add lib/xaas` in group 2 also persisted 4 already-deleted
  platform files (route_orgs_custom_domain_approve,
  route_projects_backups_approve + their requires_approver validations)
  that another actor had deleted in the shared tree; persisted under
  12d5f6d3 with this disclosure, content unchanged from that actor's
  deletion.
- Not staged (other lanes' in-flight): lib/xaas/dev_seeds.ex,
  lib/xaas/library/hold_request.ex.
