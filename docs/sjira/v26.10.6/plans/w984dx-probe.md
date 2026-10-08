# W984dx — FreezeWindowActive Chicago court (probe receipt)

- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface` (HEAD `c0626503`, working tree shared — no commits made, per lane law)
- **Scope**: Chicago court for `Xaas.Governance.Checks.FreezeWindowActive` (`lib/xaas/governance/checks/freeze_window_active.ex`), uncovered in W984du's fifth re-census.
- **Pre-existing coverage (not touched)**: `test/xaas/governance/freeze_window_active_gate_test.exs` (W969b, action-level `:approve` refusals/lifts, unapproved override, control) — read, not edited.
- **New file**: `test/xaas/governance/freeze_window_active_deepening_test.exs` — 14 tests, all `match?/3` unit-contract branches the gate court does not reach:
  - fall-through clauses: no `:subject` key, subject `org_id: nil`, unrecognized subject shape → `false`
  - `%Ash.Changeset{action_type: :update}` org_id extraction clause (active window → `true`; data lacking org_id → `false`)
  - boundary inclusivity on real datetimes: `starts_at == now` and `ends_at == now` (second-truncated) are IN the window; strictly-future start and strictly-past end are NOT; foreign-org window does not forbid
  - unit-level override branching: overrideable+no override → forbid; overrideable+APPROVED override → lift; FILED-only override → still forbids
  - discovered real contract: `ApprovalFreezeOverride` create **refuses filing** against a non-overrideable window (`Ash.Error.Invalid`) — asserted directly
- **Commands/exits**:
  - `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984dx mix test test/xaas/governance/freeze_window_active_deepening_test.exs` → `14 passed` (exit 0; lane build root compiled fresh, ~430 MB)
  - Mock gate: `mix run -e 'IO.inspect(...scan_mock_usage(["test","lib"]))'` → `[]`
  - Zero mocks/patches in the new file; boundaries are real datetimes written to real `FreezeWindow` rows in the SQL sandbox.
- **lib/ untouched**: yes — no edits outside the new test file + this receipt.
- **Standing**: ALIVE (observed execution on the exact lane subject, 14/14 green).
- **Cleanup**: lane build root deletion `rm -rf _build-laneW984dx` was DENIED by the
  permission system at close — `_build-laneW984dx` (~430 MB) REMAINS ON DISK and needs
  coordinator cleanup per the lane-lease law.
