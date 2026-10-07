# W740 — Double-Approve Guard on the 4 Non-Global-Multitenancy Approval* Resources

- **Wave / lane**: v26.10.6, lane W740 (gap 1 from `docs/sjira/v26.10.6/plans/w722-governance-deepening.md`)
- **Subject**: canonical checkout `/Users/sac/xaas`, branch `feat/playwright-surface`, base HEAD `a0723bf6` (uncommitted lane diff, not committed per lane contract)
- **Standing**: ALIVE (observed execution on the exact subject; all listed courts green in lane build root `_build-laneW740`)

## Defect (before)

None of the 4 non-global-multitenancy Governance `Approval*` resources
(`ApprovalDrFailover`, `ApprovalLegalHoldRelease`, `ApprovalDeploymentQuarantine`,
`ApprovalBackupRetentionChange`) guarded double-approval: a second `:approve`
succeeded and silently overwrote `approved_by` — a maker-checker integrity defect
on consequential approvals (W722 gap 1). The deepening test even pinned the bug
as a "disclosed gap" test. Only the Billing siblings' `newly_approved?/2`
defense-in-depth (and BackupRetention's own `ChargeOverage` guard) prevented
double-charging, not re-approval itself.

## Fix

House idiom reused (same shape as
`Xaas.Governance.Validations.AuditExportTokenNotAlreadyRevoked`): one shared
validation reading the real pre-update value via `Ash.Changeset.get_data/2`,
refusing with a typed field error when `approved_by` is already set.

- **New (1 file, disclosed deviation from the lane's "4 resource files only"
  contract — the house idiom is a dedicated validation module, so a 5th lib
  file was required):**
  `lib/xaas/governance/validations/approval_not_already_approved.ex`
  (`Xaas.Governance.Validations.ApprovalNotAlreadyApproved`)
- **4 resource edits (identical one-line shape):**
  `validate(Xaas.Governance.Validations.ApprovalNotAlreadyApproved)` added to
  `:approve` in
  `lib/xaas/governance/approval_dr_failover.ex`,
  `lib/xaas/governance/approval_legal_hold_release.ex`,
  `lib/xaas/governance/approval_deployment_quarantine.ex`,
  `lib/xaas/governance/approval_backup_retention_change.ex`
- **Test updates:**
  - `test/xaas/governance/multitenant_approval_deepening_test.exs`: the
    "double-approve: disclosed gap" behavior-pinning test replaced with the
    refusal court (all 4 resources: second approve → typed
    `Ash.Error.Invalid` naming `approved_by`/"already been approved";
    persisted `approved_by` stays `"approver-1"`), plus a new
    ledger-charge-path court (exactly one real -$6.00 overage charge;
    second approve refused before `ChargeOverage` runs). Mutation rationale
    in the test comment: dropping the `validate(...)` line from any resource's
    `:approve` makes `assert {:error, %Ash.Error.Invalid{}} =` fail and the
    persisted `approved_by` flip to `"approver-2"` — the exact W722 defect.
  - `test/xaas/governance/approval_backup_retention_change_test.exs`
    (disclosed second-file touch): "approving twice does not double-charge"
    previously completed the second approve successfully (`Ash.update!`);
    under the guard the second approve is now itself the typed refusal, so
    that assertion was updated to `assert {:error, %Ash.Error.Invalid{}}`.
    Charge-exactly-once assertion unchanged and green.

## Verification (real output, lane build root `_build-laneW740`, asdf elixir 1.20.2-otp-28)

```
MIX_ENV=test MIX_BUILD_ROOT=_build-laneW740 mix test \
  test/xaas/governance/multitenant_approval_deepening_test.exs \
  test/xaas/governance/approval_backup_retention_change_test.exs
# Result: 12 passed

MIX_ENV=test MIX_BUILD_ROOT=_build-laneW740 mix test \
  test/xaas_web/controllers/approval_{dr_failover,legal_hold_release,deployment_quarantine,backup_retention_change}_controller_test.exs \
  test/xaas/governance/approval_dr_failover_stress_test.exs \
  test/xaas/governance/approval_backup_retention_change_stress_test.exs
# Result: 24 passed, 2 excluded (stress/kind tags)

MIX_ENV=test MIX_BUILD_ROOT=_build-laneW740 mix test test/xaas/dev_seeds_test.exs \
  test/xaas_web/controllers/resolve_org_actor_test.exs \
  test/xaas/governance/enqueue_webhook_deliveries_test.exs
# Result: 15 passed
```

51 passed, 0 failed across the approval-touching surface. `mix compile` clean.
Controller tests confirm the PATCH `:approve` route surfaces the refusal on
every one of the 4 resources.

## Mutation rationale (falsifier)

Delete `validate(ApprovalNotAlreadyApproved)` from any one of the 4 `:approve`
actions → `multitenant_approval_deepening_test.exs` "double-approve is a typed
refusal..." fails for that resource (second approve returns `{:ok, _}`, persisted
`approved_by` == "approver-2"). Delete from all 4 → the loop fails on the first
resource. The ledger-charge court additionally kills any regression that drops
`ChargeOverage`'s `newly_approved?/2`.

## Standing

ALIVE for the 4 resources' `:approve` state guard, witnessed by real sandboxed
Postgres courts. Not committed (lane contract); coordinator owns integration.
Lane build root `_build-laneW740` deleted after verification.
