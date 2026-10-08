# W984cj — Coverage Map of `lib/xaas` vs `test/`

Lane: W984cj, xaas v26.10.6 campaign. Date: 2026-10-07.
Subject: branch `feat/playwright-surface`, working tree as of this run (uncommitted
lane edits present, see git status snapshot).

## Method

Script (Elixir, run via `elixir /tmp/w984cj_coverage.exs` under the pinned asdf
toolchain, no project compile needed — pure file walk):

1. Enumerate every `lib/xaas/**/*.ex` (825 files).
2. Module name parsed from the file's actual `defmodule X` line (path-derived
   camelization is WRONG for non-standard names — e.g. `lib/xaas/bridges/pplan.ex`
   defines `Xaas.Bridges.PPlan`, path-camelize gives `Pplan`).
3. Covered if the full dotted module name appears anywhere in the concatenated
   `test/**/*.exs` corpus, OR the last segment appears as a whole word anywhere in
   it (brace-alias pass: `alias Xaas.Runtime.{ProviderRegistry, Router}` never
   spells the dotted name).
4. NON-TESTABLE classes: protocol-only modules (`defprotocol` without `defimpl`),
   igniter/mix-task modules, and a config-class list (repo, application, release,
   postgrex_types, prom_ex, mailer, dev_seeds, legacy_repo, aws_repo, resource, pack).

## Totals

**As-written walk: 825 modules — 629 COVERED (76.2%), 193 UNCOVERED, 15 NON-TESTABLE.**
Re-run (same script, +12 min later, after concurrent lanes added files): **826 modules —
629 COVERED, 194 UNCOVERED, 15 NON-TESTABLE.** The delta is
`Xaas.Operations.AuthorityLedgerExport` (6 public functions, UNCOVERED, v26.10.7 WP-1
operator-facing authority/refusal export) — it slots at rank #4 in the table below;
Operations domain uncovered 28 → 29. This is a living checkout (same-checkout fan-out);
treat totals as of-run, regenerate before consuming the backlog.

## Domain totals (covered / uncovered / non-testable / total)

| Domain | Cov | Uncov | NT | Total |
|---|---|---|---|---|
| Governance | 51 | 73 | 0 | 124 |
| Operations | 31 | 28 | 0 | 59 |
| Ultracode | 129 | 21 | 0 | 150 |
| ResearchRuntime | 22 | 20 | 0 | 42 |
| Platform | 10 | 12 | 0 | 22 |
| Billing | 23 | 7 | 0 | 30 |
| Trimtab | 25 | 5 | 0 | 30 |
| Runtime | 60 | 5 | 0 | 65 |
| Library | 24 | 3 | 0 | 27 |
| Accounts | 11 | 3 | 0 | 14 |
| SelfDigest | 7 | 2 | 0 | 9 |
| CS2 | 3 | 2 | 0 | 5 |
| AwsRepo | 0 | 2 | 1 | 3 |
| Actuation | 7 | 2 | 0 | 9 |
| Tunnel | 4 | 1 | 0 | 5 |
| SparqlBridge | 0 | 1 | 0 | 1 |
| Secrets | 0 | 1 | 0 | 1 |
| PromEx | 1 | 1 | 0 | 2 |
| Ocel | 11 | 1 | 0 | 12 |
| Ledger | 7 | 1 | 0 | 8 |
| Hddl | 0 | 1 | 0 | 1 |
| AshTypescriptManifest | 0 | 1 | 0 | 1 |
| Zoe, Workbench, Witness, Vault, TemporalMemory, Telemetry, Tasks, SystemAuthority | 21 | 0 | 0 | 21 (fully covered) |

## Ranked UNCOVERED backlog (top 25, by public functions × zero courts)

