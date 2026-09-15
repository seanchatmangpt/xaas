# v26.9.15 — xaas: authorization was moved, not bounded (PR #47)

- **Date**: 2026-09-15
- **Source**: 14-hour cross-repo code review, window Sep 14 9:40 PM PDT → Sep 15 11:40 AM PDT.
- **Method**: inspection of commits, PR heads, and exact source files.

## Result

**Closure (2026-09-15)**: XAAS-2601 is implemented on PR #48 with service-scoped `Xaas.SystemAuthority` capability checks and end-to-end actor propagation through the classified internal mutations and AshOban cron paths. Historical local evidence on predecessor head `5d66a06` recorded 632 passed, 40 excluded, 0 failures; later heads do not inherit that standing. The authoritative execution receipt for the merged revision is PR #48's exact-head CI court. See [XAAS-2601](./XAAS-2601-system-authority-predicate.md) for the capability map, falsifiers, residual in-process trust boundary, and deliberately unclassified follow-up scope.

The PR #47 refactor removed numerous localized `authorize?: false` call sites, but resources then contained action-wide bypasses shaped like:

```elixir
bypass action(:transition_state) do
  authorize_if(always())
end
```

with equivalent rules for other internally intended mutations. "Internal-only" existed in architectural intent but not in the authorization calculus: any caller reaching such an Ash action through the normal authorization path satisfied the bypass. That was broader than an explicitly localized internal `authorize?: false` call and therefore **BLOCKED** until XAAS-2601 supplied an executable authority predicate.

## Tickets

| ID | Title | Severity | Closure order |
| --- | --- | --- | --- |
| [XAAS-2601](./XAAS-2601-system-authority-predicate.md) | Replace action-wide `authorize_if(always())` bypasses with a real system/internal authority predicate | High | #3 |
