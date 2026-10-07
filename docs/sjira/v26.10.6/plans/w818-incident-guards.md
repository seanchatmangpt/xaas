# W818 — Incident Guards (closing W793 gaps (a)/(b))

- **Lane**: W818, v26.10.6 campaign
- **Subject**: `/Users/sac/xaas` @ `a0723bf6`, branch `feat/playwright-surface` (canonical checkout, no worktree)
- **Standing**: ALIVE (exact subject, observed execution, real sandboxed Postgres, zero mocks — mock grep over the new/changed files: zero matches)
- **Artifacts** (all uncommitted, per lane contract):
  - `lib/xaas/operations/incident.ex` — wired the two guards
  - `lib/xaas/operations/validations/incident_resolved_is_terminal.ex` — new validation module
  - `test/xaas/operations/incident_lifecycle_deepening_test.exs` — two gap pins converted to the corrected contract
  - `test/xaas/operations/incident_test.exs` — one stale fixture migrated to the corrected lifecycle (create-then-update, since `:create` never accepted `:resolved_at`)
  - receipt: `docs/sjira/v26.10.6/plans/w818-incident-guards.md`

## Before (W793's typed findings, observed live on a0723bf6)

- `GAP(RESOLVED_AT_GUARD_ONLY_ON_UPDATE)`: `:create` accepted `status: :resolved` with `resolved_at == nil`.
- `GAP(NO_REOPEN_GUARD)`: `resolved → open` permitted via `:update`, retaining the stale `resolved_at`, and re-satisfying `ApprovalDrFailoverRequiresOpenIncident`'s precondition query (real cross-resource side effect).

## After (both closed)

- **Guard (a)** — `Xaas.Operations.Validations.IncidentResolvedRequiresResolvedAt` is now wired onto `:create` as well. Because `:create` never accepted `:resolved_at`, a `:resolved`-at-birth incident is refused outright: resolution requires a dateable update, never a creation-time mint.
- **Guard (b)** — new `Xaas.Operations.Validations.IncidentResolvedIsTerminal` wired onto `:update`: when the persisted row is `:resolved` and the update would move status off `:resolved`, refused (`Ash.Error.Invalid`); row unchanged on disk. Same-status postmortem annotation stays allowed. The stale-`resolved_at` retention dies with the reopen path itself.

## Mutation rationale per guard (why each guard is non-vacuous)

- **(a)** Falsifier: the W793 gap pin asserted `create(status: :resolved, resolved_at: nil)` succeeded and persisted. The converted court now asserts `{:error, %Ash.Error.Invalid{}}` on the exact same payload plus zero rows written. The guard flips the observable behavior on the identical payload — if the validation is removed from `:create`, the converted court fails.
- **(b)** Falsifier: the W793 gap pin asserted `resolved → open` succeeded and retained stale `resolved_at`. The converted court now asserts refusal + on-disk invariants (still `:resolved`, `resolved_at` intact) and that same-status postmortem annotation still succeeds (the guard is not over-broad). Removing the terminal guard flips the court.

## Typed findings left open (out of scope, per lane contract)

- `GAP(NO_RESOLVED_AT_GUARD)`: `resolved_at` may still be set while status stays `:open` — pinned in the deepening test, unfixed.
- `GAP(NO_POSTMORTEM_STATUS_GUARD): postmortem may be `:final` while `:open` — pinned in the deepening test, unfixed.
- `GAP(NO_CROSS_REFERENCE)`: no incident↔route-castle reference at the resource layer — pinned in the deepening test, unfixed.

## Commands / exits (real tails)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW818 mix compile
  exit 0 (only pre-existing ash_affidavit @envelope_domain_tag warning, unrelated)

$ ... mix test test/xaas/operations/incident_lifecycle_deepening_test.exs \
        test/xaas/operations/incident_test.exs
Finished in 0.7 seconds (0.7s async, 0.00s sync)
Result: 29 passed
```

## Transport failures during the lane (all repaired, none outstanding)

1. **W801 deconflict hit, repaired**: my first cut of `incident_resolved_is_terminal.ex` referenced `Ash.Changeset.OriginalDataNotLoaded`, which does not exist in the pinned ash 3.34.4 — verified by my own grep over `deps/ash` (zero hits) after W801's report. Removed; house idiom (`changeset.data` + `Ash.Changeset.get_attribute/2`); `mix compile` exit 0 confirmed before any test run.
2. **First deepening+incident run: 28/29** — the pre-existing `incident_test.exs:121` fixture minted `:resolved` at `:create` (the exact gap guard (a) closes), session-introduced failure. Fix-forward: fixture now creates `:open` then resolves via the real `:update` with `resolved_at`. Rerun: 29/29.
3. Cold `_build-laneW818` dep compile under 10 min; a background test launch timed out at 600s while compiling deps and was stopped; lane build root retained and reused, final runs fast (0.7s).
4. Mixed stale paths in my first `tail` of the task output file — re-read from the correct task output path.

## Standing vocabulary

- **ALIVE**: both guards on the exact subject, real sandboxed Postgres, 29/29 across the deepening file + pre-existing `incident_test.exs`.
- **GAP(NO_RESOLVED_AT_GUARD)**, **GAP(NO_POSTMORTEM_STATUS_GUARD)**,
  **GAP(NO_CROSS_REFERENCE)** — remain open as typed findings, pinned as
  behavior in the deepening test so any later guard flips them (the
  intended falsifier).

## Replay

```
cd /Users/sac/xaas && git rev-parse HEAD   # a0723bf6
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW818 \
  mix test test/xaas/operations/incident_lifecycle_deepening_test.exs \
           test/xaas/operations/incident_test.exs   # 29 passed
```

## Cleanup

`_build-laneW818` deleted by the lane itself per the same-checkout fan-out
cleanup law (lease closed at integration).
