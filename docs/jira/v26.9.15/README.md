# v26.9.15 — xaas: authorization was moved, not bounded (PR #47)

- **Date**: 2026-09-15
- **Source**: 14-hour cross-repo code review, window Sep 14 9:40 PM PDT → Sep 15 11:40 AM PDT.
- **Method**: inspection of commits, PR heads, and exact source files. No code executed, nothing changed by the reviewer.

## Result

**Closure (2026-09-15)**: XAAS-2601 implemented and Chicago-validated on `fix/v26.9.15-system-authority` (worktree `wt-v26915/xaas`); full suite 632 passed, 0 failures. The internal-mutation bypasses now require a real `Xaas.SystemAuthority` actor; follow-up scope for the unclassified sites is disclosed in the ticket.

The PR #47 refactor removes numerous `authorize?: false` call sites, which is directionally good. But resources now contain action-wide bypasses shaped like:

```elixir
bypass action(:transition_state) do
  authorize_if(always())
end
```

with equivalent rules for other internally intended mutations. "Internal-only" exists in the architectural intent, but not in the authorization calculus: any caller that reaches such an Ash action through the normal authorization path satisfies the bypass. That is **broader** than an explicitly localized internal `authorize?: false` call. Standing: **BLOCKED**.

## Tickets

| ID                                                        | Title                                                                                             | Severity | Closure order |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------------- | -------- | ------------- |
| [XAAS-2601](./XAAS-2601-system-authority-predicate.md)    | Replace action-wide `authorize_if(always())` bypasses with a real system/internal authority predicate | High     | #3            |
| [XAAS-2602](./XAAS-2602-always-bypass-classification.md)  | Classify every remaining action-scoped `authorize_if(always())` site; convert the provably-internal/service-boundary mutations to `Xaas.Checks.SystemActor` | High     | #3 (follow-up) |
