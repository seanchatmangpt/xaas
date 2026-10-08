# W650y4 — RegistrationStatusTransition depth court

Lane: W650y4, xaas v26.10.6 campaign, branch `feat/playwright-surface`.
Subject: `test/xaas/conference/registration_status_transition_court_w650y4_test.exs`
(first direct depth court over `Xaas.Conference.Validations.RegistrationStatusTransition`,
`lib/xaas/conference/registration.ex:94-139`).

## Module surface analysis

`RegistrationStatusTransition` is an `Ash.Resource.Validation` on
`Registration :update` (and carried on `:cancel`, which force-sets
`:cancelled`). Surface:

- `@forward_edges`: `{:registered, :cancelled}`, `{:registered, :attended}`,
  `{:cancelled, :attended}`; published via `forward_edges/0`.
- `validate/3`: admits `{current, new} in @forward_edges` **or** `current == new`
  (self-transition carve-out, W973b); otherwise typed
  `Ash.Error.Changes.InvalidChanges` "…is not an admitted forward edge…".
- Semantics: `:registered` open; `:attended` terminal (one-shot, work cannot
  un-happen); `:cancelled` re-openable to `:attended` only.

Prior coverage (measured before writing): conference_deepening_test covered a
registered→cancelled→attended walk, the `{:attended, :registered}` refusal, and
the `{:registered, :registered}` self-transition — implicit/walk-shaped only.
W984do's `registration_terminal_cancel_guard_court_w984do` owns the
`RegistrationTerminalCancelGuard` / `:cancel` terminal-guard surface (cancel of
terminal refused; NOT duplicated here). The full 9-cell matrix, illegal edges
`{:cancelled, :registered}` / `{:attended, :cancelled}`, self-transitions in
`:cancelled`/`:attended`, and one-shot semantics were uncovered.

## Court (5 tests, Chicago, real ETS Ash actions, no mocks)

1. **Forward-edge matrix** — each published edge exercised on a fresh row;
   persisted status asserted after `:update`. Kills the drop-one-edge mutant.
2. **Illegal-edge typed refusals** — all three non-admitted non-self edges
   raise `Ash.Error.Invalid` ~r/not an admitted forward edge/ and the row is
   re-read at its prior status (nothing written). Kills the unconditional-:ok
   mutant and the direction-inversion mutant.
3. **Self-transition matrix {s, s} for all three states** — kills the
   remove-carve-out mutant and the `:registered`-only carve-out mutant.
4. **One-shot attendance** — registered→attended, then both non-self targets
   refused while the self-update stays admitted. Kills the add-attended-outedge
   mutant.
5. **`forward_edges/0` contract** — published list equals the documented set
   exactly, and a pair absent from it is refused at runtime, proving guard and
   introspection share one source. Kills add+remove (net-zero) edge-list
   mutants.

Fixture note (found during run 1): rows for one (attendee, session) pair are
unique per ACTIVE status per `EnforceActiveRegistrationIdentity` — each matrix
leg uses a fresh attendee on a shared unlimited-capacity session.

## Verification (real output)

- Run 1, fresh root `_build-laneW650y4`: 2/5 → fixed fixture (active-duplicate
  identity), not a surface failure.
- Run 2, warm `_build-laneW650y4`: `Result: 5 passed` (mix test, exit 0).
- Run 3, fresh root `_build-laneW650y4-fresh2` (×2 fresh-root requirement):
  `Result: 5 passed` (exit 0; full deps+app compile from empty root, resumed
  across three 30-minute background windows — concurrent-lane compile load).

## Standing

- Court: ALIVE on `feat/playwright-surface` (5/5, real ETS Ash actions).
- No commit made (lane law: coordinator owns commits).
- Build roots left for coordinator: `_build-laneW650y4` (warm),
  `_build-laneW650y4-fresh2` (fresh). `rm -rf` was permission-denied in this
  lane; per cleanup law these are leases the coordinator should delete at
  integration.
