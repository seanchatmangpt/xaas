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

- **Standing**: ALIVE

## Status
ALIVE — verified this session (2026-09-22) on branch `sjira/sj-004`,
worktree `/Users/sac/xaas/worktrees/sjira/sj-004`, HEAD `1b07a29`
(prior commits `5c1ad01` "feat(semantics): SJ-004 adopt Xaas.Resource on the
seven registry-exempt resources" and `1b07a29` "style(semantics): mix format
registry_test" already carried the migration; this session re-ran the
required courts against that exact HEAD and re-checked all three acceptance
criteria and both falsifiers directly against source).
- **Repository**: seanchatmangpt/xaas @ `8e72cfc` (base), verified HEAD `1b07a29`

## Description
test/xaas/semantics/registry_test.exs carries a disclosed `@pending` exemption list (CouplingRun, EventLog, AutofdePlannerCacheHotset/CacheStats/Candidate/Catalog/Match; plus library-generated RevokeNonce and *.Version). Migrate the seven owned resources to `use Xaas.Resource` (base_resources) and shrink the list to library-generated only.

## Evidence (this session, real commands + real output)
- `mix compile --warnings-as-errors` → exit 0 ("Compiling 478 files (.ex) / Generated
  xaas app", no warnings-as-errors failures; only a pre-existing dep warning in
  `deps/ex4pm/mix.exs`, outside path_scope).
- `mix test test/xaas/semantics` → exit 0, "9 tests, 0 failures".
- `mix test` (full suite, runnable check) → "1346 tests, 0 failures (71 excluded)",
  194.3s.
- `grep -rn "unittest.mock\|Mock(\|MagicMock\|patch(\|Mox\.\|monkeypatch"
  test/xaas/semantics/ lib/xaas/coupling/ lib/xaas/ledger/
  lib/xaas/operations/autofde_planner_*.ex` → 0 matches (Chicago-style, no mocks).
- `@pending` in `test/xaas/semantics/registry_test.exs` contains only
  `Xaas.Accounts.Token.RevokeNonce` (library-generated; `.Version` handled by the
  separate suffix clause) — read directly from the file.
- Policy-floor falsifier check: `grep -n -A3 "policy always()"` on all nine touched
  resources (`lib/xaas/coupling/coupling_run.ex`, `lib/xaas/ledger/{balance,
  account,transfer}.ex`, `lib/xaas/operations/autofde_planner_{cache_hotset,
  cache_stats,catalog,candidate,match}.ex`) shows `policy always() do
  forbid_if(always()) end` on every one — deny-by-default, not allow-all. Falsifier
  "a migrated resource gains an allow-all policy" did not trigger.
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
