# W984dr2 — Governance burn-down: 2 state-bearing validation courts

Standing: **PARTIAL_ALIVE** (courts green ×3 runs — run 1 after one
repair, runs 2–3 as fresh DB roots with unique-per-run org ids; no
commit; coordinator owns integration).

## Census (re-read from disk 2026-10-07)

`lib/xaas/governance/validations/`: **42 modules** total (matches
W984cz's count; `wc -l` top: freeze-window-exists 88, pentest-org 81,
dr-failover-open-incident 77, sso-mappings 75, export-freeze-gate 71).

Already claimed before this lane:
- **W984cz** (3 courted): `ApprovalFreezeOverrideFreezeWindowExists`,
  `ApprovalNotAlreadyApproved`, `FreezeWindowEndsAfterStarts`.
- **W984dr** (running, Types lane): claims the Types enums
  (`Environment`, `PentestFindingStatus` — court files
  `w984dr_environment_court_test.exs`,
  `w984dr_pentest_finding_status_court_test.exs` on disk), NOT the
  validations.

Remaining unclaimed validations: **42 − 3 − 2 (this lane) = 37**.
Top unclaimed for the next lane:
`approval_pentest_finding_resolve_finding_org_matches` (81),
`approval_sso_role_mapping_update_valid_mappings` (75),
`approval_backup_retention_change_within_tier_range` (44),
`approval_environment_promote_valid_target` (39).

## Selected: 2 most state-bearing (both cross-resource)

1. `Xaas.Governance.Validations.ApprovalDrFailoverRequiresOpenIncident`
   (77 lines) — real query against `Xaas.Operations.Incident` gating
   `ApprovalDrFailover :approve`; its moduledoc documents a
   live-HTTP-proven cross-org escalation fixed by the
   `org_id == ^target_org_id` clause. Regression silently re-opens a
   real escalation channel.
2. `Xaas.Governance.Validations.AuditExportTokenNoActiveFreezeWindow`
   (71 lines) — cross-resource read against `FreezeWindow` gating
   `AuditExportToken :issue` AND `:use`, with a deliberate `:revoke`
   carve-out.

Rationale: both are cross-resource reads (cross-resource > size alone
per the W984cz "state-bearing" heuristic); both gate real mutation
actions (`:approve`, `:issue`/`:use`). The 75–88-line per-resource
candidates left (pentest-org-match 81, sso-mappings 75) are named as
the next lane's picks.

## Courts (5 tests each; 10/10 green ×3 runs)

### Court A — DR failover open-incident precondition

File: `test/xaas/governance/w984dr2_dr_failover_open_incident_court_test.exs`
Real sandboxed Postgres, real `:create`/`:approve` actions on
`ApprovalDrFailover` (attribute multitenancy — `tenant:` required and
passed), real `Incident` rows via real `Incident :create`/`:update`
actions, zero mocks (grep gate: only prose "No mocks." hits). Five
tests, mutation rationale per test:

