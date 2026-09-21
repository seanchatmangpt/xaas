---
{
  "identity": "SJ-004",
  "title": "Adopt Xaas.Resource on the registry-exempt resources",
  "description": "test/xaas/semantics/registry_test.exs carries a disclosed `@pending` exemption list (CouplingRun, EventLog, AutofdePlannerCacheHotset/CacheStats/Candidate/Catalog/Match; plus library-generated RevokeNonce and *.Version). Migrate the seven owned resources to `use Xaas.Resource` (base_resources) and shrink the list to library-generated only.",
  "subject": "resource-adoption-registry-exemptions",
  "repository": "seanchatmangpt/xaas",
  "base_sha": "8e72cfcb85bd901ad067589295598eb7580a1442",
  "standing": "PARTIAL_ALIVE",
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

- **Standing**: PARTIAL_ALIVE

## Status
PARTIAL_ALIVE
- **Repository**: seanchatmangpt/xaas @ `8e72cfc`

## Description
test/xaas/semantics/registry_test.exs carries a disclosed `@pending` exemption list (CouplingRun, EventLog, AutofdePlannerCacheHotset/CacheStats/Candidate/Catalog/Match; plus library-generated RevokeNonce and *.Version). Migrate the seven owned resources to `use Xaas.Resource` (base_resources) and shrink the list to library-generated only.

## Evidence
- commit on main: 'exempt library-generated resources in registry test'
- `Xaas.Resource` is the configured base_resources entry in config/config.exs

## Definition of done
- [ ] `@pending` contains only RevokeNonce
- [ ] `mix test test/xaas/semantics` passes
- [ ] deny-by-default policy floor preserved on each touched resource

Runnable check:

```sh
cd ~/xaas && mix test test/xaas/semantics && mix test
```

## Falsifiers
- a migrated resource gains an allow-all policy
- projection admission passes but ontology_projection_hash is nil
