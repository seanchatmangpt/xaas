# W984c — Registration terminal-cancel guard (W973b closure)

Lane: W984c, xaas v26.10.6, branch `feat/playwright-surface` (shared checkout, uncommitted).
Subject: `lib/xaas/conference/registration.ex` @ working tree 2026-10-07 (~10:20 PT), base = HEAD `691e0a93` + W983a uncommitted working-tree state.

## What was implemented

New top-level validation module
`Xaas.Conference.Validations.RegistrationTerminalCancelGuard`
(`lib/xaas/conference/registration.ex`), wired ONLY on the named `update :cancel` action:

- Terminal statuses: `[:cancelled, :attended]`.
- `validate/3`: if `Ash.Changeset.get_data(changeset, :status)` is terminal, returns
  `{:error, Ash.Error.Changes.InvalidChanges}` with message
  `"cannot cancel a terminal registration: status :cancelled is terminal and the :cancel action admits no self-transition (re-register via :create instead)"`.
- The bare `:update` action is untouched — its self-transition carve-out for
  artifacts-only writes is preserved.
- Legal walk preserved: cancelled→re-register is a `:create` (W981s scoped identity /
  `EnforceActiveRegistrationIdentity`), untouched by the guard.

## Falsifier (W973b) — now GREEN

`test/xaas/conference/enrollment_journey_court_test.exs` — **5/5 passed** (exit 0),
including the W973b leg
`"W973b terminal guard: a cancelled registration cannot :cancel again (typed refusal)"`
(asserts `Ash.Error.Invalid` + `~r/cancelled/` — satisfied by the message above; no test
softening). Command:

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984c \
  mix test test/xaas/conference/enrollment_journey_court_test.exs
# Result: 5 passed  (fresh lane build root)
```

## Other runs (real tails)

```
mix test test/xaas/conference/conference_test.exs + enrollment file → 8 passed (exit 0)
mix test test/xaas/conference test/xaas/conference_deepening_test.exs → 21/22 passed
```

## Pre-existing RED (NOT introduced by this lane — measured)

`Xaas.ConferenceDeepeningTest "reads are deterministic after writes..."` (test/xaas/conference_deepening_test.exs:288)
fails **with or without** my guard (10/11 both ways), and passes 11/11 only against
HEAD's registration.ex — i.e. the failure is attributable to W983a's uncommitted
working-tree change (identity removed → `EnforceActiveRegistrationIdentity` scoped to
ACTIVE statuses), not to W984c. The test still asserts the pre-W981s unscoped
"has already been taken" contract that W981s/W983a deliberately replaced; the W981s
court in the enrollment file asserts the opposite (re-register must succeed). The two
tests are in direct conflict; the deepening test leg is stale relative to the admitted
W981s contract. Left untouched — test file outside lane scope (write scope:
`lib/xaas/conference/` + this receipt). Coordinator should route the stale deepening
leg to the owner of the test file (W983a/W981s follow-up).

## Standing

- W973b falsifier: GREEN (ALIVE on working-tree subject).
- Guard module + wiring: hand-written, in lane scope.
- Legal walk (W982o leg 6 / W981s re-register): witnessed green in enrollment 5/5.
- Pre-existing deepening conflict: disclosed, not repaired, not softened.

## Replay

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984c \
  mix test test/xaas/conference/enrollment_journey_court_test.exs \
           test/xaas/conference/conference_test.exs   # expect 8 passed
```

Build root `_build-laneW984c` deleted at integration (lane-lease law).
