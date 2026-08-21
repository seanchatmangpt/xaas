# R2RML + Ontop Virtual-Graph Prototype

Real, disclosed prototype proving the R2RML + Ontop architecture decision (use Ontop, a
SPARQL-to-SQL virtual-graph engine, over the existing Postgres schema, instead of a custom
`Ash.DataLayer` targeting a triple store). This is the first real code for that decision — a
working mapping file, a working `docker-compose` service, and two real SPARQL queries run
against real rows in the real dev database.

## Extension (2026-08-20, later session): 3 more real tables

Extended `priv/ontop/xaas-mapping.ttl` with 3 more real `rr:TriplesMap` blocks, chosen to
prefer real DB-level FK constraints over app-enforced-only joins:

1. **`approval_provider_status_changes.provider_id -> marketplace_providers.id`** (real DB FK
   `approval_provider_status_changes_provider_id_fkey`) — the real maker-checker provider
   status-change lifecycle (`Xaas.Marketplace.ApprovalProviderStatusChange`) that landed this
   session.
2. **`approval_dr_failovers.org_id -> orgs.slug`** (real DB FK
   `approval_dr_failovers_org_id_fkey`, `ON UPDATE CASCADE` / `ON DELETE RESTRICT`) — one of
   the 3 real multitenancy FKs added this session
   (`20260821034020_add_org_fk_dr_failover_legal_hold_release_deployment_quarantine.exs`).
   Its 2 siblings (`approval_deployment_quarantines`, `approval_legal_hold_releases`) have the
   identical FK shape and were not separately mapped, to avoid 3 near-duplicate TriplesMaps for
   one disclosed pattern.
3. **`org_memberships.org_id -> orgs.id`** (real DB FK `org_memberships_org_id_fkey`) — a real
   `uuid` FK, unlike the `text`-slug joins above, so this edge uses a real R2RML referencing
   object map (`rr:parentTriplesMap` + `rr:joinCondition`) rather than a `rr:template` guess.
   Ontop's own startup log confirms it compiled this into a real SQL join:
   `SELECT CHILD.id AS CHILD_id, PARENT.slug AS PARENT_slug FROM (SELECT * FROM
   org_memberships) CHILD, (SELECT * FROM orgs) PARENT WHERE CHILD.org_id = PARENT.id`.

**Deliberately NOT mapped**: `org_memberships.user_id -> users.id`. `users`
(`Xaas.Accounts.User`) is one of the 2 real auth/PII resources this project's CLAUDE.md and
`docs/claude/diataxis/reference/http-api-surface.md` keep deliberately unwired from the
customer-facing API ("never blindly wire routes on sensitive resources"). The same discipline
applies to the SPARQL graph: mapping `users` would expose PII rows through a datalayer with no
per-actor Ash policy enforcement (same standing gap already disclosed below). Only the
`org_memberships -> orgs` edge is mapped; `org_memberships.role` is also mapped as a literal.

### Real seed rows (dev DB, same discipline as the original prototype)

`approval_dr_failovers` already had 1 real row from this session's own work
(`org-a-67`/`us-east-1`->`us-west-2`). The other 2 target tables were empty; one real row each
was inserted (plus 1 real `users` row, required by `org_memberships.user_id`'s `NOT NULL` FK,
even though that edge itself isn't mapped):

```sql
insert into users (id, email) values (gen_random_uuid(), 'r2rml-prototype-seed@example.com');

insert into approval_provider_status_changes (id, org_id, provider_id, requested_by, requested_status, approved_by)
values (gen_random_uuid(), 'read-12', 'e25f17bc-37b2-4556-9415-f96d3b7566cc', 'maker@example.com', 'suspended', 'checker@example.com');

insert into org_memberships (id, role, user_id, org_id)
values (gen_random_uuid(), 'admin', '8b9b50c0-a256-409e-8f42-957c70642952', 'd5a39e0d-62be-4527-8109-cdc0231e735f');
```

All 3 real, `INSERT 0 1` each.

### Docker/Ontop: real, live-verified this run

`xaas-ontop-prototype` was already running (`docker compose ps`, healthy) against the real
`xaas_default` network. Restarted it (`docker compose -f docker-compose.ontop.yaml restart
ontop`) to pick up the extended mapping file — real log confirms the new join-condition
TriplesMap compiled and the endpoint came back up:

```
05:01:38.573 |-INFO  R2RMLToSQLPPTriplesMapConverter - Join "triples map" introduced: ...
  source query: SELECT CHILD.id AS CHILD_id, PARENT.slug AS PARENT_slug FROM
  (SELECT * FROM org_memberships) CHILD, (SELECT * FROM orgs) PARENT WHERE CHILD.org_id = PARENT.id
05:01:39.107 |-INFO  OntopQueryEngineImpl - Ontop has completed the setup and it is ready for query answering!
```

The real auth-gated proxy (`KanbanWeb.OntopProxyPlug` at `/internal-api/sparql`) is configured
to reach Ontop at `http://ontop:8080` over the internal Docker network — correct for the
already-running `xaas-web-1` container, but that container predates this session's proxy code
(confirmed: hitting it returned a real `404`, not `401`, meaning the route isn't compiled into
its image). To query for real this run, a local `mix phx.server` was booted instead (same
approach the original prototype used), with `config :kanban, :ontop_base_url` pointed at
Ontop's host-published `127.0.0.1:8888` port (temporary `config/dev.exs` edit, reverted via
`git checkout` before finishing — not committed, not left in the tree).

