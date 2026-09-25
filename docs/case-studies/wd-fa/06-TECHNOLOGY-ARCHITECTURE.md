# Technology Architecture

## Reference stack

| Concern | Reference technology | Architectural reason |
|---|---|---|
| domain/runtime | Elixir + Ash | typed resources/actions, policy, composable domain |
| concurrency | BEAM/OTP | durable process supervision and bounded capability execution |
| persistence | Postgres | transactional source for reference runtime |
| event evidence | OCEL 2.0 | object-centric process/evidence representation |
| semantics | RDF/SHACL/SPARQL | public graph model + executable constraints |
| work | sJira | semantic obligation/evidence projection |
| capability interaction | SA2A | typed bounded capability contracts |
| manufacture | ggen/ggen_igniter | deterministic graph→artifact projection |
| alternate API | FastAPI/Pydantic | legible generated target stack |
| alternate UI | Next.js/Zod | legible generated target stack |
| browser verification | Playwright | user-visible exact-path court |

## Technology neutrality

The architecture does not depend on a particular frontend framework, LLM vendor or database product for its meaning.

```
SupplierIdentity ∉ CoreOntology
RuntimeIdentity  ∉ CoreSemantics
```

Implementations are replaceable projections if they preserve canonical semantics, constraints, authority and evidence.

## Intelligence placement

General LLM reasoning is an exception path for unresolved novelty, not a structural dependency for KNOWN cases.

```
KNOWN → deterministic machinery
UNKNOWN → bounded frontier reasoning → candidate → admission → formalization
```
