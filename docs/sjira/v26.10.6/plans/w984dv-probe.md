# W984dv — Probe Receipt: ApprovalPricingOverrideApprove + RouteProjectsBackupsRetainUntilPassed Chicago Courts

- Subject: `/Users/sac/xaas` @ branch `feat/playwright-surface`, HEAD `c0626503` (uncommitted lane test files only)
- Standing: **ALIVE** (10/10 real tests green on the lane build root, mock gate `[]`, exit 0)
- Task source: W984du fifth re-census (`/tmp/w984du_map.txt`) — two still-uncovered validation families

## Census

- `Xaas.Billing.Changes.ApprovalPricingOverrideApprove`
  (`lib/xaas/billing/changes/approval_pricing_override_approve.ex`): no-op stub
  (W984cc SPEC-08 note). Surrounding surface heavily covered (controller court,
  W982s lifecycle court: re-approve StaleRecord guard, self-approval, race,
  multitenancy). Genuinely unexercised: the stub's own pass-through contract
  (init/change/atomic) and the Ash-level policy path with a real
  `Xaas.SystemAuthority` actor under `authorize?: true`.
- `Xaas.Platform.Validations.RouteProjectsBackupsRetainUntilPassed`
  (`lib/xaas/platform/validations/route_projects_backups_retain_until_passed.ex`):
  W981d atomicity court covers bulk happy path, no-match bulk, per-row refusal,
  cross-org policy. Genuinely unexercised: the atomic-pinned bulk refusal of a
  not-yet-expired row with `return_errors?` shape, the fail-closed nil branch of
  `validate/3`, and the direct `validate/3` retention-window message contract.

## Files landed (tests only; lib/ untouched)

- `test/xaas/billing/approval_pricing_override_approve_w984dv_test.exs` (6 tests)
- `test/xaas/platform/retain_until_passed_w984dv_test.exs` (4 tests)

## Branches covered

Billing (6): init pass-through, change/3 identity, atomic/3 identity, SystemActor
end-to-end atomic `:approve` with persisted `approved_by`, SystemActor
self-approval refusal, non-system actor Forbidden (row survives).
Platform (4): atomic-pinned bulk destroy over a not-yet-expired row (typed
`InvalidAttribute` field `:retain_until`, row survives), fail-closed nil
`retain_until` branch of validate/3, happy per-row purge (row really deleted),
validate/3 retention-window refusal message.

## Real commands + output

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984dv \
  mix test test/xaas/billing/approval_pricing_override_approve_w984dv_test.exs \
           test/xaas/platform/retain_until_passed_w984dv_test.exs
  → Result: 10 passed  (exit 0)

PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984dv \
  mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'
  → []  (exit 0)
```

## Finding (behavior, not defect)

Under `strategy: [:atomic]` pinned bulk destroy, Ash still runs `validate/3`
eagerly on the loaded changeset, so the surfaced typed error carries validate/3's
"is still within its retention window" message, not the atomic SQL expr's
message. Test pins the observed real contract; the atomic expr remains the
fail-closed DB-level backstop. A `retain_until` row can never be nil via the
create surface (`allow_nil?(false)`), so the nil branches are defense-in-depth
dead code via the public surface — exercised directly against a real changeset.

## Falsifiers

- A regression making `:approve` non-atomic or breaking the idempotency guard
  would flip (2a)/(2b); a regression in the purge validation flips (1).
- Broken-then-fixed trace: one real failure fixed in-session (bulk error is
  nested under `%Ash.Error.Invalid{errors: [...]}`; message is validate/3's).

## Cleanup

- `rm -rf /Users/sac/xaas/_build-laneW984dv` (426 MB) was DENIED by the session
  permission system — the lane build-root lease could not be released from this
  lane. Coordinator must delete it at integration (fanout cleanup law).
  `/tmp/w984dv_probe.exs` written as probe input.
