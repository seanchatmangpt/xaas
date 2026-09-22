# Phase D — Technology Architecture

## Reference topology

```
Phoenix / LiveView
       │
Ash domain
       │
Postgres ── OCEL
       │
RDF / SHACL / SPARQL
       │
sJira / SA2A
       │
Receipts / replay
```

## Manufacture topology

```
RDF/SHACL
→ ggen/ggen_igniter
→ Pydantic/FastAPI
→ Zod/Next.js
→ Playwright
```

## Design test

If replacing a framework changes the meaning of KNOWN, authority, evidence, work or MachineExperience, the semantic architecture is not yet sufficiently separated from implementation.
