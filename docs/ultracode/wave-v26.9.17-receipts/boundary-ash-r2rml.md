# Boundary receipt: qualify-boundary(ash_r2rml, cap-semantic-feedback)

Final standing: **ALIVE** — FOND verify-boundary outcome: **qualified**

- Agent: implementation agent 2/10, SA2A release v26.9.17 qualification wave (2026-09-17)
- Repo: /Users/sac/ash_r2rml
- Pinned head: `7d958a8c47a5a3459a515ac6f81a4d2d2d84dd16`
- Branch: `epoch/v26.9.15-semantic-subject`
- Drift: none — re-pinned before and after the court, byte-identical; working tree clean (no tracked changes, no untracked files)

## 1. Court discovery (cheapest gate first)

- `.github/workflows/ci.yaml` — five CI gates: `types`, `release-security`, `production`, `test`, `obda`. Locally runnable database-free court = `mix compile --force --warnings-as-errors` + `mix test` (release-security job form).
- Live/adversarial engine tests self-skip absent docker: `test/support/docker_infra_check.ex:87-92` (`skip_reason/0`), applied via `@moduletag skip:` in `test/adversarial_closure_test.exs`, `test/adversarial/sparql_parity_test.exs`, `test/adversarial/ontop_postgres_test.exs`. CI covers them in `test`/`obda` jobs with docker compose + Ontop 5.5.0.
- Toolchain: repo `.tool-versions` = elixir 1.18.4-otp-27, erlang 27.2.4 (asdf-resolved from repo dir).

## 2. Court run (exact commands + exits)

| Command | Exit | Result |
|---|---|---|
| `mix deps.get` | 0 | "All dependencies are up to date" (91 deps present) |
| `mix compile --force --warnings-as-errors` | 0 | 113 files compiled, `Generated ash_r2rml app`, zero warnings |
| `mix test` | 0 | **738 tests, 0 failures, 9 skipped**, 16.2s |

The 9 skips = the docker-gated live-topology tests named above (Ontop/Postgres/SPARQL-parity adversarial suites). No compile warnings on lib; the only warnings visible during `mix test` are unused-clause warnings in `test/negative/*` support helpers (test-env only, not gate-relevant; the warnings-as-errors gate is lib compile and passed clean).

## 3. Capability probe — owns predicate HOLDS

The semantic-feedback capability (relational → RDF projection feeding the loop's learning path) is genuinely owned here:

- **R2RML mapping IR**: `lib/ash_r2rml/mapping.ex` — `AshR2RML.Mapping.*` bundle structs (TriplesMap/SubjectMap/PredicateObjectMap/ReferenceObjectMap/JoinCondition) + typed fail-closed `AshR2RML.Refusal` codes (`mapping.ex:6-52`).
- **R2RML renderer**: `lib/ash_r2rml/renderers.ex:5-7` — `AshR2RML.R2RML`, "Deterministic W3C R2RML renderer over `AshR2RML.Mapping.Bundle`"; `rr:` prefix `renderers.ex:26`; `rr:TriplesMap` / `rr:logicalTable` / `rr:subjectMap` emission `renderers.ex:109-111`; `rr:parentTriplesMap` reference maps `renderers.ex:196,225`.
- **Ash → mapping compiler**: `lib/ash_r2rml/compiler.ex:99` (`AshR2RML.Compiler`), `compile/2` `compiler.ex:126`, `compile_resources/1` `compiler.ex:453`; receipt hashes incl. `r2rml_sha256` (`compiler.ex:17`).
- **Runtime relational → RDF projection**: `lib/ash_r2rml/obda_in_memory.ex:5,139` — `AshR2RML.OBDA.InMemory.query/4` (real `Ash.read!/2` + in-process SPARQL algebra); dual-engine contract `lib/ash_r2rml/obda/adapter.ex:5-25` (InMemory vs Ontop CLI).
- **Feedback/learning loop**: `lib/ash_r2rml/knowledge_hooks.ex` — typed hooks `:ask | :result_delta | :external_trigger | :shacl | :datalog | :threshold | :count | :temporal_window` over SPARQL queries against the projection.
- **Test coverage of the capability (executed in this session's passing suite)**:
  - `test/public_mapping_test.exs:80,110` — `AshR2RML.R2RML.render/1` emits real R2RML; assertions on `rr:joinCondition` (:81), `rr:tableName "memberships"` / `rr:predicate <https://schema.org/memberOf>` (:112-114)
  - `test/ash_r2rml_resource_test.exs:83,91` — relationship dependency closure then `AshR2RML.render/1`
  - `test/obda_in_memory_test.exs` (+ `_cloak`, `_other_data_layers`) — projection queried over relational state
  - `test/knowledge_hooks_test.exs:53-220` — ASK hooks content-addressed, intent construction without authority, observation receipts, result-delta identity comparison (the learning path's feedback semantics)
- Repo's own ownership statement: `lib/ash_r2rml/AGENTS.md` — "AshR2RML is a W3C R2RML/SHACL semantic compiler for Ash"; canonical object = admitted closed operational ontology as `AshR2RML.SemanticIR` projecting to Ash / PostgreSQL / R2RML.

## 4. Classification

- Build: not broken (compile gate clean, zero warnings). No repair branch needed — `fix/ash-r2rml-v26.9.17-boundary` not created.
- Blocked: no — no lawful-alternate discovery required.
- UNSUPPORTED: no — no missing extension to report.
- **Outcome: qualified. Standing: ALIVE** (observed execution of the exact capability surface — R2RML render, OBDA in-memory projection, knowledge hooks — against pinned `7d958a8`, in this session, with the repo's own verifier).

## 5. Falsifiers attempted

1. "Warnings in output = build-broken" — falsified: warnings are test-env-only helpers; the warnings-as-errors gate exited 0 with zero lib warnings.
2. "Skips hide real failures" — falsified: all 9 skips are `DockerInfraCheck`-gated live docker tests; the database-free court (CI `release-security` shape) is green.
3. "owns predicate wrong (capability lives elsewhere)" — falsified: renderer + compiler + projection + hook surface cited above, with passing tests exercising each layer.
4. "Pinned head drifted during the wave" — falsified: rev-parse identical pre/post court; tree clean.

## 6. Boundary note (honest scope)

The docker-topology adversarial suite (Ontop 5.5.0 over PostGIS, SPARQL parity) did not execute locally — it is CI `test`/`obda` job scope requiring docker compose. This receipt claims ALIVE on the database-free court plus executed capability-probe tests, not on live-engine parity.

## 7. What the operator did NOT have to write

Everything. Zero bytes authored on 産面 this session: no source edits, no fixes, no fix branch, no hand-written projections. The boundary qualified purely through reading + executing the repo's own court. 比 this session: 0 hand-written / 0 delivered lines (pure verification; no production change required).
