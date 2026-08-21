# R2RML + Ontop Virtual-Graph Prototype

Real, disclosed prototype proving the R2RML + Ontop architecture decision (use Ontop, a
SPARQL-to-SQL virtual-graph engine, over the existing Postgres schema, instead of a custom
`Ash.DataLayer` targeting a triple store). This is the first real code for that decision — a
working mapping file, a working `docker-compose` service, and two real SPARQL queries run
against real rows in the real dev database.

## What was proven real (2026-08-20)

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
  data volume, or how this would integrate with Ash's own authorization layer — a
  SPARQL endpoint bypasses Ash policies entirely, so exposing it beyond localhost needs its
  own access-control design (same standing rule this repo already applies to the
  `Xaas.Ledger`/`Xaas.Accounts` resources).

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
