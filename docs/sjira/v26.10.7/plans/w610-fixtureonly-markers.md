# W610 Receipt — WP-5/OS-13 `aex:fixtureOnly` marketplace markers (v26.10.7)

Standing: PARTIAL_ALIVE (marker surface verified ALIVE on disk; nothing new to add — see finding)
Date: 2026-10-07
Subject: `~/ggen-marketplace` working tree (NOT committed, per directive); repo HEAD `2592ec5b`-equivalent — exact: `git -C ~/ggen-marketplace rev-parse HEAD` = see git status below. Ontology hashes from real `ggen graph validate` runs are the subject identity anchors.

## Grounding (read-before-write, per directive)

- Marker idiom learned from exemplar `packs/ash-extension-core-pack/ontology.ttl:28-29`:
  `aex:fixtureOnly a rdf:Property ; rdfs:domain aex:AshExtensionSpec ;` — "boolean marker for
  pack-owned worked examples. fixtureOnly=true individuals remain available to gates/audits
  but MUST NOT fan out consumer artifacts." Attaches to **individuals** (`aex:AshExtensionSpec`
  instances), one line per spec, not pack metadata.
- Gate consumption: `packs/ash-extension-pack/gates/100_projection_isolation_contract.rq:22-23`
  filters `FILTER NOT EXISTS { ?s aex:fixtureOnly true }` — i.e. the gate exempts fixture-only
  specs from projection-isolation.
- Cross-pack idiom reuse: `packs/protocol-integration-pack/enterprise_kudzu.ttl:39-40` defines
  `pr:priorArtFixtureOnly` "mirrors ash-extension-pack's aex:fixtureOnly idiom".

## Per-family findings (matched by purpose, exact disk evidence)

| family (directive name) | disk individuals | marker state |
|---|---|---|
| ash_r2rml | `aex:AshR2RMLSpec` in ash-extension-pack (L343) + ash-extension-core-pack (L168) | MARKED in both |
| audit_trail | `aex:AuditTrailSpec` in ash-extension-pack (L271) + ash-extension-core-pack (L106) | MARKED in both |
| notification_extension | `aex:NotificationExtensionSpec` in ash-extension-pack only (L556) | MARKED |
| — (bonus, same idiom) | `aex:AshA2aSpec` ash-extension-pack L1590 | MARKED (pre-existing working-tree line from sibling lane) |

NOT-FOUND records (typed):
- `NOT-FOUND(notification_extension individual, ash-extension-core-pack)` — core pack has exactly
  two AshExtensionSpec individuals (AuditTrailSpec, AshR2RMLSpec); no notification family
  individual exists there. Not invented.
- `N/A(ash-r2rml-paas-pack, ash-r2rml-reactor-paas-pack)` — these packs exist and are about
  R2RML but carry `paas:PlatformProfile` individuals only; no `aex:AshExtensionSpec` individuals,
  hence no fixtureOnly attachment surface. No marker added (would violate property domain).

## Edits made by this lane

**None.** All three named families were already marked on disk when this lane grounded:
- ash-extension-core-pack: markers are in **committed HEAD** (2 × `fixtureOnly true`).
- ash-extension-pack: markers present in the **uncommitted working tree** — the exact diff hunk
  `+    aex:fixtureOnly true ;` on AuditTrailSpec/AshR2RMLSpec/NotificationExtensionSpec/AshA2aSpec
  is sitting uncommitted in `~/ggen-marketplace` (also carries unrelated sibling-lane edits to
  `gates/120_spark_dead_surface.rq`, `templates/extension.ex.tmpl`, `CHANGELOG.md`,
  `marketplace.active.toml`). Attributed to a sibling/earlier W610 pass; this lane did not
  duplicate or commit them.

Deliberate non-extension: the pack-owned probe specs lacking the marker
(`qualification/consumer.ttl` PipelineProbeSpec/LedgerProbeSpec, `verify/fixtures/receipted_spec*.ttl`)
were left unmarked because `gates/100_projection_isolation_contract.rq` exempts `fixtureOnly` specs
from projection isolation — marking live qualification surfaces would weaken that gate. Flagged
for coordinator, not silently changed.

## Validation (real commands, real tails)

`ggen 26.9.28`, `ggen graph validate --files <ontology> --format plain` — all four passed (0 violations):

    == ash-extension-pack/ontology.ttl
    quads: 1931
    hash: 283b5558db415e72e36ed049993a0a0c1a176052d42f175b4837ed7c0b6ddc25
    files_checked: 1

    == ash-extension-core-pack/ontology.ttl
    quads: 664
    hash: 8168c97042a3edd12a2d61b7e29d22b828c7bd7ed0553d20e5c3445d36d7d3d9
    files_checked: 1

    == ash-r2rml-paas-pack/ontology.ttl
    ggen graph validate --files ash-r2rml-paas-pack/ontology.ttl --format plain
    quads: 46
    hash: 59822209e179f5851087627d6f7c3b1a5eb98fac020ab031666b27bf762f4e4d
    files_checked: 1

    ==     == ash-r2rml-reactor-paas-pack/ontology.ttl
    quads: 87
    hash: 7fc3184a1f5e6a3e417db80ff13c09024fdce7bba0e1d4dd9fd11b1339edb2c1
    files_checked: 1

No sync was run (directive). Consumer-side flag remains W610's second half in `~/ggen`.

## Replay

    cd ~/ggen-marketplace/packs
    grep -n -A1 "a aex:AshExtensionSpec" ash-extension-pack/ontology.ttl   # 4 marked individuals
    grep -n -A1 "a aex:AshExtensionSpec" ash-extension-core-pack/ontology.ttl  # 2 marked individuals
    ggen graph validate --files ash-extension-pack/ontology.ttl --format plain

## Standing

PARTIAL_ALIVE — marker surface on the three named families: ALIVE on disk (validated). Lane diff:
zero files changed by this lane. Open items: (1) uncommitted sibling-lane working-tree state in
~/ggen-marketplace needs coordinator-owned commit; (2) consumer-mode sync flag (~/ggen half) is a
separate lane; (3) probe-spec marking question deferred with rationale.
