# ARD — ash_atlassian migration target (SJ-007)

- **Order**: SJ-007 `ash-atlassian-target` (this directory, `007-ash-atlassian-target.md`)
- **Date**: 2026-09-21 · **Branch**: `sjira/sj-007` · **Base**: seanchatmangpt/xaas @ `8e72cfc`
- **Scope**: turn `BLOCKED:NO_TARGET_PACKAGE` into a buildable order set. This ARD names the
  target package, the resource set, the ontology source, and the generator route through
  ggen-marketplace. It builds nothing: path scope of the order is `docs/sjira/**`.

## 1. Verified evidence (commands run this session)

| Command | Result |
|---|---|
| `ls ~/ash_atlassian` | `No such file or directory` (exit 1) — no local target |
| `gh repo view seanchatmangpt/ash_atlassian` | GraphQL: could not resolve to a Repository — no remote target either |
| `file ~/atlassian` | ASCII text, 1,117,044 bytes, 26,850 lines |
| `grep -n "migrating all of the atlassian" ~/atlassian` | exactly one hit, line 3491 |

Evidence correction to the order: `~/atlassian` is **not** an empty stub — it is the
whitepaper source itself: a ChatGPT export containing the migration thesis, the Issue
resource design, the enum designs, and the Atlassian-in-Ash domain-structure guidance
cited below. The blocker stands (no target package), but the source is alive and quotable.

## 2. Whitepaper source extraction (~/atlassian, line-cited)

- **Thesis** (line 3491): *"We are migrating all of the atlassian systems to Ash but
  simplified. AshAi is the engine behind Rovo."*
- **Issue resource** (lines 2453–2591): title/description (string), priority + status
  (constrained strings, later retyped), `belongs_to` creator (required) and assignee
  (optional), `has_many` comments, update_status action, policies.
- **Enums** (lines 2628–2665): `MyApp.Issue.Status` values `open,in_progress,closed,resolved`
  and `MyApp.Issue.Priority` values `low,medium,high,urgent`, both manufactured by
  `mix ash.gen.enum` — i.e. the whitepaper itself routes enums through the Ash generator.
- **AshAi** (lines 2943–3492): exposes admitted Ash actions as AI tools — the "Rovo" engine.
- **Domain structure** (lines 9045–9215): one Ash domain per product
  (`Atlassian.Jira` → Issue, Project; `Atlassian.Confluence` → Page, Space;
  `Atlassian.Rovo` → insights), singular resource names, code interfaces on the domain.
- **Tests** (lines 9372–9423): domain-level resource tests (`Jira.Issues.IssueTest`).

## 3. Target package

| Property | Value |
|---|---|
| Repository | `seanchatmangpt/ash_atlassian` (greenfield; neither local checkout nor GitHub remote exists — verified §1) |
| Shape | standalone Mix application (single OTP app `:ash_atlassian`), Ash + AshPostgres, Chicago-style tests, no mocks |
| Module root | `AshAtlassian` (app name owns the root; whitepaper's `Atlassian.*` is the concept map, not the module root) |
| Domains | `AshAtlassian.Jira`, `AshAtlassian.Confluence` (phase 1); Rovo is engine wiring, not a domain — §6 |
| Base resource | `AshAtlassian.Resource` (mirrors the `Xaas.Resource` base-resource pattern the projection template already renders) |
| Scaffold route | `mix igniter.new` + `mix igniter.install ash,ash_postgres` — framework generators own the mutation; no pack fits (failed edge e5, §6) |

## 4. Resource scope (phase 1 — simplified core)

Every row is **generated from a public-ontology class through the pack projection**
(§5–§6). Enum values follow the whitepaper (§2); they are application-profile decisions,
not claims about the source vocabularies.

| Ash resource (module) | Public class (`sh:targetClass`) | Datatype attributes (`sh:path` → type) |
|---|---|---|
| `AshAtlassian.Jira.Issue` | `oslc_cm:ChangeRequest` | `dcterms:title` → string (required); `dcterms:description` → string; `dcterms:identifier` → string (issue key); `oslc_cm:status` → enum `open,in_progress,closed,resolved`; `oslc_cm:priority` → enum `low,medium,high,urgent` |
| `AshAtlassian.Jira.Project` | `doap:Project` | `doap:name` → string (required); `doap:shortdesc` → string; `doap:description` → string |
| `AshAtlassian.Confluence.Space` | `sioc:Space` | `dcterms:title` → string (required); `dcterms:description` → string |
| `AshAtlassian.Confluence.Page` | `sioc:Post` | `dcterms:title` → string (required); `sioc:content` → string (page body) |
| `AshAtlassian.Confluence.Comment` | `schema:Comment` | `schema:text` → string (required); `dcterms:created` → utc_datetime |
| `AshAtlassian.Confluence.Person` | `foaf:Person` | `foaf:name` → string (required); `foaf:mbox` → string |

Namespace IRIs: `oslc_cm:` http://open-services.net/ns/cm# · `doap:` http://usefulinc.com/ns/doap# ·
`sioc:` http://rdfs.org/sioc/ns# · `dcterms:` http://purl.org/dc/terms/ ·
`schema:` https://schema.org/ · `foaf:` http://xmlns.com/foaf/0.1/

Phase-2 relationship edges (all fail-closed today — see e3, §6 — none hand-written):

- `Issue —dcterms:creator→ Person` (belongs_to, required) · `Issue —dcterms:contributor→ Person` (assignee, optional)
- `Page —sioc:has_container→ Space` (belongs_to) · `Comment —dcterms:creator→ Person` (belongs_to)
- `Issue —schema:comment→ Comment` (has_many)

Out of scope phase 1: Loom, Goals/Atlas, JSM, boards/workflows, Rovo agent runtime.
The whitepaper's "all systems" ambition extends by the same pattern (new public classes +
profile facts), never by new hand-written resources.

