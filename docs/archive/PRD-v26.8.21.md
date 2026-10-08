# Product Requirements Document — XaaS v26.8.21

Status: release candidate contract  
Release: 26.8.21  
Owning repository: `seanchatmangpt/xaas`  
Authority posture: OBSERVE / CONSTRUCT / VERIFY only in this PR; no merge, deploy, release, cloud actuation, billing actuation, or other consequential DO.

## 1. Product intent

XaaS v26.8.21 is the repository-wide convergence release that turns the existing Ash ecosystem into one internally consistent product surface. It is not a documentation refresh and it is not a patch around the legacy BEAMOps application. The release treats the Ash domains, Spark DSLs, Reactor workflows, JSON:API, GraphQL, AshTypescript, Phoenix transport, PostgreSQL schema history, generated clients, tests, CI, runtime image, and operator documentation as projections of one admitted system.

The product requirement is semantic closure: a capability described in documentation must exist in executable code; an executable surface must be represented in the architecture/reference docs; generated projections must be reproducible from the exact Ash DSL; schema history must replay from an empty database; and CI evidence must identify the exact commit it executed.

## 2. Baseline contradictions to eliminate

The v26.8.21 release is not acceptable while any of these observed contradictions remain:

- Mix reports `0.1.0` while the product is released on a calendar-versioned line.
- The repository pins Elixir 1.18.4 / OTP 27.2.4 while an admitted Ash dependency requires Elixir 1.20.
- The container defaults carry a third BEAM identity instead of sharing the repository toolchain contract.
- Canonical architecture documentation reports 69 Ash resources and 17 Operations resources while the configured seven-domain graph contains 70 and 18 respectively.
- Documentation describes AshTypescript as narrower than the executable domain configuration.
- Generated AshTypescript clients target RPC endpoints that are not mounted by Phoenix.
- The migration chain attempts to create AutoFDE tables more than once and repeats an already-applied webhook encryption migration.
- Gettext uses the deprecated backend API and therefore breaks warnings-as-errors compilation.
- Pull-request CI can execute GitHub's synthetic merge ref without proving the checked-out SHA is the PR head.
- Pull-request CI may push a container image even though a PR qualification run has no release authority.
- Release claims can drift because there is no whole-repository executable alignment audit.

## 3. Canonical product model

v26.8.21 has seven configured Ash domains and 70 registered domain resources:

| Domain | Resources |
| --- | ---: |
| `Xaas.Accounts` | 5 |
| `Xaas.Billing` | 7 |
| `Xaas.Governance` | 27 |
| `Xaas.Ledger` | 4 |
| `Xaas.Marketplace` | 2 |
| `Xaas.Operations` | 18 |
| `Xaas.Platform` | 7 |
| **Total** | **70** |

All seven domains remain projections of one Ash application. Resource ownership stays explicit; a resource may not be silently registered in multiple domains or exist as an unregistered `Xaas.Resource` module.

## 4. Functional requirements

### FR-1 — Canonical release identity

- A root `VERSION` file is the human- and machine-readable product version.
- `Mix.Project.config()[:version]` must equal `VERSION`.
- v26.8.21 uses Elixir 1.20.2 with OTP 28.5.0.2.
- `.tool-versions`, `mix.exs`, CI, and Docker defaults must agree on that BEAM line.
- The production image must compile with warnings treated as errors.

### FR-2 — Ash ecosystem closure

- All configured Ash domains and resources compile under the canonical toolchain.
- Spark verifiers must fail closed when DSL configuration is invalid.
- Reactor remains orchestration; it does not become an ambient authority mechanism.
- Ash policies remain the authorization boundary for resource actions.
- JSON:API, GraphQL, and AshTypescript are projections of admitted Ash actions rather than independent business-logic implementations.
- ProjectMeasure remains stateless and read/observe-only: no create/update/destroy action may be added.

### FR-3 — Exact-subject project measurement

The project measurement capability must:

- require an exact 40-hex commit SHA;
- observe GitHub Actions only through GET transport;
- apply exact SHA and half-open `[since, until)` admission locally;
- count excluded off-subject and out-of-window observations;
- distinguish pending, successful, failure-like, and absent evidence;
- classify failure-like evidence as `BUILD_BROKEN`, absent evidence as `UNKNOWN`, and clean observed CI no higher than `PARTIAL_ALIVE`;
- refuse conflicting duplicate run identities;
- emit deterministic replay-verifiable receipts;
- expose an Ash code interface, GET-only JSON:API route, query-only GraphQL projection, and AshTypescript RPC projection without broadening authority.

### FR-4 — Live AshTypescript transport

- Every generated RPC endpoint must be mounted by Phoenix.
- `/internal-api/rpc/run` and `/internal-api/rpc/validate` are the canonical endpoints.
- Both endpoints must pass through `KanbanWeb.Plugs.RequireInternalApiToken`.
- The RPC controller delegates directly to `AshTypescript.Rpc`; it may not create a second action implementation.
- The admitted RPC set for this release is read/observe-only: Accounts org listing, Billing subscription listing, Marketplace provider listing, and Operations project measurement.
- Generated TypeScript must be recreated from the exact Ash DSL and checked for zero drift in CI.

### FR-5 — Replayable PostgreSQL schema history