Real auth check, no-token request against the real proxy: `401` (confirmed live this run).

### Real SPARQL queries #3-#5 — the 3 new mappings, via the real auth-gated proxy

```bash
curl -s -G "http://localhost:4111/internal-api/sparql" \
  -H "Authorization: Bearer $INTERNAL_API_TOKEN" \
  --data-urlencode 'query=PREFIX xv: <http://xaas.local/vocab#>
SELECT ?psc ?status ?provider ?providerName WHERE {
  ?psc a xv:ProviderStatusChange ; xv:requestedStatus ?status ; xv:forProvider ?provider .
  ?provider xv:name ?providerName .
}' -H "Accept: application/sparql-results+json"
```

Real response — `approval_provider_status_changes -> marketplace_providers`:

```json
{"head":{"vars":["psc","status","provider","providerName"]},"results":{"bindings":[{"provider":{"type":"uri","value":"http://xaas.local/resource/provider/e25f17bc-37b2-4556-9415-f96d3b7566cc"},"providerName":{"type":"literal","value":"Prototype Provider"},"psc":{"type":"uri","value":"http://xaas.local/resource/provider-status-change/b04a501a-56be-428d-9730-23ddea825c75"},"status":{"type":"literal","value":"suspended"}}]}}
```

Real response — `approval_dr_failovers -> orgs` (query analogous, `xv:DrFailover` /
`xv:belongsToOrg`):

```json
{"head":{"vars":["dr","fromR","toR","org","orgName"]},"results":{"bindings":[{"dr":{"type":"uri","value":"http://xaas.local/resource/dr-failover/17f7bf01-ad15-4278-84d6-569e82099ab8"},"fromR":{"type":"literal","value":"us-east-1"},"org":{"type":"uri","value":"http://xaas.local/resource/org/org-a-67"},"orgName":{"type":"literal","value":"A"},"toR":{"type":"literal","value":"us-west-2"}}]}}
```

Real response — `org_memberships -> orgs` (the referencing-object-map / join-condition edge,
`xv:OrgMembership` / `xv:belongsToOrg`), proving the join-condition-based mapping resolves for
real, not just compiles:

```json
{"head":{"vars":["mem","role","org","orgSlug"]},"results":{"bindings":[{"mem":{"type":"uri","value":"http://xaas.local/resource/org-membership/e740ec8e-9977-44bd-9245-b1bec1f88612"},"org":{"type":"uri","value":"http://xaas.local/resource/org/read-12"},"orgSlug":{"type":"literal","value":"read-12"},"role":{"type":"literal","value":"admin"}}]}}
```

All 3 real, correctly joined through the real auth-gated `/internal-api/sparql` proxy with a
real Bearer `INTERNAL_API_TOKEN`.

### Regression check this run

`mix compile --force` clean (no `lib/` changes — only `priv/ontop/xaas-mapping.ttl` and this
doc were touched). `MIX_ENV=test mix test` run 3 times, real output each time: `1 property, 211
tests, 0 failures (10 excluded)`. Real `grep -rn
"unittest.mock\|Mock(\|MagicMock\|patch(\|monkeypatch\|Mox\b\|:meck\|meck\." test/ lib/` — only
matches are `Phoenix.ConnTest.patch/2` HTTP PATCH calls in controller tests and unrelated
`dispatch`/`patch(:update)` substrings; zero real mocking-library usage.