## 5. Ontology source

Owner: **ggen-marketplace** (`seanchatmangpt/ggen-marketplace` @ `f1c350b`), pinned public
ontologies under `ontologies/public/` with the MANIFEST discipline (real retrieval, HTTP 200,
SHA-256, publisher, disclosed failures — `xaas-profile-batch-1/MANIFEST.md`).

| Vocabulary | Status today | Action |
|---|---|---|
| `dcterms` (`dublin-core-terms.ttl`), `doap.rdf`, `foaf.ttl`, `schema-org.ttl` | **already pinned** in `ontologies/public/` | reuse as-is |
| OSLC CM (`oslc_cm:`) | not pinned (batch 1 pinned automation/config/rm only) | pin per MANIFEST discipline → SJ-010 |
| SIOC (`sioc:`) | not pinned | pin per MANIFEST discipline → SJ-010 |

Law (from the family's gates): no local `owl:Class`/`rdf:Property` vocabulary;
`sh:targetClass` and `sh:path` must be public IRIs (`xaas-ash-core-pack/gates/010_no_custom_vocabulary.rq`,
`020_public_target_classes.rq`; projection-pack equivalents `gates/010_no_native_domain_vocabulary.rq`,
`020_public_targets_only.rq`). Therefore **no `Atlassian.*` RDF classes are created**:
`AshAtlassian.*` modules are implementation consequences mechanically derived from public
class IRIs plus a profile-declared consumer namespace (e1, §6). A custom-namespace route
would require a recorded failed-edge against this public set; none exists — the public set covers it.

## 6. Generator route (search ladder, run 2026-09-21)

REUSE survey over `~/ggen-marketplace/packs/` by capability family
("SHACL/RDF → Ash/Igniter generator commands"):

| Candidate | Verdict |
|---|---|
| `xaas-public-ash-projection-pack` | **owns the projection law** (public SHACL → `mix ash.gen.*`; fail-closed relationships; collision refusal). Almost fits — see e1–e3 |
| `xaas-ash-core-pack` | same family, TOGAF-scoped profile shell (`profiles/public-shapes.ttl` empty on purpose); carries the same bindings — co-extended with its sibling |
| `ggen-igniter-bootstrap-pack` | REFUSED for this job — manufactures `ggen_igniter`'s own module scaffold only (failed edge e5) |
| `ash-extension-pack` / `ash-r2rml-*` | REFUSED — different family (Ash extension modules / R2RML mapping), not application resources |
| no pack at all (hand-written resources) | REFUSED — trips this order's falsifier |

Failed edges of the almost-fit (recorded, not pruned):

- **e1 namespace binding** — `queries/ash-gen-commands.rq` in both family packs (projection pack line 17, core pack line 15)
  hard-bind `Xaas.Public.<LocalName>` / domain `Xaas.Public`. Target needs a consumer-declared
  namespace (`AshAtlassian` root + product domain segment). Fix: profile/consumer-level
  namespace fact in the pack's generation config (ggen.toml), keeping module names mechanical
  consequences, per the pack's own law ("module names are implementation consequences, not RDF facts").
- **e2 enum projection** — only datatype shapes project today; `sh:in`-constrained strings
  degrade to plain strings. Whitepaper enums need `mix ash.gen.enum` + enum-typed attribute.
- **e3 relationship projection** — object properties fail closed (gate `xaas-ash-core-pack/gates/060_object_property_projection_pending.rq` / projection pack `030_relationship_projection_pending.rq`;
  README law). Phase-2 edges need an admitted object-property→relationship correspondence,
  still pack-routed; default stays fail-closed.
- **e4 AshAi (Rovo) wiring** — no pack projects `AshAi` tool exposure. Until a pack fact
  exists, any such byte is `UNSUPPORTED(public-ash-projection-family, ash_ai_tool_wiring)`
  + a `HANDWRITTEN.md` row in the target repo — the only admitted hand-written residue, and it
  must shrink. Gated on SJ-009 (ash_ai dependency retest) resolving COMPATIBLE.
- **e5 scaffold** — no marketplace pack scaffolds greenfield consumer apps; `mix igniter.new` /
  `mix igniter.install` are the framework's own generators, so the mutation stays generator-owned.

Decision: **EXTEND the `xaas-public-ash-projection-pack` family; INVENT nothing.**
No new top-level pack; the Atlassian facts enter the family as profile facts + pack tests.

## 7. Hand-written budget (產面 residue for the follow-on build)

| Byte | Owner | Standing |
|---|---|---|
| Resource/domain/enum/repo modules | projection family via `mix ash.gen.*` | 0 hand-written |
| Tests for generated resources | target repo, Chicago-style (real Ash actions, real Postgres) | tests are consumer proof, not resource manufacture — permitted, pack-owned factories preferred where a pack can render them |
| AshAi tool wiring (phase 3) | future pack fact | `UNSUPPORTED` + `HANDWRITTEN.md` row until then (e4) |

## 8. Follow-up work orders

Emitted now as new SJ files in this directory (all against `seanchatmangpt/ggen-marketplace`
@ `f1c350b` — honestly based today; admissible by `GgenIgniter.SemanticJira.admit_work_order/1`):

| Order | File | Delivers | Depends |
|---|---|---|---|
| SJ-010 | `010-atlassian-public-vocab-pin.md` | pin OSLC CM + SIOC into `ontologies/public/xaas-profile-batch-2/` with MANIFEST discipline | — |
| SJ-011 | `011-public-ash-projection-extend.md` | family extension: consumer namespace (e1), `sh:in` enum projection (e2), relationship correspondence behind explicit admission (e3), with pack tests | — |
| SJ-012 | `012-ash-atlassian-profile-admit.md` | admit the §4 SHACL application profile; gates 010/020 green; `ggen sync` renders `AshAtlassian`-namespaced construction commands | SJ-010, SJ-011 (receipts) |

Issuance-gated (recipe fixed here; **not** emitted — no truthful `base_sha` can exist for a
repo with zero commits, and admission of a fabricated base is refused by evidence law):

1. **Scaffold + execute** (repo `seanchatmangpt/ash_atlassian`): `mix igniter.new ash_atlassian`
   + `mix igniter.install ash,ash_postgres`; register as marketplace consumer; run the
   SJ-012-rendered construction program; `mix test` green on generated resources.
   *Emit as an SJ order after the first scaffold commit exists.*
2. **Relationship edges**: phase-2 §4 edges through the e3-extended projection. *Emit after 1.*
3. **Rovo wiring**: `AshAi` tool exposure of admitted actions, gated on SJ-009 COMPATIBLE;
   any hand-written byte enters `HANDWRITTEN.md` with the e4 `UNSUPPORTED` owner. *Emit after 1.*

## 9. Falsifier self-audit

- *ARD proposes hand-written resources where a pack could generate them* — **survives**: §4
  routes every resource/attribute/enum through the projection family (`mix ash.gen.*`);
  relationships stay pack-routed behind e3; the only hand-written candidate (AshAi wiring) is
  an explicit `UNSUPPORTED` + ledger row (e4), and the scaffold route is generator-owned (e5).
- Side-check: no second hand-edited copy of anything a projection owns — this ARD cites
  `generate.py` as the single manufacturer of the SJ files it emits.

## 10. Receipts

See `receipts/sj-007-*.json` (manufacture + verification classes): DoD check exit code,
regeneration byte-stability, and the real `admit_work_order/1` run over the emitted set.
