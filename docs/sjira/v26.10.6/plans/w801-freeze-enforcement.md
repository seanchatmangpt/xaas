# W801 — FreezeWindow minimal enforcement wiring (receipt)

- **Lane**: W801, v26.10.6 campaign, /Users/sac/xaas @ a0723bf6 (feat/playwright-surface)
- **Files written**:
  - `lib/xaas/governance/validations/audit_export_token_no_active_freeze_window.ex` (new)
  - `lib/xaas/governance/audit_export_token.ex` (one `validate` line + comment added to `:issue`)
  - `test/xaas/governance/export_token_deepening_test.exs` (extended: 11 → 16 tests)
  - this receipt. Nothing committed.
- **Standing**: PARTIAL_ALIVE — primary suite 16/16 exit 0 on the exact subject; regression
  suites (freeze_window_test, approval_freeze_override_test) BLOCKED by a concurrent
  lane's in-flight compile break (below), not by this diff.

## What was measured before (W765 GAP-D)

W765 (`w765-export-token-deepening.md`) disclosed: an active `FreezeWindow` blocks
nothing in-process — the only enforcement point was
`ApprovalFreezeOverrideFreezeWindowExists` (existence + same-org +
`allow_emergency_override`), i.e. the window gated only override filing, never any
freeze-sensitive mutation.

## What was wired

`Xaas.Governance.Validations.AuditExportTokenNoActiveFreezeWindow` on
`AuditExportToken :issue` — the coordinator-sanctioned minimal path (the resource most
adjacent to the audit-export governance pair). Semantics:

- real `authorize?: false` `Ash.read` over `FreezeWindow` filtered
  `org_id == changeset org and starts_at <= now <= ends_at` (now truncated to :second,
  matching the column type);
- match → typed `Ash.Error.Invalid` on field `:org_id`, message naming the window id and
  ends_at; nothing persisted (validation runs before `GenerateAuditExportToken`);
- read error → fail closed (refusal, not pass), same discipline as
  `ApprovalFreezeOverrideFreezeWindowExists`;
- scoped to `:issue` only — `:revoke` deliberately stays available during a freeze;
- **not** a global freeze interceptor; other freeze-sensitive paths
  (`ApprovalEnvironmentPromote`'s documented platform-console `checkFreezeGuard`
  analogue) remain unwired — that is a design change beyond this repair and stays
  disclosed as such.

## Mutation rationale (vacuity guard)

Before this diff, the active-window test fails by construction (`:issue` accepted with
any active window present), so the new tests cannot pass on the reverted subject — the
refusal is caused by exactly this validation, not ambient behavior. The pre-existing
`ApprovalFreezeOverrideFreezeWindowExists` tests (unchanged, still passing) show the
override path was untouched.

## Verification ladder (real output)

1. `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW801 mix test test/xaas/governance/export_token_deepening_test.exs`:

```
................
Finished in 1.0 seconds (1.0s async, 0.00s sync)
Result: 16 passed
```

New tests pin: active same-org window → typed refusal on `:org_id`, zero rows persisted;
expired window → `:issue` succeeds; future window → `:issue` succeeds; active window in a
different org → no block; `ApprovalFreezeOverride` against an emergency-eligible window
still files during a freeze while the same org's `:issue` is refused (both paths in one
assertion).

2. Regression suites — **BLOCKED, not failed**:

```
== Type checking failed with errors ==
lib/xaas/operations/validations/incident_resolved_is_terminal.ex:29:9:
struct Ash.Changeset.OriginalDataNotLoaded is undefined
```

`incident_resolved_is_terminal.ex` is an **untracked file created mid-session by a
concurrent lane** (not in W801's write set; confirmed `git status` untracked). The struct
`Ash.Changeset.OriginalDataNotLoaded` does not exist anywhere in `deps/ash` (grep of the
exact dep in the lockfile-resolved checkout: zero matches). Lane disjointness: this lane
does not modify another lane's in-flight file, so the freeze_window /
approval_freeze_override suites could not be re-run to green after the diff — they were
green-relevant only for `FreezeWindow :create` and the override path, both of which are
also covered inside the 16/16 deepening suite (the override-path tests are the unchanged
W765 tests, which still pass).

## Falsifiers

- Revert the `validate` line in `audit_export_token.ex :issue` → the active-window
  refusal test must fail (it passes now; non-vacuous).
- `mix test test/xaas/governance/freeze_window_test.exs test/xaas/governance/approval_freeze_override_test.exs`
  once the blocking lane's file compiles — expected green, BLOCKED here by transport.

## Cleanup

`_build-laneW801` left in place for the coordinator (contains the last full compile of
W801's diff; deletion is the coordinator's integration step per the fanout law).
