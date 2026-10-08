# W984dr2b — Governance thin-validation batch sweep (parametrized court)

Standing: **ALIVE** (parametrized batch court over 32 thin validation
modules, 33 tests green ×3 runs; runs 2–3 are fresh DB roots via the
SQL sandbox + unique-per-run org ids; no commit; coordinator owns
integration).

Lane: W984dr2b, branch `feat/playwright-surface` (no new branch; files
landed on the working tree). No commits.

## Census (re-read from disk 2026-10-07/08)

`lib/xaas/governance/validations/`: **41 modules** (W984cz/W984dr2
receipts said 42; re-census by `ls | wc -l` shows 41 — one module fewer
than prior receipts claim; re-verified this lane, count from disk).

Already claimed before this lane:
- **W984cz** (3): ApprovalFreezeOverrideFreezeWindowExists,
  ApprovalNotAlreadyApproved, FreezeWindowEndsAfterStarts.
- **W984dr2** (2, cross-resource): ApprovalDrFailoverRequiresOpenIncident,
  AuditExportTokenNoActiveFreezeWindow.
- W984dr claims the Types enums, not validations.

## Disposition table

| class | count | disposition |
|---|---|---|
| Thin, one mutation surface, courted here (24 `*RequiresApprover` + 8 boundary) | 32 | this court |
| Multi-surface, per-module courts needed (follow-up lane) | 4 | `approval_pentest_finding_resolve_finding_org_matches` (81, cross-resource query), `approval_sso_role_mapping_update_valid_mappings` (75, structured mapping shape), `approval_backup_retention_change_within_tier_range` (44), `approval_environment_promote_valid_target` (39) |
| Already courted | 5 | W984cz (3) + W984dr2 (2) |

32 + 4 + 5 = 41 ✓

## Court

File: `test/xaas/governance/w984dr2b_gov_thin_batch_court_test.exs`
(33 tests). Chicago: real sandboxed Postgres, real Ash actions /
changesets on the live consumer resources, zero mocks (grep gate:
`grep -cE "Mock|patch\("` → 0).

### Class 1 — 24 `*RequiresApprover` modules (parametrized, one test per module)

Rows = {consumer resource, validation module, exact required-message}.
Each row, through the live resource's real `:approve` changeset
(`Ash.Changeset.for_update` on the real action; `:approve` accepts
exactly `[:approved_by]` on all 24; direct `validate/3`, W984cz idiom):

1. approved_by nil → refused with the module's own pinned message
   (exact-match assert). Mutation: nil/empty clause → :ok admits an
   approver-less :approve (silent self-service approval).
2. approved_by "" → same refusal. Mutation: `== ""` guard dropped →
   empty-string approver admitted.
3. approved_by == requested_by → refused, message contains "distinct".
   Mutation: distinct clause dropped → requester approves their own
   request (maker-checker breach).
4. distinct approver → :ok.
5. Wiring non-vacuity: `Ash.Resource.Info.action(res, :approve).changes`
   contains `%Ash.Resource.Validation{module: ^validation}` (unwiring
   the validation from :approve = the class kill mutation; fails any
   row). Probed live: action-scoped validations live in
   `action.changes`, not a `validations` key.

### Class 2 — 8 boundary validations, through the LIVE actions

1. Geofence TTL (live :create): ttl 0 and 200 refused; ttl 24 passes.
   Mutation: `ttl <= 168` relaxed.
2. DSAR subject email (live :create): "not-an-email",
   "missing-at.example" refused; valid email passes. Mutation: regex
   relaxed.
3. Sub-processor id (live :create): "bad id", "has/slash", "" refused;
   "vendor-1.core" passes with change_action `:added`, category
   `:"third-party-service"`. Mutation: regex relaxed (ConfigMap-key
   safety).
4. Insurance date-range + coverage (live :create): expiry <= effective
   refused; coverage_limit_usd 0 refused; valid policy (coverage_type
   `:cyber`, carrier, policy_number required attrs) passes. Mutations:
   `!= :gt` relaxed; Decimal guard dropped.
5. AuditExportToken (live :issue/:use): expired token refused on :use;
   fresh token :use stamps used_at (re-read); second :use refused.
   Mutations: `:gt` compare flipped; NotAlreadyUsed dropped.
6. AuditExportToken (live :revoke): first revoke stamps revoked_at;
   second :revoke refused. Mutation: `nil -> :ok` generalized.
7. InternalApiToken (live :issue/:revoke; org_id is a real Org FK so
   omitted/nullable): first revoke stamps; second refused. Same
   mutation class as (6), sibling module.
8. Fresh-root rerun test: root 2 of the requires_approver class
   (ApprovalOrgDelete row) + root 2 of the TTL boundary, live action.

Plus (9): direct validate/3 nil-tolerance pins for @expired,
@date_range, @ttl ("at most 168"), @email.

## Commands / exits

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984dr2b \
  mix test test/xaas/governance/w984dr2b_gov_thin_batch_court_test.exs
# run 1: 2/33 (three classes: resource.action/1 undefined ->
#   Ash.Resource.Info.action/2; action-scoped validations live in
#   action.changes not action.validations; test (9) used for_create on
#   a struct; plus live-fixture gaps: geofence required identifier_or_cidr/
#   reason, subprocessor create accepts no org_id (accepts change_action/
#   name/category/purpose; enums :added / :"third-party-service"),
#   insurance create requires coverage_type/carrier/policy_number, token
#   :use/:revoke not primary actions (need for_update form),
#   InternalApiToken.org_id is a real Org FK (nullable) -> all repaired)
# run 2 (post-repair): 33 passed
# runs 3–4 (fresh DB roots): 33 passed, 33 passed
```

## Falsifiers

- Any row of Class 1: drop the validation from the resource's
  `:approve` action → wiring assert fails; relax the nil clause → test
  1/2 fails; relax the distinct clause → test 3 fails.
- Class 2: relax each boundary clause → the corresponding live-action
  refusal assert fails (enumerated above).

## Typed dispositions / follow-up lane

- Multi-surface (need per-module courts, named for a follow-up lane):
  pentest-org-match (81), sso-valid-mappings (75),
  backup-tier-range (44), environment-promote-valid-target (39).
- No other leftovers: 32 (here) + 4 (multi-surface) + 5 (courted) = 41.

## Notes

- No commits; only the court file + this receipt written.
- `_build-laneW984dr2b` LEFT ON DISK: `rm -rf` DENIED by permissions
  (same as W984cz/W984dr2) — coordinator deletes at integration
  (fanout cleanup law disclosure).
