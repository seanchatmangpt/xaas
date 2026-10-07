# W984cz — Governance changes/validations direct court

Standing: **PARTIAL_ALIVE** (court green, lane-scoped only — no action-level
integration deepening, no commit; coordinator owns integration).

## Batch census (re-read from disk 2026-10-07)

- `lib/xaas/governance/changes/`: **29 modules**
  - 26 are 13-line identity stubs (`use Ash.Resource.Change`,
    `change/2 -> changeset` verbatim), including
    `ApprovalFreezeOverrideApprove` — typed disposition: no behavior to
    court (no-padding clause honored).
  - Real-behavior changes outside this lane's slice:
    `enqueue_webhook_deliveries.ex` (129 lines),
    `generate_internal_api_token.ex` (40),
    `write_audit_log_entry.ex` (90),
    `generate_audit_export_token.ex` (28),
    `approval_backup_retention_change_charge_overage.ex` (123).
- `lib/xaas/governance/validations/`: **42 modules** (13–88 lines each;
  the heavy ones — freeze-window-exists 88, dr-failover-open-incident 77,
  pentest-org-matches 81, sso-mappings 75 — carry real cross-resource
  logic, not delegations).

## Court (5 tests, all passing ×2 fresh roots)

File: `test/xaas/governance/w984cz_gov_changes_direct_court_test.exs`
Real sandboxed Postgres, real `Ash.Changeset`s, zero mocks (grep count 0).
Direct `validate/3` calls on real changesets against real persisted rows.

1. `ApprovalFreezeOverrideFreezeWindowExists` — ghost
   `freeze_window_id` refused by direct `validate/3`.
   Mutation: map `{:error, _}` clause to `:ok` → ghost id admitted.
2. Same module — cross-org window refused, non-emergency
   (`allow_emergency_override: false`) window refused, eligible same-org
   emergency window passes. Mutations A (org clause dropped) and B
   (emergency clause dropped) both killed.
3. `ApprovalNotAlreadyApproved` — re-approve guard: pre-update
   `approved_by` present → typed refusal; nil → `:ok`. Real persisted
   `ApprovalLegalHoldRelease` row; pre-update state set on the loaded
   record (`:create` does not accept `approved_by`).
4. `FreezeWindowEndsAfterStarts` — `ends_at == starts_at` refused,
   `ends_at > starts_at` passes, nil pair passes. Mutation: `!= :gt`
   relaxed to `== :lt` admits zero-length windows.
5. Non-vacuity fresh-root rerun of (1)+(3) — refusals track real DB
   state, unique orgs per run, no fixture reuse.

## Commands / exits

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984cz \
  mix test test/xaas/governance/w984cz_gov_changes_direct_court_test.exs
# run 1: 3/5 (fixtures wrong) → repaired →
# run 4: 4/5 (missing hold_id) → repaired →
# run 5: 5 passed; run 6 (fresh root 2): 5 passed
```

## Dispositions

- Courted directly: 3 modules (above).
- Typed disposition, not courted: 26 identity-stub `*Approve` changes
  (1-line `change/2` returning changeset — nothing to kill).
- Out of slice, real behavior, left for later lanes:
  `enqueue_webhook_deliveries` (has existing
  `enqueue_webhook_deliveries_test.exs`), `write_audit_log_entry` (has
  `audit_log_entry_test.exs`), token-generating changes (covered by
  export-token deepening tests).

## Falsifiers

- Revert any guarded clause (ghost-id error clause, org-match clause,
  emergency flag clause, `!= :gt`, approved_by nil-check) → the
  corresponding court test fails.

## Notes

- `rm -rf _build-laneW984cz` was denied by permissions; the lane build
  root `_build-laneW984cz` is LEFT ON DISK for the coordinator to delete
  at integration (fanout cleanup law disclosure).
- No commits made; only `test/xaas/governance/w984cz_gov_changes_direct_court_test.exs`
  and this receipt written.