- A clean database must migrate from zero to head without duplicate-object errors.
- A table may have one canonical create migration.
- Later migrations alter that table rather than recreating it.
- The stale pending-backlog migration must not recreate the three AutoFDE planner request tables or repeat the webhook encryption migration.
- Token AshCloak storage must converge on `encrypted_extra_data :binary`.
- If legacy plaintext token metadata exists, migration must refuse destructive removal and require an explicitly authorized encryption backfill instead of guessing or discarding data.

### FR-6 — Warnings-as-errors compatibility

- The application must use the Gettext 1.x backend API.
- Shared Phoenix controller/component helpers must use the configured backend through the supported `use Gettext, backend: ...` interface.
- No ticket-local compiler warning may be accepted as harmless when CI treats warnings as errors.

### FR-7 — Exact-head CI and release authority

For pull requests:

- checkout must resolve to `github.event.pull_request.head.sha`;
- CI must assert `git rev-parse HEAD` equals the expected SHA before compilation;
- compilation, migrations/tests, formatter, release audit, generated-code checks, and bounded static analysis must execute against that exact subject;
- qualification may build a container but may not push an image, deploy, tag, or release.

For `main` pushes, existing release/deploy jobs remain separately authority-gated. This PR does not exercise those paths.

### FR-8 — Whole-repository alignment audit

`mix xaas.release_audit` is a release gate and must inspect all tracked files that can be validated deterministically. It must at minimum verify:

- version and BEAM identity convergence;
- configured Ash domain/resource census and unique ownership;
- registration of every source module using `Xaas.Resource`;
- unique table-creation ownership across the migration history;
- readable tracked text and absence of merge-conflict markers;
- valid tracked JSON;
- shell syntax for tracked `.sh` files;
- local Markdown link integrity;
- absence of known stale architecture-count claims;
- existence and version identity of this PRD;
- canonical AshTypescript endpoint agreement between config and Phoenix router.

The audit is observational and fail-closed. It may report findings but may not mutate the repository or external systems.

## 5. Non-functional requirements

### NFR-1 — Determinism

Equivalent admitted inputs must produce equivalent generated TypeScript, receipts, release-audit results, and migration structure. Exact subjects are SHA-addressed, not branch-name-addressed.

### NFR-2 — Security and authority

No release-alignment work may weaken existing token gates, expose sensitive Ledger/Accounts resources mechanically, add ambient mutation routes, or turn a CI qualification job into a release/deploy actor.

### NFR-3 — Reversibility

Design choices must preserve reversible lawful alternatives until a boundary requires selection. The release may add read projections and verifiers without forcing persistence or mutation semantics onto stateless capabilities.

### NFR-4 — Failure semantics

Unknown evidence remains `UNKNOWN`. Failed exact-subject CI is `BUILD_BROKEN`. Invalid configuration or unsafe migration preconditions are typed refusals. Documentation or generated-code drift is a release-audit failure, not silently corrected evidence.

### NFR-5 — Operability

The same release identity must be reproducible in developer toolchains, GitHub Actions, and the Docker builder. Runtime/operator documentation must describe the executable topology rather than a superseded implementation session.

## 6. Verification ladder

The release is qualified in this order:

1. exact-subject checkout identity;
2. dependency resolution on Elixir 1.20.2 / OTP 28.5.0.2;
3. `mix compile --warnings-as-errors`;
4. `mix xaas.release_audit`;
5. clean PostgreSQL migration and full `mix test --max-failures 1 --trace`;
6. `mix format --check-formatted`;
7. ProjectMeasure Chicago court;
8. read-only/no-mock ProjectMeasure guards;
9. `mix ash_typescript.codegen --check` or equivalent deterministic zero-diff court;
10. Dialyzer and unused-dependency checks where the repository's existing CI supports them;
11. container build with `push: false` on pull requests.

A later failure does not erase earlier evidence; it scopes standing to the last independently observed boundary.

## 7. Definition of Done

v26.8.21 is done only when all of the following are observed on one exact PR head:

- [ ] `VERSION`, Mix, `.tool-versions`, CI, and Docker identify v26.8.21 / Elixir 1.20.2 / OTP 28.5.0.2 consistently.
- [ ] `mix compile --warnings-as-errors` passes.
- [ ] `mix xaas.release_audit` passes over the complete tracked repository.
- [ ] A fresh PostgreSQL database migrates to head without duplicate schema creation.
- [ ] Full repository tests pass or every remaining failure is independently demonstrated to be outside the release diff and explicitly classified.
- [ ] All changed Elixir/HEEx files are formatter-clean.
- [ ] ProjectMeasure's exact-subject Ash/Spark/Reactor/API falsifier court passes.
- [ ] Generated AshTypescript code contains the Operations project measurement RPC, targets the authenticated internal endpoints, and has zero regeneration drift.
- [ ] Canonical architecture, AshTypescript, HTTP API, migration, testing, and operator docs agree with executable topology.
- [ ] Pull-request qualification performs no registry push, deployment, release, tag, or live cloud actuation.
- [ ] PR receipt records exact base/head SHA, commands, exits, falsifiers, generated status, migration status, rollback/refusal behavior, and remaining exclusions.

Until every applicable item is observed on the same exact head, the release standing is `PARTIAL_ALIVE` or `BUILD_BROKEN`, never inferred `ALIVE`.

## 8. Rollback

The release changes are code/config/schema-history corrections only. Before merge, rollback is branch/commit reversal. The token-storage migration is fail-closed when legacy plaintext data exists, so it cannot silently destroy that data. No rollback procedure in this PR is authorized to perform production database mutation, registry mutation, deployment, or cloud actuation.
