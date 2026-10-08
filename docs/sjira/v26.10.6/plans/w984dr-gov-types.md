# W984dr — Governance-types burn-down courts (v26.10.6)

Lane: W984dr · Branch: `feat/playwright-surface` (shared checkout, no commit) · Date: 2026-10-07

## Scope

Continuing the governance-types burn-down (W984cy4 courted `OverrideDecision`; W984di2 verified `CapabilityClass` dead). Fresh census of `lib/xaas/governance/types/` (19 files), then courts on the 2 most state-bearing of the remaining attribute-bound enums, through their live consumer resources, with per-test mutation rationale.

## Census (fresh, this lane, 2026-10-07)

19 type files under `lib/xaas/governance/types/`. Bindings verified by grep over `lib/` for the short-atom attribute binding (`attribute :x, :<type_name>`) and module references:

| Type | Binding | Consumer(s) | Status |
|---|---|---|---|
| OverrideDecision | attribute (`ApprovalDeniedPartyOverride.decision`) | approval_denied_party_override.ex | COURTED (W984cy4, 5 tests) |
| CapabilityClass | none (graphlaw uses plain `:atom`) | — | DEAD (W984di2) |
| **Environment** | attribute ×3 on 2 resources | approval_deployment_quarantine.ex (`environment`), approval_environment_promote.ex (`from_environment`, `to_environment`) | **COURTED (W984dr, 5 tests)** |
| **PentestFindingStatus** | attribute (`PentestFinding.status`) | pentest_finding.ex | **COURTED (W984dr, 5 tests PentestFindingStatus + PentestFinding transitions)** |
| DeploymentQuarantineReason | attribute | approval_deployment_quarantine.ex (`reason`) | thin remainder |
| ChangeOfControlEventType | attribute | approval_change_of_control_notify.ex | thin remainder |
| CmekProvider | attribute | approval_cmek_key_binding.ex | thin remainder |
| ExportSubscriptionCadence | attribute | approval_export_subscription_update.ex | thin remainder |
| ExportSubscriptionScope | attribute | approval_export_subscription_update.ex | thin remainder |
| InsuranceCoverageType | attribute | approval_insurance_policy_update.ex | thin remainder |
| LeRequestType | attribute | approval_le_request_respond.ex | thin remainder |
| LeResponseStatus | attribute | approval_le_request_respond.ex | thin remainder |
| PentestFindingResolution | attribute | approval_pentest_finding_resolve.ex | thin remainder |
| PentestFindingSeverity | attribute | pentest_finding.ex (`severity`) | thin remainder |
| ProjectTier | attribute | approval_backup_retention_change.ex (`tier`) | thin remainder |
| SubprocessorCategory | attribute | approval_subprocessor_registry_update.ex (`category`) | thin remainder |
| SubprocessorChangeAction | attribute | approval_subprocessor_registry_update.ex (`change_action`) | thin remainder |
| OrgRole | validation-bound | approval_sso_role_mapping_update_valid_mappings.ex (`OrgRole.values()`) | thin remainder |
| Interface | NONE | none in lib or test | DEAD candidate (zero consumers) |

Note: the 13 "thin remainder" entries share one disposition — see below.

## Courts (10 tests, both files green ×2 fresh root)

### 1. `test/xaas/governance/w984dr_environment_court_test.exs` — Environment (5 tests)

Through live consumers `ApprovalDeploymentQuarantine` + `ApprovalEnvironmentPromote`:

1. Full-value roundtrip: dev/staging/prod via authorized create (real `Org`, tenant+actor) + tenant-scoped reload → typed atoms, per-value.
2. Promotion roundtrip: from/to_environment as typed atoms on the second consumer (no existing test asserts these as typed atoms).
2b. One_of refusal shape on quarantine `:environment` — typed Invalid keyed :environment, "is invalid", zero rows land (tenant count).
3. Storage encoding: raw SQL `SELECT environment ...` → `"prod"` string; Ash reload → `:prod` atom (dump/load symmetric).
4. Promote refusal: out-of-enum `to_environment` → Invalid keyed `:to_environment` (second attribute path witnessed).

### 2. `test/xaas/governance/w984dr_pentest_finding_status_court_test.exs` — PentestFindingStatus (5 tests)

Through live consumer `Xaas.Governance.PentestFinding`:

1. Full-value roundtrip `:open` → `:remediation_in_progress` on changeset + fresh reload.
2. Closed create surface: `status` not accepted on `:create` → `NoSuchInput` typed refusal (`input == :status`), while a clean create forces `:open`.
3. State-machine guard: `:remediate` on non-open → Invalid keyed :status, "must be open"; row unchanged.
4. Storage encoding: raw SQL status column == `"remediation_in_progress"` + atom reload.
5. Authorized roundtrip: real org-scoped actor moves open→remediation_in_progress under `PentestFindingActorOrgFilter` (existing coverage was authorize?: false only).

## Commands / exits

- Run 1 (fresh `_build-laneW984dr` compiled from zero): `mix test ...w984dr_environment_court_test.exs ...w984dr_pentest_finding_status_court_test.exs` → `10 passed, 0 failed`, EXIT=0.
- Run 2 (root deleted, rebuilt from zero, same command): → `10 passed, 0 failed`, EXIT=0.

## Standing

- Environment, PentestFindingStatus: **ALIVE** (witnessed ×2 fresh root, real Postgres, typed refusals, storage encoding, authorized path).
- Thin remainder (13 attribute/validation-bound enums above): **PARTIAL_ALIVE** — each exercised indirectly through live consumer actions/refusals in existing tests; direct enum-contract courts deferred, next-lane candidates ranked: CmekProvider, LeResponseStatus+LeRequestType pair, ProjectTier, ChangeOfControlEventType.
- Interface: **DEAD candidate** — zero consumers in lib and test; next lane should confirm and delete per W984di2 CapabilityClass pattern.
- CapabilityClass: DEAD (prior lane, unchanged).
