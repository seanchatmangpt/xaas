---
{
  "identity": "SJ-004",
  "title": "Adopt Xaas.Resource on the registry-exempt resources",
  "description": "test/xaas/semantics/registry_test.exs carries a disclosed `@pending` exemption list (CouplingRun, EventLog, AutofdePlannerCacheHotset/CacheStats/Candidate/Catalog/Match; plus library-generated RevokeNonce and *.Version). Migrate the seven owned resources to `use Xaas.Resource` (base_resources) and shrink the list to library-generated only.",
  "subject": "resource-adoption-registry-exemptions",
  "repository": "seanchatmangpt/xaas",
  "base_sha": "8e72cfcb85bd901ad067589295598eb7580a1442",
  "standing": "ALIVE",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "promotion_rule": "verified_by_required_courts_then_receipted",
  "replay_identity": "sjira-v26.9.21-sj-004",
  "required_courts": [
    "compile",
    "tests",
    "chicago_no_mocks"
  ],
  "required_evidence": [
    "command_exit_codes",
    "real_output"
  ],
  "acceptance": [
    "`@pending` contains only RevokeNonce",
    "`mix test test/xaas/semantics` passes",
    "deny-by-default policy floor preserved on each touched resource"
  ],
  "falsifiers": [
    "a migrated resource gains an allow-all policy",
    "projection admission passes but ontology_projection_hash is nil"
  ],
  "projections": [
    "jira",
    "verification",
    "receipt"
  ],
  "dependencies": [],
  "authority_requirement": "NONE",
  "path_scope": [
    "lib/xaas/coupling/**",
    "lib/xaas/ledger/**",
    "lib/xaas/operations/autofde_planner_*",
    "test/xaas/semantics/registry_test.exs"
  ],
  "required_receipt_classes": [
    "manufacture",
    "verification"
  ]
}
---

# SJ-004: Adopt Xaas.Resource on the registry-exempt resources

- **Standing**: ALIVE (bounded: see Receipts; full-suite `mix test` NOT RUN at the verified head)

## Status
ALIVE
- **Repository**: seanchatmangpt/xaas @ `8e72cfc` (order base); observed at merge head `0f73fa8` = main `2ec5fdb` + `sjira/sj-004`

## Description
test/xaas/semantics/registry_test.exs carries a disclosed `@pending` exemption list (CouplingRun, EventLog, AutofdePlannerCacheHotset/CacheStats/Candidate/Catalog/Match; plus library-generated RevokeNonce and *.Version). Migrate the seven owned resources to `use Xaas.Resource` (base_resources) and shrink the list to library-generated only.

## Evidence
- commit on main: 'exempt library-generated resources in registry test'
- `Xaas.Resource` is the configured base_resources entry in config/config.exs

## Definition of done
- [x] `@pending` contains only RevokeNonce
- [x] `mix test test/xaas/semantics` passes
- [x] deny-by-default policy floor preserved on each touched resource

Runnable check:

```sh
cd ~/xaas && mix test test/xaas/semantics && mix test
```

## Falsifiers
- a migrated resource gains an allow-all policy
- projection admission passes but ontology_projection_hash is nil

## Receipts

Stream `errc2/sj004-registry`, subject head `0f73fa8` (merge of `sjira/sj-004` `1b07a29` into main
`2ec5fdb`; code-identical to the branch head, later commits are docs only). Full transcript and
logs: `docs/streams/sj004-registry.md`.

| Court | Command | Result |
|---|---|---|
| compile | `mix compile --warnings-as-errors` | exit 0 |
| tests | `MIX_TEST_PARTITION=sj004r mix test test/xaas/semantics test/xaas/operations test/xaas/coupling test/xaas/ledger` | exit 0, 63 tests, 0 failures (5 excluded); `test/xaas/ledger` does not exist in this repo |
| tests | `mix test test/xaas/semantics --trace` | 9 tests, 0 failures, includes "every configured Ash resource admits a public-ontology projection" |
| tests | union: 27 files (every file touching the seven resources + every wave-1 failing file), `--max-cases 4` | exit 0, 199 tests, 0 failures |
| tests | ontology/actuation binders (`actuation_test`, `actuation_ocel_undo_test`, `causal_admission_test`, `semantics_computation_test`, `graphql_schema_test`, `ontology/`) | exit 0, 18 tests, 0 failures (6 excluded) |
| admission | `MIX_ENV=test mix run` over the seven | all seven `{:ok, projection}`, 64-hex `ontology_projection_hash`, equals `Registry.hash/1` |
| exemptions | registry walk of 98 configured resources | resources without `ontology_projection_hash/0`: `Accounts.Token.RevokeNonce` and six `*.Version` (library-generated) only |
| policy floor | `Ash.Policy.Info` fingerprint (authorizers, policies, extensions, actions) base vs head | identical for all seven |
| migrations | `mix ash_postgres.generate_migrations --check` | exit 1 at head AND at base `2ec5fdb`: 3 pending files (one migration plus snapshots for `billing_revenue_recognitions` and `ultracode_runs`), byte-identical `--dry-run` output at both, none touching the seven resources; pre-existing, not introduced |
| format | `mix format --check-formatted` | exit 0 |
| chicago | mock grep over `test/ lib/` | 6 hits, all false positives (see stream notes); zero mock usage |

Bound: the full `mix test` from the runnable check above was not run at this head. Wave-1's two full
runs failed only by DBConnection pool exhaustion or `:eaddrinuse` under host load; the union of
those failing files reruns green (199 tests, 0 failures). Failures introduced by this change: none
observed. Pre-existing on base: `mix ash_postgres.generate_migrations --check` (exit 1), the
`AshR2RMLTest.UnsupportedResource` domain warnings.

`Xaas.Ledger.EventLog` has no `Ash.Policy.Authorizer` and no policies at base or head (AshEvents log
resource); adoption of `Xaas.Resource` did not change that. Whether it should gain a floor is a
separate decision, not taken here.
