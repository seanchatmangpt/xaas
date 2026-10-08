# ARD: ash_atlassian migration target (SJ-007)

Version v26.9.21. Scope: the target package for the Atlassian -> ash_atlassian migration, its
ontology source of truth, the bounded first slice, and the generator route. Audience: the
autonomic loop (`Xaas.Ultracode.Autonomic`) and any agent picking up SJ-007 follow-ups.
Acceptance is decided by a machine court, not by a reader: `mix xaas.sjira.ard_court` (see
Acceptance). The court receipt is `receipts/SJ-007-ard-court.json`.

## Decision

- **Target**: a new package `~/ash_atlassian` (Hex app `:ash_atlassian`, namespace `AshAtlassian`),
  its own git repo, created by this track. It replaces the missing target that blocked SJ-007.
- **Ontology source of truth**: `~/ash_atlassian/ontology/atlassian-profile.ttl`, a SHACL
  application profile over public terms only. No local class or property is declared.
- **Route**: `ggen sync run` renders an Igniter construction program and a semantic map from the
  profile; `mix ash.gen.resource` / `mix ash.extend` write the Ash source. Nothing in `lib/` is
  hand-written.
- **First slice**: Jira issues, projects, users, transitions; Confluence pages, spaces.
- **Attribute set**: datatype properties that have a declared public term. Everything else is
  deferred with an explicit `UNSUPPORTED(ontology-term)` row, never given an invented term.

## Observed facts

Prior-art search, 2026-09-21. Every row below was observed by a command or fetch in this track.

