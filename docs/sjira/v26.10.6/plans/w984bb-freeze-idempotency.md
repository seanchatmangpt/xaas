# w984bb — freeze-window duplicate-creation adjudication (v26.10.6)

**Standing**: DESIGN-ACCEPTED — no register row added.
**Lane**: W984bb, xaas v26.10.6, branch `feat/playwright-surface`. No commit (per lane scope).
**Cites**: w983g typed DESIGN-FINDING
(`/Users/sac/xaas/docs/sjira/v26.10.6/plans/w983g-freeze-deepening.md`,
court 4 in `/Users/sac/xaas/test/xaas/governance/freeze_window_deepening_test.exs:149`).

## The finding being adjudicated

w983g court 4 witnessed that `FreezeWindow :create` has no unique identity on
`(org_id, starts_at, ends_at)` — a second identical create is ADMITTED, yielding
2 rows with no identity (permit-dup).

## Adjudication (1) — resource + consumers

- Resource: `/Users/sac/xaas/lib/xaas/governance/freeze_window.ex` — `:create`
  accepts `(org_id, starts_at, ends_at, reason, allow_emergency_override,
  created_by)`; no `identities` block, no unique index
  (`priv/repo/migrations/20260821021000_multitenancy_pilot_and_new_resources.exs`
  creates `freeze_windows` with no unique constraint).
- Consumers (all three, read fresh this lane):
  1. `Xaas.Governance.Checks.FreezeWindowActive`
     (`lib/xaas/governance/checks/freeze_window_active.ex:87-110`) —
     existential active-window query (`{:ok, [_ | _]} -> forbidden`), reads
     only the FIRST matched row for the emergency-override lift.
  2. `Xaas.Governance.Validations.AuditExportTokenNoActiveFreezeWindow`
     (`lib/xaas/governance/validations/audit_export_token_no_active_freeze_window.ex:49-50`) —
     same existential shape.
  3. `Xaas.Governance.Validations.ApprovalFreezeOverrideFreezeWindowExists` —
     existence check by `freeze_window_id` (any real row satisfies).
  All three are existential: duplicate rows are functionally harmless to
  enforcement. Either row alone triggers the gate; lifting via an approved
  `ApprovalFreezeOverride` references one exact row id and is unaffected by
  its duplicate sibling. No consumer iterates rows, counts them, or treats
  multiplicity as meaning.

## Adjudication (2) — dup-creation reachability from admitted paths

- JSON:API: yes — the resource registers `post(:create)` at base
  `/freeze_window` (`freeze_window.ex:88-98`), mounted under the
  `/internal-api` forward (`lib/xaas_web/plugs/set_internal_api_system_actor.ex:52`
  names `freeze_window` in the plug's route list). Admitted path:
  `RequireInternalApiToken` Bearer gate → `SetInternalApiSystemActor` →
  `Xaas.Checks.SystemActor` policy on `:create` (`freeze_window.ex:65-72`).
- No UI/`live_view` or other creation path exists (grep over `lib/xaas_web`
  hits only the plug list). No Reactor/actuation path creates freeze windows.

So dup creation IS reachable from the one admitted path (a double-submit by
an internal-api token holder). The question is whether that is semantically
confusing. Verdict on the concrete scenarios:

- **Identical double-submit** (w983g's witness): harmless. All consumers are
  existential; enforcement semantics are identical with 1 or N identical rows;
  lifting the freeze works identically; deleting one row leaves the other
  active (arguably more robust for a deletion race).
- **Overlapping-but-different windows** (e.g. two double-submits with drift):
  also not confusing — the contract is a union: the gate fires if ANY window
  covers `now`. Overlap is legitimate freeze semantics, not a defect. The
  `reason` and `allow_emergency_override` of the first-matched row govern the
  emergency path, which is the only multiplicity-sensitive point, and that is
  a documented existential-read-first contract, not a dup artifact.

## Verdict

Dup creation is reachable from an admitted path but NOT semantically
confusing: the freeze contract is existential (any active window governs),
overlap is legitimate, and identical dups change nothing observable except
row count. This is row-count hygiene, not a product gap. **DESIGN-ACCEPTED,
no register row added** (per lane instruction: row only if reachable AND
semantically confusing; only the first conjunct holds).

## Re-witness (real run, this lane)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984bb \
  mix test test/xaas/governance/freeze_window_deepening_test.exs
....
Finished in 1.4 seconds (0.00s async, 1.4s sync)
Result: 4 passed
[exited with code 0]
```

Lane build root `_build-laneW984bb` deleted after the run (confirmed gone on
disk).

## Standing

- Court 4 (permit-dup): RE-WITNESSED ALIVE on branch `feat/playwright-surface`
  (working tree, uncommitted — no lane commit per scope).
- DESIGN-ACCEPTED disposition: ADMITTED by this receipt; falsifier for any
  future reopening would be a consumer of `FreezeWindow` that iterates/counts
  rows or treats multiplicity as meaning (e.g. a UI listing windows would
  surface the dup visually), or a second admitted create path that bypasses
  the SystemActor gate.
