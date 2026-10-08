# W650z9 Probe — `ApprovalCastleVerbScheduleApprove` census-uncovered residue

- **Standing**: DISPOSITIONED (UNSUPPORTED residual class — no-op orphan change; no court written)
- **Lane**: W650z9, xaas v26.10.6, canonical checkout `/Users/sac/xaas`
- **Subject**: `lib/xaas/operations/changes/approval_castle_verb_schedule_approve.ex`
- **Build root**: `_build-laneW650z9` (deleted; see verification)

## Investigation

1. **Module shape** (`lib/xaas/operations/changes/approval_castle_verb_schedule_approve.ex`):
   13 lines. `init(opts) -> {:ok, opts}`, `change(changeset, ...) -> changeset`
   unchanged. It is a **no-op pass-through** Ash change with zero own behavior —
   no validation, no mutation, no side effect.
2. **Wiring**: zero references anywhere in `lib/` outside its own file. The
   resource `Xaas.Operations.ApprovalCastleVerbSchedule` at
   `lib/xaas/operations/approval_castle_verb_schedule.ex` declares its own
   `update :approve` action (lines 87+) with the `RequiresApprover` validation
   wired inline — it does **not** reference the `...Approve` change module. The
   change module is an **orphan**: never attached to any action.
3. **W984dp2 court** (`test/xaas/operations/approval_castle_verb_schedule_authority_test.exs`,
   described in `docs/sjira/v26.10.6/plans/w984dp2-ops-residue.md`): exercises the
   resource's `:approve` **action** (happy path, two typed `RequiresApprover`
   refusals, read bypass, row-unchanged assertions, mutation rationale naming
   `authorize_if(always())` and `bypass action_type(:read)`). It never touches
   the change module — correctly, because the change module contributes nothing.

## Root cause of census gap

Census greps module names; the court exercises the `:approve` action on the
resource, not the change module by name. The uncovered name is a no-op orphan,
so the census gap is a **name-mismatch artifact, not a coverage hole**.

## Disposition

Typed disposition, no court: **UNSUPPORTED(no-op-orphan-change)**. A depth court
on a module whose `change/3` is the identity function would test nothing (any
behavioral assertion would fail vacuously or pass on any implementation). Real
behavior (typed refusals, self-approval refusal, read bypass) is already
covered by the W984dp2 court on the `:approve` action itself.

## Commands / verification (real output)

```
$ grep -rn ApprovalCastleVerbScheduleApprove lib/  → only its own file (orphan confirmed)
$ cat approval_castle_verb_schedule_approve.ex → identity change/3 confirmed
$ grep -n "change\|approve" lib/xaas/operations/approval_castle_verb_schedule.ex
  → :approve action defined in-resource, RequiresApprover wired inline, no change-module reference
```

## Falsifier

If `...Approve` is ever wired onto an action (grep shows a non-self reference in
`lib/`) or gains non-identity `change/3` logic, this disposition is void and a
depth court is required.

## Cleanup

`_build-laneW650z9` left for coordinator (no test run was needed — read-only
investigation; no build root was ever created).