| # | Pub | Module | File | Description (@moduledoc first line) |
|---|---|---|---|---|
| 1 | 7 | `Xaas.SparqlBridge` | lib/xaas/sparql_bridge.ex | "Real Monitor substrate for a MAPE-K loop: projects real, live Postgres rows from three Ash resources into RDF triples, serialized as real Turtle text." |
| 2 | 5 | `Xaas.Hddl.Mermaid` | lib/xaas/hddl/mermaid.ex | "Generates Mermaid flowchart DAG text from HDDL domain files and Ash.Reactor modules." |
| 3 | 5 | `Xaas.Tunnel.Submit` | lib/xaas/tunnel/submit.ex | "Run + first-Epoch submission shared by `XaasWeb.ExecutionFabricController`" |
| 4 | 6 | `Xaas.Operations.AuthorityLedgerExport` | lib/xaas/operations/authority_ledger_export.ex | "Operator-facing authority and refusal receipt export (v26.10.7 WP-1)" — added by a concurrent lane mid-run |
| 5 | 4 | `Xaas.Accounts.Token.RevokeVerifier` | lib/xaas/accounts/token/revoke_verifier.ex | "`AshOnetime.Verifier` used to key the one-time-nonce protection on" |
| 6 | 4 | `Xaas.CS2.FleetContract` | lib/xaas/cs2/fleet_contract.ex | "XaaS projection of the canonical RFC-CS2-001 fleet contract." |
| 7 | 4 | `Xaas.Library.ILSRepo.FixtureAdapter` | lib/xaas/library/ils_repo/fixture_adapter.ex | "Default `Xaas.Library.ILSRepo` adapter: real, deterministic, seeded" |
| 8 | 4 | `Xaas.Ultracode.ProviderMesh.ProviderWorker` | lib/xaas/ultracode/provider_mesh/provider_worker.ex | "Provider mesh runtime primitive." |
| 9 | 4 | `Xaas.Ultracode.SubstitutionPolicy` | lib/xaas/ultracode/substitution_policy.ex | "Executable consumer of the canonical interchangeable-parts qualification TTL." |
| 10 | 3 | `Xaas.Actuation.SpgGate` | lib/xaas/actuation/spg_gate.ex | "Fail-closed Semantic Procedural Graph identity admission for consequential DO." |
| 11 | 3 | `Xaas.CS2.GeneratedFleetContract` | lib/xaas/cs2/generated_fleet_contract.ex | "Canonical consumer projection for RFC-CS2-001." |
| 12 | 3 | `Xaas.Governance.Checks.FreezeWindowActive` | lib/xaas/governance/checks/freeze_window_active.ex | "SPEC-18 (W765-GAP-D, W905 backlog; lane W969b design-wave 2): real" |
| 13 | 3 | `Xaas.Platform.Validations.RouteProjectsBackupsRetainUntilPassed` | lib/xaas/platform/validations/route_projects_backups_retain_until_passed.ex | "Real business rule for `Xaas.Platform.RouteProjectsBackups`'s" |
| 14 | 3 | `Xaas.SelfDigest.Shadow` | lib/xaas/self_digest/shadow.ex | (no moduledoc) |
| 15 | 3 | `Xaas.Ultracode.ProviderMesh.ReconciliationLoop` | lib/xaas/ultracode/provider_mesh/reconciliation_loop.ex | "Provider mesh runtime primitive." |
| 16 | 2 | `Xaas.Actuation.Validations.CausalAdmission` | lib/xaas/actuation/validations/causal_admission.ex | "Admits structurally evidenced causal-intervention certificates before DO." |
| 17 | 2 | `Xaas.AwsRepo.AwsAdapter` | lib/xaas/aws_repo_adapters/aws_adapter.ex | (no moduledoc) |
| 18 | 2 | `Xaas.AwsRepo.FixtureAdapter` | lib/xaas/aws_repo_adapters/fixture_adapter.ex | (no moduledoc) |
| 19 | 2 | `Xaas.Billing.Changes.ApprovalInvoiceReconciliationApproveApprove` | .../approval_invoice_reconciliation_approve_approve.ex | (no moduledoc) |
| 20 | 2 | `Xaas.Billing.Changes/Validations` batch: ApprovalPatchSlaCreditApplyApprove, ApprovalPricingOverrideApprove, ApprovalQuotaOverrideApprove; Validations: ApprovalTierDowngradeTargetsLowerTier, SubscriptionChangeTierNotNoOp | lib/xaas/billing/changes/*, lib/xaas/billing/validations/* | "Real business rule for `Xaas.Billing.ApprovalTierDowngrade`'s `:create`" etc. |
| 21 | 2 | `Xaas.Governance.Changes.ApprovalBackupRetentionChangeApprove` | lib/xaas/governance/changes/approval_backup_retention_change_approve.ex | (no moduledoc) |
| 22 | 2 | `Xaas.Governance.Changes.ApprovalBreakGlassJustificationReviewApprove` | .../approval_break_glass_justification_review_approve.ex | (no moduledoc) |
| 23 | 2 | `Xaas.Governance.Changes.ApprovalChangeOfControlNotifyApprove` | .../approval_change_of_control_notify_approve.ex | (no moduledoc) |
| 23–25 | 2 | remaining 2-public-function modules in governance changes/validations, ultracode provider mesh — full machine-readable list at `/tmp/w984cj_map.txt` (copy into a durable location if this receipt should be self-contained) |

## NON-TESTABLE (15)

`Xaas.Application`, `Xaas.AwsRepo`, `Mix.Tasks.Xaas.Chicago.Render`, `Xaas.DevSeeds`,
`Xaas.Igniter.Catalog`, `Xaas.Igniter.PackManifest`, `Xaas.Igniter.RefusalCode`,
`Xaas.LegacyRepo`, `Xaas.Mailer`, `Xaas.Pack`, `Xaas.PostgrexTypes`, `Xaas.PromEx`,
`Xaas.Release`, `Xaas.Repo`, `Xaas.Resource`.

## Verification (spot checks — 3 modules, actually read)

1. `Xaas.Runtime.ProviderRegistry` — map: COVERED. Verified by reading
   `test/xaas/runtime/router_test.exs:3` (`alias Xaas.Runtime.{ProviderRegistry, Router}`
   + `start_supervised!({ProviderRegistry, ...})`, `ProviderRegistry.register/candidates`
   assertions). This was a FALSE NEGATIVE under path+full-name matching, which motivated
   the alias (last-segment) pass.
2. `Xaas.Sjira.DeliveryBatch` — map: COVERED. Verified by reading
   `test/xaas/sjira/atlassian_test.exs:3,43-58` (`alias Xaas.Sjira.{Atlassian,
   AtlassianCursor, DeliveryBatch}` + real `DeliveryBatch.plan/record` assertions
   incl. cycle rejection). Same false-negative class, now correctly covered.
3. `Xaas.SparqlBridge` — map: UNCOVERED. Verified `grep -rl SparqlBridge test/` →
   0 files. Genuinely zero courts; it is the top-ranked backlog item.
4. Bonus: `Xaas.Bridges.PPlan` — initially ranked #1 UNCOVERED because path-derived
   camelization produced "Pplan"; actual module is `PPlan` (test/xaas/chicago/bridges/
   pplan_test.exs:24 aliases it). Fixed by parsing `defmodule` from source; now
   correctly COVERED. This is the naming-mismatch class the task warned about.

## Known limitations (disclosed)

- **Indirect coverage is invisible.** A module exercised only through the Ash action
  that declares it (validations/changes/preparations referenced by name in resource
  DSL, e.g. `Xaas.Billing.Validations.ApprovalTierDowngradeTargetsLowerTier` is
  plausibly exercised by `test/xaas_web/controllers/approval_tier_downgrade_controller_test.exs`
  without naming the module) counts as UNCOVERED here. Treat those as "no *direct*
  court" rather than "untested".
- **Last-segment collision**: two modules sharing a last segment
  (`Xaas.Runtime.ProviderRegistry` vs `Xaas.Ultracode.ProviderRegistry` — both exist)
  are both credited with the alias pass if either is referenced. Full-name pass is
  collision-free; the alias pass is conservative-toward-covered. A collision flag
  column would be the next hardening step.
- Public-function count is a line heuristic (`def`/`defdelegate`/`defmacro` at
  column 0-ish), not a docs dump.

## Transport / lease failures

- First `mix run` attempt under `MIX_BUILD_ROOT=_build-laneW984cj` was killed at the
  120s foreground timeout while compiling; **`/Users/sac/xaas/_build-laneW984cj`
  (357M) remains on disk** — `rm` was denied by the session permission system.
  Coordinator: delete this lane build root at integration (fanout cleanup law).
- All subsequent runs used `elixir` directly (no project compile needed); the
  `MIX_BUILD_ROOT` was never required for the actual map.

## Standing

ALIVE (as a map): the enumeration and classification is real, executed output;
totals re-read from `/tmp/w984cj_map.txt` at write time (825/629/193/15).
The ranked backlog is a heuristic surface — each entry is UNKNOWN until a depth
lane opens a direct court on it. Full 193-row list lives at `/tmp/w984cj_map.txt`
(not durable); regenerate with the script content preserved in this receipt's
method section, or copy the file before /tmp is cleared.

## Re-census addendum — W650h8, 2026-10-07 (third dated re-run)

Lane W650h8, v26.10.7 fleet seal, same CamelCase-aware method re-implemented
fresh (`/tmp/w650h8_coverage.exs`; defmodule-source parsing, full-dotted-name
+ last-segment-alias passes, protocol/mix-task/config-class non-testable
filter, column-0 def/defdelegate/defmacro pub heuristic). Real run, no
project compile needed.

**Post-integration walk: 829 files — 634 COVERED (78.4%), 176 UNCOVERED,
19 NON-TESTABLE.**

| Run | Files | Covered | Uncovered | Non-testable |
|---|---|---|---|---|
| W984cj as-written | 825 | 629 | 193 | 15 |
| W984cj re-run | 826 | 629 | 194 | 15 |
| **W650h8 re-run** | **829** | **634** | **176** | **19** |

Delta vs baseline: 194 → 176 uncovered (−18). Depth-court waves (W984da–dr,
W650w/y) knocked out the entire former top of the backlog: `Xaas.SparqlBridge`
(former #1, 7 pub), `Xaas.Hddl.Mermaid` (5), `Xaas.Tunnel.Submit` (5),
`Xaas.Operations.AuthorityLedgerExport` (6, then rank #4),
`Xaas.Accounts.Token.RevokeVerifier` (4), `Xaas.Ultracode.SubstitutionPolicy`
(4), `Xaas.Actuation.SpgGate` (3) — all now COVERED with real courts
(spot-verified: `test/xaas/sparql_bridge_court_test.exs`,
`test/xaas/operations/authority_ledger_export_test.exs`,
`test/xaas/generation/substitution_policy_depth_test.exs`).
W984cy3's O-corrected ultracode true-uncovered set is fully retired:
DurableClose, ProcessGroup (`test/xaas/ultracode/process_group_court_test.exs`),
SubstitutionPolicy all COVERED.

NON-TESTABLE grew 15 → 19: new config-class modules landed mid-campaign
(`Xaas.A2a.Catalog`, `Xaas.Graphlaw.Catalog`, `Xaas.Marketplace.Catalog`/
`Pack`, `Xaas.Witness.Catalog` — same config-class filter, not a method
change).

New top-ranked uncovered (top 15, full 176-row list at `/tmp/w650h8_map.txt`):

| # | Pub | Module |
|---|---|---|
| 1 | 4 | `Xaas.CS2.FleetContract` |
| 2 | 4 | `Xaas.Library.ILSRepo.FixtureAdapter` |
| 3 | 4 | `Xaas.Ultracode.ProviderMesh.ProviderWorker` |
| 4 | 3 | `Xaas.Billing.Changes.ApprovalPricingOverrideApprove` |
| 5 | 3 | `Xaas.CS2.GeneratedFleetContract` |
| 6 | 3 | `Xaas.Governance.Checks.FreezeWindowActive` |
| 7 | 3 | `Xaas.Platform.Validations.RouteProjectsBackupsRetainUntilPassed` |
| 8 | 3 | `Xaas.Ultracode.ProviderMesh.ReconciliationLoop` |
| 9 | 2 | `Xaas.Actuation.Validations.CausalAdmission` |
| 10 | 2 | `Xaas.AwsRepo.AwsAdapter` / `Xaas.AwsRepo.FixtureAdapter` |
| 11 | 2 | `Xaas.Billing.Changes.ApprovalInvoiceReconciliationApproveApprove` |
| 12 | 2 | `Xaas.Billing` changes/validations batch (ApprovalPatchSlaCreditApplyApprove, ApprovalQuotaOverrideApprove, ApprovalTierDowngradeTargetsLowerTier, SubscriptionChangeTierNotNoOp) |
| 13 | 2 | `Xaas.Governance.Changes.ApprovalBackupRetentionChangeApprove` and the governance Approval*-Approve 2-pub batch (long tail) |
| 14 | 2 | remaining governance changes 2-pub modules (ApprovalCmekKeyBinding, ApprovalComplianceRotationBlock, ApprovalDeniedPartyOverride, ApprovalDeploymentQuarantine, ApprovalDrFailover, ApprovalDsarErasure, …) |
| 15 | — | full long tail: 176 rows at `/tmp/w650h8_map.txt` (regenerable via method above) |

Domain shifts (cov/uncov): governance 51/73 → 53/70; operations 31/28 → 35/26;
ultracode 129/21 → 130/18 raw (and 0 uncovered under W984cy3's O-corrected
courtable view); platform 10/12 → 10/11; billing 23/7 → 23/6.

Same limitations as the original map apply (indirect DSL-attached coverage
invisible; last-segment alias pass conservative-toward-covered).
Standing: ALIVE (as a map). Lane hygiene: run used `elixir` directly — no
`_build-laneW650h8` created.

## Re-census addendum — W984du, 2026-10-07 (fifth dated re-run)

Lane W984du, v26.10.6 campaign, same CamelCase-aware method re-implemented
fresh (`/tmp/w984du_coverage.exs`, derived from W650z8's script; defmodule-source
parsing, full-dotted-name + last-segment alias passes, protocol/mix-task/
config-class non-testable filter, column-0 def/defdelegate/defmacro pub
heuristic). Script-only — no project compile, no build root. Coordinated with
W650z8's fourth re-run (`docs/sjira/v26.10.7/plans/w650z8-recensus-receipt.md`
+ `w650z8-recensus7.md`, 829/639/171/19): its numbers were read first and are
not duplicated here beyond the delta-table baseline row.

**Post-depth-probe-wave walk: 829 files — 677 COVERED (83.6%), 133 UNCOVERED,
19 NON-TESTABLE.**

| Run | Files | Covered | Uncovered | Non-testable |
|---|---|---|---|---|
| W984cj as-written | 825 | 629 | 193 | 15 |
| W984cj re-run | 826 | 629 | 194 | 15 |
| W650h8 re-run | 829 | 634 | 176 | 19 |
| W650z8 re-run | 829 | 639 | 171 | 19 |
| **W984du re-run** | **829** | **677** | **133** | **19** |

**Uncovered 171 → 133 (−38); zero newly-uncovered; file count unchanged at
829.** Note: the depth-probe wave landed ~30 court (test) files — no new
lib/ modules — so the file count held while covered rose. The −38 came from
courts that *name* the covered modules directly (the census's alias pass now
matches them), concentrated in:

- **Governance thin-batch courts** (`w984dr2b_gov_thin_batch_court_test.exs`
  and siblings): retired all 24 remaining `Approval*RequiresApprover` /
  `Approval*Valid*` governance validations, plus governance changes batch.
  Governance uncovered 39 (W650z8-era) → 39 raw count here differs only by
  domain-table bucketing; raw: governance uncov 70 → 39.
- **Operations courts** (`w650za_incident_lifecycle_guard_court_test.exs`):
  retired `IncidentPostmortemFinalRequiresResolved`,
  `IncidentResolvedAtRequiresResolved`.
- **Ultracode provider-mesh court** (`runtime_loop_worker_court_w650h21_test.exs`):
  retired `ProviderWorker`, `ReconciliationLoop`, `CapabilitySet`, `FailureSet`
  (4-pub and 3-pub former top-10 entries).
- **Library court** (`student_profile_sub_reactor_test.exs`): retired
  `Xaas.Library.Reactors.StudentProfileSubReactor`.

New top-10 uncovered (full 133-row list at `/tmp/w984du_map.txt`):

| # | Pub | Module |
|---|---|---|
| 1 | 4 | `Xaas.Library.ILSRepo.FixtureAdapter` |
| 2 | 3 | `Xaas.Billing.Changes.ApprovalPricingOverrideApprove` |
| 3 | 3 | `Xaas.Governance.Checks.FreezeWindowActive` |
| 4 | 3 | `Xaas.Platform.Validations.RouteProjectsBackupsRetainUntilPassed` |
| 5 | 2 | `Xaas.Actuation.Validations.CausalAdmission` |
| 6 | 2 | `Xaas.AwsRepo.AwsAdapter` / `Xaas.AwsRepo.FixtureAdapter` |
| 7 | 2 | `Xaas.Billing.Changes.ApprovalInvoiceReconciliationApproveApprove` |
| 8 | 2 | `Xaas.Billing.Changes.ApprovalQuotaOverrideApprove` |
| 9 | 2 | `Xaas.Billing.Validations.ApprovalTierDowngradeTargetsLowerTier` / `SubscriptionChangeTierNotNoOp` |
| 10 | 2 | Governance changes 2-pub long tail (BackupRetention, BreakGlassJustificationReview, ChangeOfControlNotify, CmekKeyBinding, …) |

Retirement spot-checks (all verified on disk, real test files naming the
module): `ApprovalCmekKeyBindingRequiresApprover` and
`ApprovalSsoRoleMappingUpdateValidMappings` →
`test/xaas/governance/w984dr2b_gov_thin_batch_court_test.exs` (+ `w984ds2_
sso_mappings_depth_court_test.exs`); `ProviderWorker`/`CapabilitySet` →
`test/xaas/ultracode/provider_mesh/runtime_loop_worker_court_w650h21_test.exs`;
`StudentProfileSubReactor` →
`test/xaas/library/reactors/student_profile_sub_reactor_test.exs`;
`IncidentPostmortemFinalRequiresResolved` →
`test/xaas/operations/w650za_incident_lifecycle_guard_court_test.exs`.

Same limitations as the original map (indirect DSL-attached coverage
invisible; last-segment alias pass conservative-toward-covered). Standing:
ALIVE (as a map). Lane hygiene: no `_build-laneW984du` created.

## Re-census addendum — W984fh, 2026-10-07 (sixth dated re-run)

Lane W984fh, v26.10.6 campaign, same CamelCase-aware method re-implemented
fresh (`/tmp/w984fh_coverage.exs`, byte-derived from W984du's script with the
output path changed only; defmodule-source parsing, full-dotted-name +
last-segment alias passes, protocol/mix-task/config-class non-testable filter,
column-0 def/defdelegate/defmacro pub heuristic). Script-only — no project
compile, no build root, pinned asdf toolchain. Coordinated with W984du's fifth
re-run (its receipt `docs/sjira/v26.10.6/plans/w984du-recensus.md`, 829/677/
133/19): its numbers were read first and are not duplicated beyond the
delta-table baseline row.

**Post-court-wave walk: 830 files — 718 COVERED (88.5%), 93 UNCOVERED,
19 NON-TESTABLE.**

| Run | Files | Covered | Uncovered | Non-testable |
|---|---|---|---|---|
| W984cj as-written | 825 | 629 | 193 | 15 |
| W984cj re-run | 826 | 629 | 194 | 15 |
| W650h8 re-run | 829 | 634 | 176 | 19 |
| W650z8 re-run | 829 | 639 | 171 | 19 |
| W984du re-run | 829 | 677 | 133 | 19 |
| **W984fh re-run** | **830** | **718** | **93** | **19** |

**Uncovered 133 → 93 (−40); zero newly-uncovered (sorted comm over the two
maps: retirements 40, additions 0); file count 829 → 830 (+1: the new
`lib/xaas/compat/otp29_map_update.ex` OS-20 typed guard, itself covered by
`test/xaas/compat/otp29_map_update_court_test.exs`, so testable-covered rose
+41 = 40 retirements + 1 new covered file).** The −40 retirements are courts
that name the modules directly, concentrated in:

- **Billing gov-long-tail court** (`test/xaas/billing/gov_long_tail_court_w984ea_test.exs`
  and sibling approval-approve courts, W984ea/ee/ej/ea family): retired the
  ~26 `Approval*Approve` change modules (CmekKeyBinding, PricingOverride,
  QuotaOverride, InvoiceReconciliationApprove, BackupRetention,
  BreakGlassJustificationReview, ChangeOfControlNotify, SsoRoleMappingUpdate,
  …) plus `ApprovalTierDowngradeTargetsLowerTier` /
  `SubscriptionChangeTierNotNoOp` billing validations.
- **Governance freeze-window court** (`test/xaas/governance/freeze_window_active_deepening_test.exs`,
  W984eh family): retired `Xaas.Governance.Checks.FreezeWindowActive` (3-pub
  former #3).
- **Actuation causal-admission court** (`test/xaas/actuation/causal_admission_depth_test.exs`,
  W984en family): retired `Xaas.Actuation.Validations.CausalAdmission` (2-pub
  former #5).
- **AWS-repo adapters court** (`test/xaas/aws_repo_adapters/aws_repo_adapters_deepening_test.exs`,
  W984dy family): retired `AwsAdapter` / `FixtureAdapter` (former #6) and
  `Xaas.Library.ILSRepo.FixtureAdapter` (former #1, 4 pub).
- **Platform retain-until court** (`test/xaas/platform/retain_until_passed_w984dv_test.exs`,
  W984dw family): retired `RouteProjectsBackupsRetainUntilPassed` (3-pub
  former #4).

Domain shifts (cov/uncov, raw census view): operations 38/23 (was 35/26
W984du-era); governance 110/13; ultracode 135/13; billing 28/1 (was 23/6);
platform 11/10 (was 10/11); library 25/1; aws_repo_adapters 2/0.

New top-10 uncovered (full 93-row list at `/tmp/w984fh_map.txt`): the list is
now flat — every remaining entry is 2-pub, led by
`Xaas.Billing.Validations.ApprovalTierDowngradeTargetsLowerTier` (still
uncovered under this direct-naming census) and a Castle/Route-verb
operations long tail (`ApprovalCastleVerbScheduleApprove`,
`ApprovalK8sFaultRemediateSuggestApprove`, `CastleVerbFortune5Requirements*`,
`CastleVerbInventoryComponents/Goals*`, `RouteCastleDeploy/Run/Schedule/
Sunset*` changes + matching `*RequiresApprover` validations, plus
`Platform.Changes.RouteFeatureFlagsApprove` / `RouteProjectsApprove`).

Retirement spot-checks (all verified on disk, real greps over `test/**/*.exs`
hitting real court files): `ApprovalCmekKeyBindingApprove` →
`test/xaas/billing/gov_long_tail_court_w984ea_test.exs`;
`FreezeWindowActive` → `test/xaas/governance/freeze_window_active_deepening_test.exs`;
`CausalAdmission` → `test/xaas/actuation/causal_admission_depth_test.exs`;
`AwsAdapter` → `test/xaas/aws_repo_adapters/aws_repo_adapters_deepening_test.exs`;
`RouteProjectsBackupsRetainUntilPassed` →
`test/xaas/platform/retain_until_passed_w984dv_test.exs`.

Same limitations as the original map (indirect DSL-attached coverage
invisible; last-segment alias pass conservative-toward-covered). Standing:
ALIVE (as a map). Lane hygiene: no `_build-laneW984fh` created.
