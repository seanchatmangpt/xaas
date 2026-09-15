# XAAS-2601: Replace action-wide `authorize_if(always())` bypasses with a real system/internal authority predicate

- **Status**: Closed — implemented + Chicago-validated (2026-09-15)
- **Severity**: High
- **Standing**: ALIVE for this fix (full suite: 632 passed, 40 excluded, 0 failures, `fix/v26.9.15-system-authority` @ 5d66a06, worktree `wt-v26915/xaas`)
- **Closure evidence**: new `Xaas.SystemAuthority` actor + `Xaas.Checks.SystemActor` (`Ash.Policy.SimpleCheck`); every internal-only mutation bypass (`Run :tick/:advance_cycle/:transition_state`, `Epoch :create/:start/:complete/:mark_missed/:mark_failed`, `Receipt :seal`, `WebhookDelivery :deliver/:retry_failed_deliveries`, `HoldRequest :expire_stale`) now admits ONLY a genuine system authority actor instead of `always()`. Internal callers (NextEpoch, EpochReactor incl. undo, MissedEpochs, CreateFirstEpoch, webhook retry loop, EnqueueWebhookDeliveries) pass the actor explicitly rather than `authorize?: false`; AshOban schedules supply `default_actor` so cron paths still authorize for real. Chicago suite `test/xaas/ultracode/system_authority_chicago_test.exs` proves the falsifier: ordinary actor, nil actor, and fabricated lookalike are all REFUSED through the real calculus; system actor admitted.
- **Disclosed follow-up scope**: the broader-pattern sites outside the review's named change set (route_secrets/route_feature_flags create/update, autofde_planner `request_match`/`request_catalog`, the library domain's wide-open policies, and `action_type(:read)` read bypasses) retain their previous shape pending an intent classification — they were not part of the flagged internal-mutation set and may be legitimately public API actions.
- **Found by**: 14-hour cross-repo code review, window 2026-09-14 9:40 PM → 2026-09-15 11:40 AM PDT (inspection, not execution)

## Evidence

The PR #47 refactor removes numerous `authorize?: false` call sites — directionally good. But resources now contain action-wide bypasses, e.g. around `Run.transition_state`, with equivalent rules for other internally intended mutations. Live sites include `lib/xaas/ultracode/run.ex` (with `lib/xaas/ultracode/validations/run_transition_allowed.ex`), `lib/xaas/ledger/account.ex:20`, `lib/xaas/ledger/balance.ex:15`, `lib/xaas/ledger/transfer.ex:20`, `lib/xaas/platform/route_projects.ex:16`, `lib/xaas/platform/webhook_delivery.ex:83,92`, and others:

```elixir
bypass action(:transition_state) do
  authorize_if(always())
end
```

`Run.transition_state` accepts both `state` and `standing`, while the action-wide bypass supplies no actor, capability, execution context, or internal-system predicate.

## Impact

"Internal-only" exists in the architectural intent, but not in the authorization calculus. Any caller that reaches that Ash action through the normal authorization path satisfies the bypass — that is **broader** than an explicitly localized internal `authorize?: false` call. Ranked #3 in the cross-repo closure order.

## Fix

Make **system/internal authority a real predicate/object** — an actor plus capability/execution-context predicate that the authorization calculus evaluates — rather than replacing a local bypass with a global action bypass.

## Falsifier (acceptance)

Invoke `transition_state` as an ordinary non-system actor through Ash authorization. It must be refused. Under the current policy, the rule itself says it should authorize.