## What was proven real (2026-08-20, original prototype)

1. **R2RML mapping compiles and loads.** `priv/ontop/xaas-mapping.ttl` maps 4 real,
   already-existing tables (`orgs`, `billing_subscriptions`, `marketplace_providers`,
   `platform_webhooks` + `platform_webhook_deliveries`) into a small RDF vocabulary under
   `http://xaas.local/vocab#`. Ontop loaded it and reported "ready for query answering"
   (real log line, `docker logs xaas-ontop-prototype`, see below).
2. **Real container boots against the real Postgres.** `ontop/ontop:latest` on the real
   `xaas_default` Docker network, connecting to the already-running `xaas-db-1` container at
   `jdbc:postgresql://db:5432/kanban_dev`.
3. **Two real SPARQL queries against real rows return real, correctly-joined results**:
   - `Subscription -[belongsToOrg]-> Org` (app-enforced join, `billing_subscriptions.org_id`
     = `orgs.slug`, no DB-level FK — disclosed in the mapping file's own header comment).
   - `WebhookDelivery -[forWebhook]-> Webhook` (real DB-level FK,
     `platform_webhook_deliveries_webhook_id_fkey`).

## What was NOT proven / left for follow-up

- Only 1 real `orgs` row existed before this session; the other 3 tables were empty. To get a
  real, non-trivial join result, one real row each was inserted into `billing_subscriptions`,
  `marketplace_providers`, `platform_webhooks`, and `platform_webhook_deliveries` in the real
  dev database (not fabricated query output — real `INSERT` statements, shown below). This
  is dev-database seed data for the prototype, not production data.
- `marketplace_providers.org_id` and `platform_webhooks.org_id` -> `orgs.slug` joins use the
  same app-enforced-only pattern as `billing_subscriptions` (no DB FK) — mapped but not
  separately queried in this session; same join mechanics as the proven `Subscription` case.
- No ontology file (`ONTOP_ONTOLOGY_FILE`) was written — the mapping's `rr:class` /
  `rr:predicate` terms are used directly with no OWL axioms behind them. Fine for this
  prototype's goal (prove the SQL-to-SPARQL round trip); would matter for reasoning/inference
  use cases later.
- Not evaluated: write access (Ontop is read-only/virtual by design), performance at real
  data volume.
- **Network exposure — fixed 2026-08-20.** Ontop's host-published port was real
  `0.0.0.0:8888` (publicly reachable on the host's network interfaces, confirmed via
  `docker ps`). Now `docker-compose.ontop.yaml` publishes `127.0.0.1:8888` only, and the
  only sanctioned way to reach it is `KanbanWeb.OntopProxyPlug`
  (`lib/kanban_web/plugs/ontop_proxy_plug.ex`), mounted at `/internal-api/sparql` behind
  the same `KanbanWeb.Plugs.RequireInternalApiToken` pipeline every other `/internal-api`
  route uses. The proxy talks to Ontop over the real internal `xaas_default` Docker
  network (`http://ontop:8080`), not the host-published port. Real-proven this session
  (local `mix phx.server`, real running `xaas-ontop-prototype` container): `GET
  /internal-api/sparql` with no `Authorization` header → real `401`; with a wrong Bearer
  token → real `401`; with the real correct `INTERNAL_API_TOKEN` → real `200` with the
  same real SPARQL JSON the original prototype query returned. Real unit tests for the
  proxy plug's own auth-and-forwarding behavior:
  `test/kanban_web/plugs/ontop_proxy_plug_test.exs`.
- **Still NOT resolved (disclosed, unchanged in kind from before)**: this is host-level
  network binding + a proxy-level bearer-token check, not per-query Ash policy
  enforcement — SPARQL still bypasses Ash's authorization layer entirely once past the
  proxy, and anyone holding the shared `INTERNAL_API_TOKEN` can run arbitrary SPARQL
  against all 4 mapped tables (no row-level or resource-level authorization inside Ontop
  itself). Same standing limitation already disclosed for `Xaas.Ledger`/`Xaas.Accounts` —
  token possession, not per-actor Ash policy, is the real access-control boundary here.

## Files

- `priv/ontop/xaas-mapping.ttl` — the R2RML mapping, Turtle syntax, real schema confirmed via
  `psql \d` against the real `kanban_dev` database before writing it.
- `priv/ontop/jdbc/postgresql-42.7.4.jar` — real PostgreSQL JDBC driver, downloaded from Maven
  Central (`org.postgresql:postgresql:42.7.4`). Required because `ontop/ontop:latest` ships
  with **no JDBC driver at all** — first boot attempt failed with
  `java.sql.SQLException: Cannot load the driver: org.postgresql.Driver` (real error, see
  below). Fixed by mounting the jar into `/opt/ontop/lib/`, which is already on the image's
  classpath.
- `docker-compose.ontop.yaml` — standalone compose file (kept separate from `compose.yaml`,
  which is Swarm-mode with `deploy:` keys) joined onto the real `xaas_default` bridge network
  so it can reach the already-running `db` service by its real Docker DNS alias.

## Real commands run, and real output

### 1. Confirm real schema (before writing the mapping)

```bash
export PGPASSWORD=$(cat secrets/.postgrespassword)
psql -h localhost -p 32768 -U postgres -d kanban_dev -c "\d orgs"
psql -h localhost -p 32768 -U postgres -d kanban_dev -c "\d billing_subscriptions"
psql -h localhost -p 32768 -U postgres -d kanban_dev -c "\d platform_webhooks"
psql -h localhost -p 32768 -U postgres -d kanban_dev -c "\d platform_webhook_deliveries"
```

Confirmed: `orgs` has no DB-level FK from any of `billing_subscriptions` /
`marketplace_providers` / `platform_webhooks` to `orgs.slug` (only
`platform_webhook_deliveries.webhook_id -> platform_webhooks.id` is a real DB FK). Recorded
as a disclosed gap in the mapping file's header comment rather than silently assumed away.

### 2. Seed one real row per empty table (real INSERTs, real dev DB)

```sql
insert into billing_subscriptions (id, org_id, stripe_customer_id, stripe_subscription_id, tier, status, current_period_end)
values (gen_random_uuid(), 'read-12', 'cus_prototype123', 'sub_prototype123', 'standard', 'active', now() + interval '30 days');

insert into marketplace_providers (id, name, slug, description, status, org_id, inserted_at, updated_at)
values (gen_random_uuid(), 'Prototype Provider', 'prototype-provider', 'R2RML/Ontop prototype seed row', 'approved', 'read-12', now(), now());

insert into platform_webhooks (id, org_id, url, event_types, secret, enabled, inserted_at, updated_at)
values (gen_random_uuid(), 'read-12', 'https://example.com/hook', ARRAY['order.created'], 'proto-secret', true, now(), now());

insert into platform_webhook_deliveries (id, event_type, payload, status, attempt_count, webhook_id, inserted_at, updated_at)
values (gen_random_uuid(), 'order.created', '{"order_id":"proto1"}'::jsonb, 'delivered', 1, '3ea8f4b3-7b8c-460f-add7-ae7a65f8d11e', now(), now());
```

All 4 inserts real, `INSERT 0 1` each.

### 3. First boot attempt — real failure, disclosed

```bash
docker compose -f docker-compose.ontop.yaml up -d
docker logs xaas-ontop-prototype
```

Real error (JDBC driver missing from the base image):

```
Caused by: java.sql.SQLException: Cannot load the driver: org.postgresql.Driver
	at it.unibz.inf.ontop.utils.LocalJDBCConnectionUtils.createConnection(LocalJDBCConnectionUtils.java:34)
	...
Exception in thread "main" java.lang.AssertionError
	at it.unibz.inf.ontop.cli.Ontop.main(Ontop.java:31)
```

### 4. Real fix — mount a real JDBC driver jar

```bash
curl -sL -o priv/ontop/jdbc/postgresql-42.7.4.jar \
  https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.4/postgresql-42.7.4.jar
```

Added to `docker-compose.ontop.yaml`:

```yaml
volumes:
  - ./priv/ontop:/opt/ontop/input
  - ./priv/ontop/jdbc/postgresql-42.7.4.jar:/opt/ontop/lib/postgresql-42.7.4.jar
```

### 5. Second boot — real success

```bash
docker compose -f docker-compose.ontop.yaml up -d
docker logs xaas-ontop-prototype
```

Real log tail:

```
02:53:58.941 |-INFO  in i.u.i.o.a.impl.OntopQueryEngineImpl - Ontop has completed the setup and it is ready for query answering!
02:53:58.941 |-INFO  in i.u.i.o.r.r.i.OntopVirtualRepository - Ontop virtual repository initialized successfully!
02:53:59.738 |-INFO  in o.s.b.w.e.tomcat.TomcatWebServer - Tomcat started on port(s): 8080 (http) with context path ''
```

`docker ps` confirmed: `xaas-ontop-prototype` — `Up ... (healthy)`, `0.0.0.0:8888->8080/tcp`.

### 6. Real SPARQL query #1 — Subscription -> Org (app-enforced join)

```bash
curl -s -G "http://localhost:8888/sparql" \
  --data-urlencode 'query=PREFIX xv: <http://xaas.local/vocab#>
SELECT ?sub ?tier ?org ?orgName WHERE {
  ?sub a xv:Subscription ; xv:tier ?tier ; xv:belongsToOrg ?org .
  ?org xv:name ?orgName .
}' \
  -H "Accept: application/sparql-results+json"
```

Real response:

```json
{
  "head": { "vars": ["sub", "tier", "org", "orgName"] },
  "results": {
    "bindings": [
      {
        "sub": { "type": "uri", "value": "http://xaas.local/resource/subscription/7efb7dc1-5f0d-4b2b-84da-bb5067ed4e47" },
        "tier": { "type": "literal", "value": "standard" },
        "org": { "type": "uri", "value": "http://xaas.local/resource/org/read-12" },
        "orgName": { "type": "literal", "value": "R" }
      }
    ]
  }
}
```

`read-12` and `R` are the real, pre-existing `orgs` row's `slug` and `name` — the join
correctly resolved the seeded `billing_subscriptions.org_id` string to the real `orgs` row via
the virtual graph, with no application code involved.

### 7. Real SPARQL query #2 — WebhookDelivery -> Webhook (real DB-level FK join)

```bash
curl -s -G "http://localhost:8888/sparql" \
  --data-urlencode 'query=PREFIX xv: <http://xaas.local/vocab#>
SELECT ?delivery ?eventType ?webhook ?url WHERE {
  ?delivery a xv:WebhookDelivery ; xv:eventType ?eventType ; xv:forWebhook ?webhook .
  ?webhook xv:url ?url .
}' \
  -H "Accept: application/sparql-results+json"
```

Real response:

```json
{
  "head": { "vars": ["delivery", "eventType", "webhook", "url"] },
  "results": {
    "bindings": [
      {
        "delivery": { "type": "uri", "value": "http://xaas.local/resource/delivery/1af9c99a-62be-4336-9de7-31121c9b2c9f" },
        "eventType": { "type": "literal", "value": "order.created" },
        "webhook": { "type": "uri", "value": "http://xaas.local/resource/webhook/3ea8f4b3-7b8c-460f-add7-ae7a65f8d11e" },
        "url": { "type": "literal", "value": "https://example.com/hook" }
      }
    ]
  }
}
```

`webhook_id` in the FK column correctly resolved to the real `platform_webhooks` row's `url`.

## Verdict

Real container boots against the real dev Postgres; real SPARQL queries against
`billing_subscriptions` and `platform_webhook_deliveries` return real, correctly-joined rows
from the real database, for both an app-enforced join (no DB FK) and a DB-FK-backed join. The
core architecture bet — Ontop can expose this schema as a queryable RDF graph without a custom
`Ash.DataLayer` or a triple-store migration — is proven at prototype scale on 4 tables and 2
join paths, on real (session-seeded) data. Not proven: behavior at real data volume, write
paths, ontology/reasoning, or an access-control story for exposing this beyond localhost.

## Stopping the prototype

```bash
docker compose -f docker-compose.ontop.yaml down
```

## See Also

- `docs/ASH-MIGRATION-PLAN.md` — migration history and standing deferred decisions this
  prototype does not touch (Phase 5 customer-facing mutation API, per-resource policies).
- `docs/claude/diataxis/reference/ash-configuration.md` — real current `config/*.exs` facts.
- [Ontop Docker endpoint tutorial](https://ontop-vkg.org/tutorial/endpoint/endpoint-docker.html)
- [`ontop/ontop` on Docker Hub](https://hub.docker.com/r/ontop/ontop)
