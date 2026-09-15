# XAAS-2601: Replace action-wide `authorize_if(always())` bypasses with a real system/internal authority predicate

- **Status**: Closed — implementation complete; exact-head execution evidence is attached to PR #48.
- **Severity**: High
- **Standing**: Do not inherit `ALIVE` across revisions. Historical local evidence exists for predecessor heads; the merged subject must use PR #48's exact-head court as its execution receipt.
- **Closure evidence**: `Xaas.SystemAuthority` now has a closed internal-service vocabulary and `Xaas.Checks.SystemActor` derives the required service from the exact resource/action. Protected mutations are `Run :tick/:advance_cycle/:transition_state`, `Epoch :create/:start/:complete/:mark_missed/:mark_failed`, `Receipt :seal`, `WebhookDelivery :deliver/:retry_failed_deliveries`, and `HoldRequest :expire_stale/:expire`. Internal callers carry an admitted actor through the normal Ash authorization calculus. AshOban schedules supply `:oban_scheduler`; webhook row delivery requires `:webhook_dispatcher`; Ultracode mutations require `:ultracode_reactor`. Hold expiry propagates the scheduler actor through the consequence-bearing per-row `:expire` update instead of dropping to `authorize?: false`.
- **Historical local evidence**: the original implementation at `5d66a06` recorded `mix test`: 632 passed, 40 excluded, 0 failures. After the diagnostic probe was removed, `4f637296` recorded a 10-test Chicago rerun. These are predecessor receipts, not proof for later heads.
- **Exact-head verification surface**: `test/xaas/ultracode/system_authority_chicago_test.exs` proves ordinary, nil, and lookalike actors are refused. `test/xaas/system_authority_capability_chicago_test.exs` adds cross-service refusal, closed-vocabulary refusal, scheduler-only cron entry, and real HoldRequest cron-to-row mutation propagation. The repository CI court asserts literal subject SHA before format/compile/test/static checks.
- **Residual authority boundary**: `Xaas.SystemAuthority` is an application-level actor/capability inside the trusted BEAM application, not a cryptographic or OS isolation primitive. Trusted in-process code can construct the struct. The claim is therefore fail-closed Ash authorization for the listed actions against external/ordinary actors and wrong service capabilities, not protection from arbitrary malicious code already executing inside the application VM.
- **Disclosed follow-up scope**: broader-pattern `always()` sites outside this ticket's classified internal-mutation set (`route_secrets`/`route_feature_flags` create/update, `autofde_planner` `request_match`/`request_catalog`, library-wide policy questions, and read bypasses) remain separate intent-classification work. They are not silently reclassified by XAAS-2601.
- **Found by**: 14-hour cross-repo code review, window 2026-09-14 9:40 PM → 2026-09-15 11:40 AM PDT.

## Evidence boundary

PR #47 removed numerous localized `authorize?: false` call sites but introduced action-wide bypasses such as:

```elixir
bypass action(:transition_state) do
  authorize_if(always())
end
```

That shape made "internal-only" an architectural comment rather than an authorization fact: any caller reaching the action through normal authorization satisfied the bypass.

The first XAAS-2601 implementation replaced `always()` with a typed system actor, which closed the ordinary/nil/lookalike-actor hole but still left two ambiguities discovered during PR #48 review:

1. every policy used `{Xaas.Checks.SystemActor, []}`, so a valid system actor for one service could satisfy another service's action; and
2. `HoldRequest.expire_stale` admitted the scheduler at the outer action but invoked the actual per-row `:expire` mutation with `authorize?: false`.

The final design closes both: the check maps exact protected actions to their required service capability, unknown mappings refuse, and the hold-expiry actor is carried through the real row mutation. `:expire` is excluded from HoldRequest's ordinary actor-present write policy, so failure of the system check cannot fall through to a broader write rule.

## Falsifiers

The boundary is false if any of these observations occurs through normal Ash authorization:

- an ordinary, nil, or lookalike actor performs a listed internal mutation;
- a valid `SystemAuthority` for the wrong service performs a protected action;
- an unknown system service is accepted;
- `HoldRequest.expire_stale` succeeds only by disabling authorization on its per-row `:expire` writes; or
- a future protected subject absent from the capability map acquires ambient system authority instead of being refused.
