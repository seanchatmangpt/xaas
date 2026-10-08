# W650h29 — Registration status-transition surface: unified truth (notes)

Lane W650h29, xaas v26.10.6 campaign, branch `feat/playwright-surface`.
Sources re-read on disk 2026-10-07: `lib/xaas/conference/registration.ex`
(lines 82-171), `w650y4-status-transition.md`, `w984do-probe.md`,
`v26.10.7/plans/w650h16-commit.md`.

## The two validations (one module, two guards)

- `RegistrationStatusTransition` (registration.ex:94-139): Ash validation on
  `:update` (and carried on `:cancel`). Forward edges `@forward_edges` =
  `{:registered, :cancelled}`, `{:registered, :attended}`,
  `{:cancelled, :attended}`; published via `forward_edges/0`. `validate/3`
  admits a forward edge **or** self-transition `{s,s}` (W973b carve-out for
  artifacts-only updates); otherwise typed `InvalidChanges`.
- `RegistrationTerminalCancelGuard` (registration.ex:141-171+): guard on the
  `:cancel` action only. `@terminal_statuses = [:cancelled, :attended]`;
  refuses cancel-of-terminal because `:cancel` force-sets `:cancelled`, and
  the self-transition carve-out must not apply to an explicit product action.

## Relationship: compose, don't overlap

`:cancel` stacks BOTH validations (registration.ex:85-86): the terminal guard
refuses cancel-of-`:cancelled`/`:attended` up front; the transition module
then sees only legal `{:registered, :cancelled}` (a forward edge) — for an
active row the transition check is trivially satisfied. Conversely on plain
`:update`, only the transition module runs: terminal self-transitions pass
via the carve-out (W984do court test 4 witnesses this). They compose: guard =
terminal-refusal on `:cancel`; transition module = edge matrix on all update
paths. No duplicated slice.

## Court ownership map (do not re-derive)

| Slice | Owner | Receipt |
|---|---|---|
| Full 9-cell edge matrix, illegal edges, self-transitions, one-shot `:attended`, `forward_edges/0` contract | W650y4 (5 tests, `test/xaas/conference/registration_status_transition_court_w650y4_test.exs`) | `v26.10.6/plans/w650y4-status-transition.md` |
| Terminal-cancel guard: cancel-of-terminal refused (both terminal states), active cancel succeeds, carve-out is `:cancel`-scoped, guard reads persisted data | W984do (5 tests, `registration_terminal_cancel_guard_court_w984do_test.exs`) | `v26.10.6/plans/w984do-probe.md` |
| Landing of the W650y4 court file at commit `bdc6d823` | W650h16 | `v26.10.7/plans/w650h16-commit.md` (W650h17 receipt `36cadd9d` confirms SKIP-as-already-landed) |

Standing: ALIVE on `feat/playwright-surface` — W650y4 court 5/5 (fresh-root
re-run), W984do court 5/5, both landed via W650h16 `bdc6d823`.