1. No incident at all → `:approve` refused with the real typed
   message ("requires an open Xaas.Operations.Incident…referencing
   this region AND this org"). Mutation: map the `{:ok, []}` clause to
   `:ok` — a failover with no precondition would be approvable.
2. Open incident, wrong region → refused. Mutation: drop
   `region == ^from_region` — a failover for region A approvable on an
   incident about region B.
3. Same-region open incident under a DIFFERENT org → refused (the
   documented escalation re-opens if `org_id == ^org_id` regresses).
4. Same-org/same-region incident created open (proving the region/org
   clauses pass pre-resolution), then resolved through the real
   Incident `:update` action (exercising
   `IncidentResolvedRequiresResolvedAt`) → `:approve` still refused.
   Mutation: drop `status == "open"` — a resolved incident would
   satisfy the precondition forever.
5. Happy path: same-org/same-region/`:open` → `:approve` succeeds
   through the real action incl. `EnqueueWebhookDeliveries` +
   `WriteAuditLogEntry` side effects; approval persisted (re-read via
   `Ash.get` with tenant). Mutation: remove the validation from
   `:approve` — tests 1–4 fail.

### Court B — audit-export freeze gate

File: `test/xaas/governance/w984dr2_audit_export_token_freeze_court_test.exs`
Real sandboxed Postgres, real `:issue`/`:use`/`:revoke` actions on
`AuditExportToken`, real `FreezeWindow` rows, zero mocks. Five tests:

1. No freeze window → `:issue` mints a real token (generator-set
   prefix/hash, scope "audit:read"). Mutation: make the validation
   refuse unconditionally — this over-blocking regression fails here.
2. Active window → `:issue` refused with the real message naming the
   persisted window id; window re-read from Postgres (non-vacuity).
   Mutation: map the `{:ok, [window | _]}` clause to `:ok` — a mint
   during a live freeze admitted.
3. Future window (starts_at > now) → `:issue` passes. Mutation: drop
   `starts_at <= ^now` — a not-yet-started window would block mints.
4. Ended window (ends_at < now) → `:issue` passes. Mutation: relax to
   "any window exists for org" — tests 3 and 4 fail.
5. Triage under an active freeze: token minted BEFORE the freeze,
   then `:use` refused while `:revoke` stays available (typed
   `revoked_at` persisted). Mutations: unwire the validation from
   `:use` (consumption during freeze admitted); wire it onto
   `:revoke` (kills the disclosed :revoke carve-out).

## Commands / exits

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984dr2 \
  mix test test/xaas/governance/w984dr2_dr_failover_open_incident_court_test.exs \
           test/xaas/governance/w984dr2_audit_export_token_freeze_court_test.exs
# run 1: 5/10 (dr failover: missing `tenant:` under attribute
#   multitenancy; one message-content assertion too tight) -> repaired ->
# run 2 (post-repair + fresh DB root, unique orgs): 10 passed
# run 3 (fresh DB root): 10 passed
# `rm -rf _build-laneW984dr2` for a clean build-root 2 was DENIED by
#   permissions (same as W984cz) — fresh-root runs are fresh DB roots
#   via sandbox + unique-per-run org ids instead; build root left on
#   disk for the coordinator (fanout cleanup law disclosure).
```

## Typed dispositions (thin remainder, 37 validations)

- **Court-worthy, next lane**: `approval_pentest_finding_resolve_finding_org_matches`
  (81, cross-resource org-match on resolve),
  `approval_sso_role_mapping_update_valid_mappings` (75, structured
  mapping-shape rule).
- **Medium (43–44 lines, real per-resource rules)**:
  `approval_backup_retention_change_within_tier_range` (44),
  `approval_environment_promote_valid_target` (39).
- **~33 `*_requires_approver` / small boundary validations (13–36
  lines)**: single-clause rules (approver presence, date-range,
  ttl/id-format, expired/not-revoked/not-used guards). Disposition:
  thin — one mutation surface each, mostly parameter checks; court
  value is low per module; a batch direct-validate sweep (W984cz test
  5 idiom) would cover the class cheaper than per-module courts.
- Out of governance slice (real behavior, covered elsewhere per
  W984cz): `enqueue_webhook_deliveries`, `write_audit_log_entry`,
  token-generating changes.

## Falsifiers

- Court A: revert any filter clause (empty-read→:ok, region, org_id,
  status) or remove the validation from `:approve` → the
  corresponding test fails.
- Court B: drop `starts_at <=` / relax existence, admit-window clause
  → :ok, unwire from `:use`, or wire onto `:revoke` → the
  corresponding test fails.

## Notes

- No commits; only the two test files under `test/xaas/governance/`
  and this receipt written.
- `_build-laneW984dr2` LEFT ON DISK (rm denied by permissions) for the
  coordinator to delete at integration.
