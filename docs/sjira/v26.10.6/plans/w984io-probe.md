# W984io — unclaimed-family probe: `Xaas.Resource` base macro

Lane: W984io · shared canonical checkout `/Users/sac/xaas` · branch `feat/playwright-surface` (no branch switch, no commit, no stash).
Subject: `lib/xaas/resource.ex` (+ `Xaas.Semantics.Registry`, `Xaas.Semantics.R2RML` as real collaborators). No `lib/` changes.

## O (read before court)

- `lib/xaas/resource.ex` (read in full): `__using__` delegates to `Ash.Resource` and
  injects exactly six functions: `ontology_projection/0`, `ontology_projection!/0`,
  `ontology_projection_hash/0`, `r2rml_mapping/0`, `r2rml_mapping!/0`,
  `r2rml_mapping_hash/0`, all via `defoverridable`.
- Prompt-hypothesized branches (base validations, timestamp touch, multitenancy
  defaults, base policy structure) DO NOT exist in the macro. Deny-by-default floors
  and timestamps are per-resource Ash surface. Classification done against the real
  macro surface, not the prompt's guess.

## Census vs test/ (branches)

| injected branch | classification | evidence |
|---|---|---|
| `ontology_projection/0` value | was UNCOVERED-value-wise (only `function_exported?` in `registry_test.exs`) | courted |
| `ontology_projection!/0` ok-arm | COVERED (`actuation_test.exs`, receipt hash bindings) | not restated |
| `ontology_projection!/0` raise-arm | UNCOVERED, unreachable for any admitted resource — `registry_test.exs` enforces every domain resource admits | typed UNCOVERED, documented |
| `ontology_projection_hash/0` | COVERED (`registry_test.exs`, receipt courts) | determinism+collision re-courted |
| `r2rml_mapping/0` + `_hash/0` on real domain resources | was COVERED on test fixtures only (`ash_r2rml_test.exs`) | courted on `Provider` |
| `r2rml_mapping!/0` raise-arm | was UNCOVERED (r2rml_refusal_test calls `R2RML.mapping/1` directly, never the injected bang) | courted |
| `defoverridable` override path | UNCOVERED, not courted — overriding a production resource's injected function in a test would be a shadow surface; left typed | UNCOVERED, documented |

## Court file

`test/xaas/resource_base_court_w984io_test.exs` — 6 tests, all passing.
Real resources: `Xaas.Conference.Sponsor` (ETS, no policies) and
`Xaas.Marketplace.Provider` (Postgres, deny-by-default floor + org-scoped bypasses)
through real `Ash.Changeset.for_create`/`Ash.create!`/`Ash.read!`; zero mocks.
Also a real compiled `__MODULE__.NoPkResource` fixture (same disclosed shape as
`r2rml_refusal_test.exs`) for the raise branch.

Newly witnessed findings:
1. `ontology_projection/0` == `Registry.admit/1` == `Registry.projection/1` == bang, both real resources (value-level, previously assertion-free).
2. Hash determinism + cross-resource non-collision.
3. **Real domain finding:** `Xaas.Conference.Sponsor` (ETS) refuses R2RML projection with `REFUSED_INVALID_LOGICAL_TABLE` — the macro's `r2rml_mapping/0` on a real non-relational production resource returns a typed refusal, previously only fixture-witnessed.
4. `r2rml_mapping!/0` raise-arm witnessed twice (ETS refusal + no-pk refusal).
5. Timestamp touch under real actions (Ash core, asserted as context only; policy floors not restated).

## Gates (real output)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984io mix test test/xaas/resource_base_court_w984io_test.exs` → `Result: 6 passed` (initially 2/6; 4 failures were lane-own test bugs, fixed in-lane: for_create form, struct-vs-module bang call, nested-module resolution, single-refusal-vs-list shape).
- Mock gate: `scan_mock_usage(["test","lib"])` → `[]`.
- Adjacent regression `registry_test + ash_r2rml_test + r2rml_refusal_test` → `Result: 11 passed`.

## Standing

ALIVE for the court file and the census. No commit (lane law). Falsifier for future
mutation: any change to the injected bodies (`lib/xaas/resource.ex`) must flip at
least one of the 6 courts; if it doesn't, the court is vacuous and must be repaired.
