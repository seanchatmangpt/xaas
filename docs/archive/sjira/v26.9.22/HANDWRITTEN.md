# HANDWRITTEN — docs/sjira/v26.9.22

Hand-written residue in this directory, each row with its generator-capability status.
The canonical source is `work-orders.ttl`; everything a generator could produce from it
is listed here until that generator exists.

| File | Role | Status |
|---|---|---|
| `project.py` | TTL -> `wo.json`, `index.json`, `jira/<ID>.md` projection (rdflib) | UNSUPPORTED(generator-capability): pending GGEN_IGNITER-26922-08 (TTL->work-order loader in semantic-jira-pack) |
| `seed/author_ttl.py` | One-time seed of the first `work-orders.ttl` revision from `/Users/sac/wt/v26922/survey.json` `synth.v26_9_22` | UNSUPPORTED(generator-capability): pending GGEN_IGNITER-26922-08; provenance only, never re-run over an edited graph |
| `shacl.exs` | Runner that calls `GgenIgniter.SemanticJira.Shacl.validate_file/1` over `work-orders.ttl` and groups violations | UNSUPPORTED(generator-capability): pending a pack-level SHACL court entry for external graphs |
| `admit.exs` | Admission driver over `wo.json` (verbatim copy of `docs/sjira/v26.9.21/admit.exs`) | Carried precedent; retires with GGEN_IGNITER-26922-08 |
| `sa2a_loop.exs` | SA2A plan/admit/replay driver (v26.9.21 copy, paths and plan id changed) | Carried precedent |

Projections that must never be edited by hand: `wo.json`, `index.json`, `jira/*.md`.
`python3 project.py --check` exits 1 when any of them differs from a fresh projection.