| Searched | Finding |
|---|---|
| `~/ash_atlassian` | did not exist; created (`git init`, first commit `36b1799`) |
| `~/atlassian` | NOT an empty stub (the order's description calls it one): a regular 1,117,044-byte, 26,850-line text file, a ChatGPT chat export. It holds a SchemaCrawler dump of a Jira MySQL 5.7 database (252 distinct `jiradb.*` `[table]` entries, the dump repeated three times) and Ash design chat. It is not an ontology or a spec; it is non-authoritative and used only to cross-check that `jiraissue`, `project`, `app_user`, `issuestatus` exist internally. |
| ggen-marketplace packs | no atlassian, jira or confluence pack. `V2030.1.1-PRD-ARD.md:42` says Atlassian and other marketplaces SHALL be modeled as projections, not independent product truth. Other lexical matches are prose mentions (D3FEND, OBO `gsso`, cell-biology "confluence"). |
| `xaas-public-ash-projection-pack` | REUSED: SHACL profile over public terms to an Igniter construction script; gates 010-040. Its README records `ggen sync run` on that pack as not yet executed. |
| `xaas-public-ontology-profile` | REUSED as law: `mappings/README.md` says non-RDF public standards (OpenAPI, Kubernetes, Terraform schemas) are mapping inputs, not ontology sources. Locks exist for OSLC automation, config and RM; none for OSLC CM. |
| `ash-r2rml-paas-pack` | REJECTED as route: a provider-neutral PaaS kernel with a local `paas:` vocabulary; different semantics. |
| `semantic-gate-witness-court-pack` | ADJACENT: binds gates to positive and negative witnesses for a pack. Named as owner for promoting the ARD court. |
| `~/ggen_igniter` | `GgenIgniter.SemanticJira` admits work orders; it has no Atlassian resource model. Nothing to reuse for the resources. |
| Jira Cloud OpenAPI v3 | fetched (WebFetch, summarized by the tool, not byte-verified) `dac-static.atlassian.com/cloud/jira/platform/swagger-v3.v3.json`. `IssueBean`{id, key, self, fields, changelog, transitions, ...}; `Project`{id, key, name, description, url, projectTypeKey, isPrivate, lead, ...; required key, name}; `User`{accountId, accountType, displayName, emailAddress, active, timeZone, locale, ...}; `IssueTransition`{id, name, to, hasScreen, isGlobal, isInitial, isConditional, isLooped; required id, name, to}. |
| Confluence Cloud REST v2 | the raw `openapi-v2.v3.json` fetch was truncated before `components.schemas`, so it is UNVERIFIED against the raw OpenAPI file. Field lists come from the developer docs pages (WebFetch, summarized): Page{id, status, title, spaceId, parentId, parentType, position, authorId, ownerId, lastOwnerId, subtype, createdAt, version, body}; Space{id, key, name, type, status, authorId, spaceOwnerId, currentActiveAlias, createdAt, homepageId, description, icon}. |
| OSLC CM `ChangeRequest` | IRI `http://open-services.net/ns/cm#ChangeRequest` is recalled, not fetched: UNVERIFIED. It is recorded only as `skos:closeMatch` and guarded by a tripwire (ARD-012). |

## Ontology source

- File: `~/ash_atlassian/ontology/atlassian-profile.ttl` (Turtle, SHACL).
- Shapes only: local IRIs (`https://ggen.io/profile/ash-atlassian#...`) name `sh:NodeShape`
  instances. The court refuses any local `owl:Class`, `rdfs:Class` or property (ARD-007).
- `sh:targetClass` / `sh:path` are public terms, each resolved against a vendored, hash-pinned
  public ontology (ARD-004, ARD-006):

| Vocabulary | Vendored file (under `~/ggen-marketplace/ontologies/public/`) | sha256 |
|---|---|---|
| schema.org | `schema-org.ttl` | `7784da44bfa147e7c5e3f6eb710cb6e314077e885f3ff28cf954a8c734ee2086` |
| FOAF | `foaf.ttl` | `4db5eee6f999817846b7d71ab16eac627b13c8dba7b5b9747215c33fa80aa4ec` |
| DCMI Terms | `dublin-core-terms.ttl` | `77ac5110ef369facc765038073cc38396f5211b781a22f42e3ea66254dd8a510` |
| P-PLAN | `xaas-profile-batch-1/p-plan.owl` (RDF/XML) | `b426b2b8471f41a337256d3248fc0f595be8bc83e3969ac27c1dc51f689c5b32` |

- `sh:name` on a property shape is the Atlassian JSON field name and the Ash attribute name; on a
  node shape it is the resource module leaf; `dcterms:isPartOf` names the Ash domain. The property
  whose path is `schema:identifier` or `dcterms:identifier` is the resource identity.
- Object edges are not projected (gate 030). Value normalization (ADF rich text to text) is
  transport work, not ontology work.

## Resources

Bounded first slice. Attribute -> public property in parentheses.

| Ash resource | Public class | Attributes |
|---|---|---|
| `AshAtlassian.Jira.Issue` | `schema:CreativeWork` | id (identifier, key), key (alternateName), summary (name), description, created (dateCreated), updated (dateModified) |
| `AshAtlassian.Jira.Project` | `schema:Project` | id (identifier, key), key (alternateName), name, description, url |
| `AshAtlassian.Jira.User` | `foaf:Agent` | account_id (`schema:identifier`, key), display_name (`foaf:name`), email_address (`schema:email`) |
| `AshAtlassian.Jira.Transition` | `pplan:Step` | id (`dcterms:identifier`, key), name (`dcterms:title`) |
| `AshAtlassian.Confluence.Page` | `schema:WebPage` | id (identifier, key), title (name), body (text), created_at (dateCreated) |
| `AshAtlassian.Confluence.Space` | `schema:WebSite` | id (identifier, key), key (alternateName), name, description, created_at (dateCreated) |

Class choices are subsumption, not equivalence: an Issue is-a `CreativeWork`; a Jira user is an
Atlassian account (person, app or customer) so `foaf:Agent`, not `foaf:Person`; a workflow
transition is a step of the workflow plan; a Confluence space is a set of related pages.

Deferred, `UNSUPPORTED(ontology-term)` (no declared public term in the vendored set; not invented):

| Resource | Deferred fields |
|---|---|
| Issue | status, priority, issuetype, project, assignee, reporter, resolution, labels |
| Project | projectTypeKey, isPrivate, lead, avatarUrls |
| User | active, accountType, timeZone, locale |
| Transition | to (object edge), hasScreen, isGlobal, isInitial, isConditional, isLooped |
| Page | status, spaceId, parentId, authorId, ownerId, position, version |
| Space | type, status, homepageId, authorId, spaceOwnerId |

`schema:status` exists but is declared for medical studies, so it is not borrowed for Jira status.
OSLC CM (`cm:status`, `cm:priority`) is the intended home for issue status and priority once its
lock exists (follow-up SJ-010).

## Generator route

```text
ontology/atlassian-profile.ttl
   | ggen sync run   (5 SPARQL gates first; refuse writes nothing)
   v
ash-atlassian-GENERATED.sh              lib/ash_atlassian/semantics.ex
   | bash ash-atlassian-GENERATED.sh    (semantic map: class and property IRIs per resource)
   v
mix ash.gen.resource  x6   -> lib/ash_atlassian/{jira,confluence}/*.ex
                              Igniter also writes the two domains and config :ash_domains
mix format ; mix compile --warnings-as-errors
```

- Pack: `xaas-public-ash-projection-pack` (shape law, gates 010-040 adapted; see residue).
- ggen manifest: `~/ash_atlassian/ggen.toml`, rules `ash-igniter-construction` and `semantic-map`.
- Framework generators: `mix ash.gen.resource` with `--extend ets,Ash.Policy.Authorizer`. The
  authorizer with no policies makes every action denied by default; carve-outs are consumer-declared.
- `--conflicts replace` makes re-generation converge and byte-idempotent.
- The Atlassian OpenAPI documents are mapping input (which fields exist), not ontology source.

## Hand-written residue

Each row is an `UNSUPPORTED(generator-capability)` receipt (also in `~/ash_atlassian/HANDWRITTEN.md`).

| Path | Missing generator capability | Owner pack |
|---|---|---|
| `ggen.toml`, `queries/*.rq`, `templates/*.tera`, `gates/*.rq` | `xaas-public-ash-projection-pack` is fixed to the `Xaas.Resource` base, `Xaas.Public.<ClassLocalName>` names and uuid_v7 keys; no `sh:name` naming, domain grouping, identity-key rule, namespace option or semantic map | `xaas-public-ash-projection-pack` |
| `mix.exs`, `.formatter.exs`, `config/config.exs` | no pack renders a Hex package skeleton for a generated Ash library | `xaas-public-ash-projection-pack` |
| `test/**/*.exs` | no admitted pack emits ExUnit qualification for a generated Ash package | `semantic-gate-witness-court-pack` |

No Ash resource, domain or `lib/` module is hand-written; the court enforces this (ARD-008, ARD-009). Generated files are the
file each resource and domain module maps to, plus ggen rule outputs (`generated_files`); never a glob.

## Non-goals

- No HTTP transport, authentication or credential handling; a live Atlassian call needs a token or
  OAuth login that the environment must provide.
- No relationship projection (belongs_to / has_many) until it is independently admitted.
- No ADF rich-text normalization; `description` and `body` are plain string attributes.
- No Jira Software, Service Management, comments, worklogs, attachments or custom fields.
- No JSON:API or GraphQL exposure, no Postgres data layer; the ETS layer is a local mirror, not a
  system of record.
- No policy carve-outs and no Hex publish; no merge to main.

## Falsifiers

| Id | Falsifies the ARD if | Check |
|---|---|---|
| F1 | a resource is hand-written where the pack route generates it | ARD-008 and ARD-009 (`mix xaas.sjira.ard_court`) |
| F2 | a generated resource's class or attributes disagree with the profile | `cd ~/ash_atlassian && mix test test/ash_atlassian/generated_resources_test.exs` |
| F3 | regeneration changes committed bytes | `cd ~/ash_atlassian && mix test test/ash_atlassian/ggen_gates_test.exs` (positive control) |
| F4 | a class or path is not declared in a pinned public ontology, or a pin drifts | ARD-004 and ARD-006 |
| F5 | any action is authorized for an anonymous or arbitrary actor | `generated_resources_test.exs` deny-by-default tests |
| F6 | a gate does not fire on its violating profile | `ggen_gates_test.exs` negative witnesses (gates 010-050) |
| F7 | an OSLC CM lock appears while Issue still targets `schema:CreativeWork` | ARD-012 tripwire |
| F8 | Igniter output (resources, domains, config) drifts from the construction script | `cd ~/ash_atlassian && bash ash-atlassian-GENERATED.sh && git diff --exit-code -- lib config` |

## Alternatives

| Alternative | Standing |
|---|---|
| Local `atl:` vocabulary (`atl:Issue`, ...) | REJECTED: violates the no-local-vocabulary gate; equivalence to public terms is unproven |
| Generate resources straight from the OpenAPI JSON | REJECTED as semantic source (OpenAPI is mapping input); RETAINED as transport-generator candidate |
| OSLC CM `ChangeRequest` as the Issue class | RETAINED, pending a hash-pinned lock (tripwire ARD-012) |
| Jira MySQL schema in `~/atlassian` as source | REJECTED: internal schema of a hosted product inside a chat export |
| `ash-r2rml-paas-pack` route | REJECTED: PaaS kernel semantics |

## Follow-up work orders

Proposed, machine-consumable, not yet emitted as `SJ-*.md` files.

| Id | Deliverable | Depends on |
|---|---|---|
| SJ-010 | fetch and hash-pin the OSLC CM vocabulary lock; retarget Issue; add status and priority | none |
| SJ-011 | extend `xaas-public-ash-projection-pack` with namespace option, `sh:name` naming, identity key, semantic map, package skeleton; retire the residue rows | none |
| SJ-012 | transport (read client) generated from the OpenAPI mapping; live calls BLOCKED until the environment provides Atlassian credentials | SJ-011 |
| SJ-013 | admit relationship projection (issue -> project, transition -> status) | SJ-010 |
| SJ-014 | ADF and Confluence storage-format normalization | SJ-012 |

## Acceptance

```bash
mix xaas.sjira.ard_court docs/sjira/v26.9.21/ash-atlassian-ard.md \
  --receipt docs/sjira/v26.9.21/receipts/SJ-007-ard-court.json
```

Exit 0 means ACCEPTED. Exit 1 means REFUSED (a check failed and is named). Exit 2 means the court
could not run. The court reads files and executes nothing.

## Machine manifest

```json ard-manifest
{
  "schema": "xaas.sjira.ard-manifest/v1",
  "order": "SJ-007",
  "package": {"name": "ash_atlassian", "root": "~/ash_atlassian"},
  "ontology": {
    "source": "~/ash_atlassian/ontology/atlassian-profile.ttl",
    "format": "turtle",
    "kind": "shacl-application-profile"
  },
  "public_ontologies": [
    {
      "name": "schema-org",
      "namespace": "https://schema.org/",
      "path": "~/ggen-marketplace/ontologies/public/schema-org.ttl",
      "format": "turtle",
      "sha256": "7784da44bfa147e7c5e3f6eb710cb6e314077e885f3ff28cf954a8c734ee2086"
    },
    {
      "name": "foaf",
      "namespace": "http://xmlns.com/foaf/0.1/",
      "path": "~/ggen-marketplace/ontologies/public/foaf.ttl",
      "format": "turtle",
      "sha256": "4db5eee6f999817846b7d71ab16eac627b13c8dba7b5b9747215c33fa80aa4ec"
    },
    {
      "name": "dcterms",
      "namespace": "http://purl.org/dc/terms/",
      "path": "~/ggen-marketplace/ontologies/public/dublin-core-terms.ttl",
      "format": "turtle",
      "sha256": "77ac5110ef369facc765038073cc38396f5211b781a22f42e3ea66254dd8a510"
    },
    {
      "name": "p-plan",
      "namespace": "http://purl.org/net/p-plan#",
      "path": "~/ggen-marketplace/ontologies/public/xaas-profile-batch-1/p-plan.owl",
      "format": "rdfxml",
      "sha256": "b426b2b8471f41a337256d3248fc0f595be8bc83e3969ac27c1dc51f689c5b32"
    }
  ],
  "generator": {
    "pack": "~/ggen-marketplace/packs/xaas-public-ash-projection-pack",
    "pack_relation": "shape law and gates 010-040 adapted; capability gaps recorded as UNSUPPORTED",
    "manifest": "~/ash_atlassian/ggen.toml",
    "construction_script": "~/ash_atlassian/ash-atlassian-GENERATED.sh",
    "framework_generators": ["mix ash.gen.resource", "mix ash.extend"]
  },
  "resources": [
    {
      "name": "Jira.Issue",
      "module": "AshAtlassian.Jira.Issue",
      "system": "jira",
      "shape": "https://ggen.io/profile/ash-atlassian#Issue",
      "class": "https://schema.org/CreativeWork",
      "generator_route": {"rule": "ash-igniter-construction", "framework_generator": "mix ash.gen.resource"},
      "handwritten": false
    },
    {
      "name": "Jira.Project",
      "module": "AshAtlassian.Jira.Project",
      "system": "jira",
      "shape": "https://ggen.io/profile/ash-atlassian#Project",
      "class": "https://schema.org/Project",
      "generator_route": {"rule": "ash-igniter-construction", "framework_generator": "mix ash.gen.resource"},
      "handwritten": false
    },
    {
      "name": "Jira.User",
      "module": "AshAtlassian.Jira.User",
      "system": "jira",
      "shape": "https://ggen.io/profile/ash-atlassian#User",
      "class": "http://xmlns.com/foaf/0.1/Agent",
      "generator_route": {"rule": "ash-igniter-construction", "framework_generator": "mix ash.gen.resource"},
      "handwritten": false
    },
    {
      "name": "Jira.Transition",
      "module": "AshAtlassian.Jira.Transition",
      "system": "jira",
      "shape": "https://ggen.io/profile/ash-atlassian#Transition",
      "class": "http://purl.org/net/p-plan#Step",
      "generator_route": {"rule": "ash-igniter-construction", "framework_generator": "mix ash.gen.resource"},
      "handwritten": false
    },
    {
      "name": "Confluence.Page",
      "module": "AshAtlassian.Confluence.Page",
      "system": "confluence",
      "shape": "https://ggen.io/profile/ash-atlassian#Page",
      "class": "https://schema.org/WebPage",
      "generator_route": {"rule": "ash-igniter-construction", "framework_generator": "mix ash.gen.resource"},
      "handwritten": false
    },
    {
      "name": "Confluence.Space",
      "module": "AshAtlassian.Confluence.Space",
      "system": "confluence",
      "shape": "https://ggen.io/profile/ash-atlassian#Space",
      "class": "https://schema.org/WebSite",
      "generator_route": {"rule": "ash-igniter-construction", "framework_generator": "mix ash.gen.resource"},
      "handwritten": false
    }
  ],
  "generated_files": ["lib/ash_atlassian/semantics.ex"],
  "handwritten": [
    {
      "path": "ggen.toml",
      "element": "consumer-local generator surface: manifest",
      "unsupported": {
        "kind": "generator-capability",
        "missing_capability": "xaas-public-ash-projection-pack renders a script fixed to the Xaas.Resource base, Xaas.Public class-local-name modules and uuid_v7 keys; no sh:name attribute naming, domain grouping, identity-key rule, namespace option or semantic map",
        "owner_pack": "xaas-public-ash-projection-pack",
        "owner_pack_path": "~/ggen-marketplace/packs/xaas-public-ash-projection-pack"
      }
    },
    {
      "path": "queries/*.rq",
      "element": "consumer-local generator surface: SPARQL projection of the profile",
      "unsupported": {
        "kind": "generator-capability",
        "missing_capability": "same gap as ggen.toml: the pack query keys resource identity on the class local name and cannot read sh:name, dcterms:isPartOf or identity properties",
        "owner_pack": "xaas-public-ash-projection-pack",
        "owner_pack_path": "~/ggen-marketplace/packs/xaas-public-ash-projection-pack"
      }
    },
    {
      "path": "templates/*.tera",
      "element": "consumer-local generator surface: construction script and semantic map templates",
      "unsupported": {
        "kind": "generator-capability",
        "missing_capability": "same gap as ggen.toml: the pack template emits Xaas.Resource based constructors and no semantic map",
        "owner_pack": "xaas-public-ash-projection-pack",
        "owner_pack_path": "~/ggen-marketplace/packs/xaas-public-ash-projection-pack"
      }
    },
    {
      "path": "gates/*.rq",
      "element": "profile gates adapted from pack gates 010-040 plus gate 050 (shape completeness)",
      "unsupported": {
        "kind": "generator-capability",
        "missing_capability": "pack gates hard-code the xaas IRI prefixes and module-name rule; not parameterizable for another profile",
        "owner_pack": "xaas-public-ash-projection-pack",
        "owner_pack_path": "~/ggen-marketplace/packs/xaas-public-ash-projection-pack"
      }
    },
    {
      "path": "mix.exs",
      "element": "package skeleton: deps, version, description",
      "unsupported": {
        "kind": "generator-capability",
        "missing_capability": "no admitted pack renders a Hex package skeleton for an ontology-generated Ash library",
        "owner_pack": "xaas-public-ash-projection-pack",
        "owner_pack_path": "~/ggen-marketplace/packs/xaas-public-ash-projection-pack"
      }
    },
    {
      "path": "config/config.exs",
      "element": "Ash string-length and domain-validation config (Igniter appends ash_domains)",
      "unsupported": {
        "kind": "generator-capability",
        "missing_capability": "no admitted pack renders the Ash runtime config a generated Ash library needs",
        "owner_pack": "xaas-public-ash-projection-pack",
        "owner_pack_path": "~/ggen-marketplace/packs/xaas-public-ash-projection-pack"
      }
    },
    {
      "path": "test/**/*.exs",
      "element": "qualification tests: generated-vs-expected shape, deny-by-default, ETS round trip, real ggen gate witnesses",
      "unsupported": {
        "kind": "generator-capability",
        "missing_capability": "no admitted pack emits ExUnit qualification for a generated Ash package; semantic-gate-witness-court-pack binds gates to witnesses but does not emit ExUnit",
        "owner_pack": "semantic-gate-witness-court-pack",
        "owner_pack_path": "~/ggen-marketplace/packs/semantic-gate-witness-court-pack"
      }
    }
  ],
  "falsifiers": [
    {"id": "F1", "kind": "generator-coverage", "statement": "a resource is hand-written where the pack route generates it", "check": "mix xaas.sjira.ard_court docs/sjira/v26.9.21/ash-atlassian-ard.md (ARD-008, ARD-009)"},
    {"id": "F2", "kind": "shape-drift", "statement": "a generated resource's class or attributes disagree with the profile", "check": "cd ~/ash_atlassian && mix test test/ash_atlassian/generated_resources_test.exs"},
    {"id": "F3", "kind": "regeneration-drift", "statement": "regeneration changes committed bytes", "check": "cd ~/ash_atlassian && mix test test/ash_atlassian/ggen_gates_test.exs"},
    {"id": "F4", "kind": "public-term", "statement": "a class or path is not declared in a pinned public ontology, or a pin drifts", "check": "mix xaas.sjira.ard_court docs/sjira/v26.9.21/ash-atlassian-ard.md (ARD-004, ARD-006)"},
    {"id": "F5", "kind": "policy-floor", "statement": "any action is authorized for an anonymous or arbitrary actor", "check": "cd ~/ash_atlassian && mix test test/ash_atlassian/generated_resources_test.exs"},
    {"id": "F6", "kind": "gate-witness", "statement": "a profile gate does not fire on its violating profile", "check": "cd ~/ash_atlassian && mix test test/ash_atlassian/ggen_gates_test.exs"},
    {"id": "F7", "kind": "supersession", "statement": "an OSLC CM lock appears while Issue still targets schema:CreativeWork", "check": "mix xaas.sjira.ard_court docs/sjira/v26.9.21/ash-atlassian-ard.md (ARD-012)"},
    {"id": "F8", "kind": "regeneration-drift", "statement": "Igniter output (resources, domains, config) drifts from the construction script", "check": "cd ~/ash_atlassian && bash ash-atlassian-GENERATED.sh && git diff --exit-code -- lib config"}
  ],
  "non_goals": [
    "no HTTP transport, authentication or credential handling",
    "no relationship projection until independently admitted",
    "no ADF rich-text normalization",
    "no Jira Software, Service Management, comments, worklogs, attachments or custom fields",
    "no JSON:API or GraphQL exposure and no Postgres data layer; ETS is a local mirror, not a system of record",
    "no policy carve-outs, no Hex publish, no merge to main"
  ],
  "supersession_tripwires": [
    {
      "path": "~/ggen-marketplace/packs/xaas-public-ontology-profile/locks/oslc-cm-vocab.lock.toml",
      "shape": "https://ggen.io/profile/ash-atlassian#Issue",
      "must_target": "http://open-services.net/ns/cm#ChangeRequest"
    }
  ]
}
```
