# Ash Elixir Refactor Plan for `xaas`

**Status**: real, researched plan — not yet executed. Produced by a real audit of this
repo, `~/ggen-marketplace/packs/xaas-ash-core-pack`, and `~/dev-fresh/xaas`, plus 3
independently-designed migration strategies, synthesized into one ranked recommendation.

## Real current state (audited directly, not assumed)

- **`~/xaas`** (this repo): plain Phoenix/Ecto, `Kanban.*`/`KanbanWeb.*` namespace, `ash`
  not a dependency. No domain/context layer at all — `Kanban.Application` supervises only
  infra children (Endpoint, PromEx, Repo, PubSub, Finch). Zero business schema/migrations
  (confirmed earlier this session). Real, deployed infra: Dockerfile, k8s manifests (live
  in `kind`), Terraform (GitHub + Grafana modules, both applied), docker-compose (7 healthy
  services), CI. The only hardcoded coupling to the `kanban` name that would break on
  rename: `Dockerfile:95`'s `rel/kanban` copy, and 4 `rel/overlays/bin/*` scripts calling
  `./kanban start`/`./kanban eval` — derived from `mix.exs:14`'s `app: :kanban`, not from
  anything else. Postgres user/db/image-tag "kanban" strings in `compose.yaml`/`k8s/*.yaml`
  are independent naming choices, not code-coupled.
- **`~/ggen-marketplace/packs/xaas-ash-core-pack`**: real, ggen-rendered pipeline. 44 real
  `xar:RenderTarget` individuals in `ontology.ttl`, 131 real INCLUDE packages in
  `packages.ttl`. `DIFFICULTIES.md` (primary source): 208/210 commands succeeded in the last
  real execution; the 2 fixes are real but the repaired 211-command run is **honestly marked
  `NOT YET EXECUTED`** — don't treat it as re-verified.
- **`~/dev-fresh/xaas`**: a separate, real, already-generated target of that pack. `Xaas.*`
  namespace (matches the pack, not `~/xaas`). 156 real `.ex` files, 89 real
  `use Ash.Resource` modules, clean `mix compile --force` (verified live, not from a stale
  log). Confirmed gaps, independently re-derived: only 2/89 resources have any
  `authorize_if`/`forbid_if` policy; only 1/89 has a real HTTP-verb route body. This project
  is a **real, reusable asset** — not throwaway — and should be the migration source.
- **Namespace collision check**: `~/xaas` has zero `Xaas.*` modules; `~/dev-fresh/xaas` has
  zero `Kanban.*` modules. The two are namespace-disjoint — merging them is additive, not a
  rename.

## Recommendation: incremental in-place merge (no Kanban→Xaas rename)

Port `~/dev-fresh/xaas`'s real `Xaas.*` resources/domains into `~/xaas` **alongside** the
existing `Kanban.*`/`KanbanWeb.*` code, leaving the real, already-working Dockerfile/k8s/CI/
Terraform infra byte-identical. Reject a full Kanban→Xaas rename for this migration — it
would touch the release binary name across `Dockerfile`/`rel/overlays/bin/*`/CI image tags
purely for namespace aesthetics, against a currently-deployed release, for zero functional
gain. Two-namespace apps are legal Elixir and require no new pattern (this is already how
`dev-fresh/xaas` maps onto the pack's ontology).

## Ordered migration plan

**Phase 0 — Branch and snapshot**: `git checkout -b ash-migration`, record both repos' HEAD
SHAs as a rollback anchor.

**Phase 1 — Deps only**: add `{:ash, "~> 3.32"}`, `{:ash_postgres, "~> 2.0"}` to `mix.exs`.
`mix deps.get && mix compile` must exit 0 before any resource code lands (confirms no
version conflict with `phoenix ~> 1.7.0`/`ecto_sql ~> 3.6`).

**Phase 2 — Config wiring**: keep `config :kanban, ecto_repos: [Kanban.Repo]` as-is; add
`config :kanban, ash_domains: [Xaas.Operations, Xaas.Governance, Xaas.Billing,
Xaas.Platform]`. `Kanban.Repo` stays a plain `Ecto.Repo` — `AshPostgres.DataLayer` is set
per-resource, no need to touch `lib/kanban/repo.ex` or the supervision tree.

**Phase 3 — Port the 89 resources** (copy, not regenerate): `cp -r
~/dev-fresh/xaas/lib/xaas/{operations,governance,billing,platform,accounts,ledger}
lib/xaas/` plus the 4 domain modules. `mix compile --force`, expect 0 namespace collisions
(confirmed disjoint). Fix any compile errors — same failure class `DIFFICULTIES.md` already
diagnosed (`ash_onetime` routing, unsupported flags), not new unknowns.

**Phase 4 — Migrations**: `mix ash_postgres.generate_migrations --domains
Xaas.Operations,Xaas.Governance,Xaas.Billing,Xaas.Platform` (regenerate fresh against
xaas's actual DB state — do not hand-copy dev-fresh's migrations, schema/timestamp drift
risk). `mix ecto.migrate`. Verify: all 89 resource tables exist, existing Kanban tables/rows
untouched (row-count check before/after).

**Phase 5 — Gap closure, not deferred debt**: 87/89 resources currently have implicit
allow-all authorization and no real API surface. Before this ships to the live deployment:
1. Every resource lacking a policy gets an explicit `policy always() do forbid_if always()
   end` floor (deny-by-default), replaced per-resource with real rules as owners define
   them — never ship allow-all on a repo with real deployed infra.
2. Decide the API surface per domain: wire `AshJsonApi`/`AshGraphql` into
   `KanbanWeb.Router` additively, or explicitly mark domains "no HTTP exposure yet" and
   don't route them.
3. Gate: never point k8s ingress at a new Ash-backed route before its resource has a real
   (non-default-allow) policy.

**Phase 6 — Ggen loop, in the permanent repo**: copy `dev-fresh/xaas`'s `ggen.toml` +
vendored `ontology.ttl` + `templates-hooks/` into `~/xaas` (matches the real, proven
`sh_after` pattern from earlier this session). Defer wiring a `ggen-render` CI job — only
one real regeneration event has happened so far; add that stage on the *second* real
ontology-driven regen, not preemptively.

**Phase 7 — Infra verification, protects the live deployment**: local-only `docker build`
+ `bin/kanban eval "1+1"` sanity check (confirms release name/boot unaffected). `mix test`
(existing 3 web tests, zero regression expected — `Kanban.Repo` untouched). Deploy to a
**separate namespace or image tag** in `kind`, never overwrite the live deployment directly
— curl existing routes (expect unchanged 200s) and any new Ash routes (expect 403 if
unauthenticated, confirming Phase 5's policy gate actually holds) before merging to `main`
and redeploying the real namespace.

## Risk summary

Nothing in Phases 1-4 touches `Dockerfile`, `rel/overlays/`, `compose.yaml`, or `k8s/*.yaml`
— they stay byte-identical, which is the whole point of this strategy over a full rename.
The one real risk surface is Phase 5: an `AshJsonApi`/`AshGraphql` route wired in before its
resource has a policy is a live authz gap on a real k8s ingress. Caught by: the migration
row-count check (Phase 4), the release-boot sanity check (Phase 7), and the curl-403 check
(Phase 7) — each specifically targets one of the three ways this could go wrong.
