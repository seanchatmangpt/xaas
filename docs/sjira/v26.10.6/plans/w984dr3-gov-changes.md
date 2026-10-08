# W984dr3 — Governance burn-down continuation: 2 state-bearing validation courts

Standing: **PARTIAL_ALIVE** (courts green 10/10 on two independent fresh
build roots; no commit; coordinator owns integration).

## Lane coordination (re-read from disk 2026-10-07)

- W984cz (courted): `ApprovalFreezeOverrideFreezeWindowExists`,
  `ApprovalNotAlreadyApproved`, `FreezeWindowEndsAfterStarts`.
- W984dr2 (courted): `ApprovalDrFailoverRequiresOpenIncident`,
  `AuditExportTokenNoActiveFreezeWindow`.
- W984da: security family (`lib/xaas/security/`), no overlap.
- W984ds2 (running at lane start): pentest-org-match (81) +
  sso-mappings (75) courts — files on disk
  (`w984ds2_sso_mappings_depth_court_test.exs`,
  `w984ds2_pentest_org_match_depth_court_test.exs`); not touched.
- Pre-existing per-resource tests already on disk cover, among others:
  `enqueue_webhook_deliveries_test.exs`,
  `approval_backup_retention_change_test.exs` (+ stress),
  `audit_log_entry_test.exs`, `export_token_deepening_test.exs`,
  `multitenant_approval_deepening_test.exs`,
  `approval_pentest_finding_resolve_finding_org_matches_test.exs` —
  so the 129/123/90-line change modules are not naked; the burn-down
  targets the validations without any dedicated court.

## Census (re-read from disk 2026-10-07)

- `lib/xaas/governance/changes/`: 26 modules; 21 are 13-line identity
  stubs (`change/2 -> changeset` verbatim), 5 carry real behavior
  (enqueue_webhook_deliveries 129, charge_overage 123,
  write_audit_log_entry 90, generate_internal_api_token 40,
  generate_audit_export_token 28) and all 5 have pre-existing test
  files touching them.
- `lib/xaas/governance/validations/`: **41 modules** on disk now
  (W984cz counted 42; current `ls | wc -l` = 41 — re-measured, not
  assumed).
- Claimed validations to date: 3 (W984cz) + 2 (W984dr2) + 2 (W984ds2,
  in flight) = 7; this lane adds 2 more → **9 courted / 32 remaining
  unclaimed** (mostly the 13–44-line single-resource gates).

## Selected: 2 most state-bearing unclaimed validations

1. `Xaas.Governance.Validations.ApprovalBackupRetentionChangeWithinTierRange`
   (44 lines) — the real "400, not a fee" per-tier retention-range
   gate on `ApprovalBackupRetentionChange :create`; the overage-fee
   change on `:approve` is downstream of it.
2. `Xaas.Governance.Validations.ApprovalEnvironmentPromoteValidTarget`
   (39 lines) — single-stage-forward-only promotion rule (dev →
   staging → prod; no skip, reverse, no-op, or terminal promotion) on
   `ApprovalEnvironmentPromote :create`.

## Courts (10 tests, 10/10 green; mutation rationale per test)

File: `test/xaas/governance/w984dr3_gov_state_bearing_court_test.exs`
Real sandboxed Postgres, real `Ash.Changeset.for_create` through the
real `:create` actions, real persisted `Xaas.Accounts.Org` rows for
the FK/multitenancy, unique-per-run org slugs / project names (fresh
root each run), zero mocks (grep gate: 0 hits).

### Court A — within-tier retention range (5 tests)

1. starter/30 refused with the real typed per-tier message.
   Mutation killed: widen `@retention_range` (starter {1,30}) — an
   out-of-tier retention admitted at create time, priced only later.
2. enterprise 2555 (7-year SEC cap) persists; 2556 refused. Mutation
   killed: `days <= max_days` off-by-one.
3. pro boundary: 7 passes + persists, 6 refused. Mutation killed:
   drop `days >= min_days` — silent under-protection admitted.
4. Non-integer days ("30") refused through the real action; the
   validation's missing-tier `:error` arm is NOT reachable through
   the action (`tier` is `allow_nil? false`, attribute constraint
   fires first) and is exercised via direct `validate/3` per the
   W984cz direct-court method, asserting the exact
   `{:error, [field: :tier, message: ...]}` shape. Mutations killed:
   drop `is_integer(days)`; map `:error` arm to `:ok`.
5. Non-vacuity: a refused create persists no row (read back empty).
   Mutation killed: remove the validation from `:create`.

### Court B — environment-promote valid target (5 tests)

1. dev → staging admitted through real `:create`, re-read via
   `Ash.get` (status `:pending`). Mutation: remove validation.
2. dev → prod skip refused with the real typed message. Mutation:
   `when to == expected` relaxed to admit any target.
3. terminal `prod` refused ("already the terminal environment").
   Mutation: `:error` arm → `:ok` (endless prod→prod admitted).
4. staging → dev reversal + staging → staging no-op refused.
   Mutation: `to == expected` → `to in [expected, from]`.
5. Non-vacuity: refused promotion persists no row; legal one does
   (re-read via `Ash.get`). Mutation: remove validation.

## Commands / exits

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984dr3 \
  mix test test/xaas/governance/w984dr3_gov_state_bearing_court_test.exs
# warm run 1: 8/10 (2 fixture bugs) → repaired → warm run: 9/10 (1
# pattern bug) → repaired → 10 passed
# FRESH ROOT 1 (rm -rf _build-laneW984dr3, full rebuild): 10 passed
# FRESH ROOT 2 (_build-laneW984dr3-fresh2, full rebuild; resumed twice
#   at the background-task time limit, no code change between resumes):
#   10 passed, exit 0
```

## Dispositions (typed, thin remainder)

- 21 changes/ identity stubs (13 lines, `change/2 -> changeset`
  verbatim): **UNSUPPORTED(no-behavior)** — no behavior to court, per
  the no-padding clause; consistent with W984cz's disposition.
- 5 real-behavior changes/ modules: **DISPOSED(pre-existing-coverage)**
  — each has a real test file touching it (listed above); deepening
  them is a coordinator-level dedupe decision, not this lane's slice.
- Remaining ~32 unclaimed validations (13–44 lines, single-resource,
  no cross-resource read): **UNKNOWN(low-risk-thin)** — available for
  the next burn-down lane; the genuinely state-bearing (cross-resource)
  tier of the W984cz heuristic is now empty of unclaimed members.
