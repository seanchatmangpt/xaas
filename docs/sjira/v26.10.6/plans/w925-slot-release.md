# W925 — Cancel Frees the Capacity Slot (EnforceSessionCapacity status filter)

Lane: W925, xaas v26.10.6 campaign, branch `feat/playwright-surface`.
Repo: `/Users/sac/xaas` (canonical checkout, no worktree).

## Subject

- `lib/xaas/conference/registration.ex` — `Xaas.Conference.Changes.EnforceSessionCapacity`
- `test/xaas/conference/enrollment_journey_court_test.exs` — extended (W893's file, extend-only)
- New receipt: `docs/sjira/v26.10.6/plans/w925-slot-release.md`

## Before

`EnforceSessionCapacity` counted ALL `Registration` rows for the target
session with no status filter, so a `:cancelled` registration still
consumed a slot — W893's `GAP(CancelDoesNotReleaseSlot)`, pinned as real
behavior in W893's journey court ("capacity counts ALL rows, cancelled
included, refusal repeats").

## After

Capacity counts only ACTIVE statuses. Real statuses read from the resource:
`:registered`/`:attended` (W795's forward-only transition set;
`:cancelled` is terminal via `RegistrationStatusTransition`, re-openable
only forward to `:attended`, never back to `:registered`). Fix:

```elixir
taken =
  Xaas.Conference.Registration
  |> Ash.Query.filter(session_id == ^session_id and status in @active_statuses)
  |> Ash.read!(authorize?: false)
  |> length()
```

with `@active_statuses [:registered, :attended]` (exposed as
`active_statuses/0` for future consumers).

## μ / diff

Handwritten fix (3 lines of logic + moduledoc) — the irreducible residue;
no framework generator covers Ash resource Change modules in this repo.
Modified hunks:

- moduledoc: documents the ACTIVE-status count and closes the gap name.
- `@active_statuses` attribute + `active_statuses/0`.
- capacity query: `status in @active_statuses` filter added.

Test changes (extend-only on W893's journey court):

- The old-behavior pin ("refusal repeats after cancel") replaced by the
  slot-release regression court: after cancel, re-registering Grace on the
  capacity-1 session SUCCEEDS and lands as `:registered`. Disclosed
  conversion per order.
- Moduledoc updated: real semantics + mutation rationale inline.

No other test pinned the old behavior: W715's `conference_test.exs` has no
capacity tests; W795's `conference_deepening_test.exs` capacity court
exercises registered rows only — stayed green unmodified.

## Mutation rationale

Drop `status in @active_statuses` from the capacity count → the count
reverts to all rows → after register→cancel the count is 1/1 → the
re-register create raises `Ash.Error.Invalid` ~r/at capacity \(1\/1 taken\)/
→ the court's `assert %Registration{} = re_reg` FAILS (the raise escapes
the test). The assertion is non-vacuous: it passes only when the filter is
present.

## Commands / exits (real tails)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW925 \
  mix test test/xaas/conference/enrollment_journey_court_test.exs \
           test/xaas/conference_deepening_test.exs \
           test/xaas/conference/conference_test.exs
# run 1: "Result: 15 passed"   (1.3s sync)
# run 2 (determinism): "Result: 15 passed"

# mock gate:
mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(
  ["lib/xaas/conference","test/xaas/conference","test/xaas/conference_deepening_test.exs"]))'
# => []
```

## Transport failures (real)

- First two test attempts failed to compile: committed duplicate AshJsonApi
  route in `lib/xaas/governance/audit_export_token.ex` (`patch(:use)` added
  by be23d26f colliding with `patch(:revoke)` at `/:id` —
  `ValidateNoOverlappingRoutes` raise). Typed
  BLOCKED(other-lane-committed-breakage); lib/ is outside this lane's
  ownership, no fix applied from W925. A sibling lane touched the file
  (now ` M` in git status) and the third attempt compiled green.

## Verification ladder

Narrow (3 conference test files, real ETS + real Ash actions).
Determinism ×2. Mock gate `[]`. W715/W795 courts unmodified and green.

## Standing

ALIVE (this lane, exact subject, observed execution ×2).

## Typed gaps

- None new. W893's `GAP(CancelDoesNotReleaseSlot)` is CLOSED by this fix.
- W893's `GAP(NoServerActionForCancel)` (cancel is a bare `:update`) remains
  open — out of W925 scope.

## Replay

```
cd /Users/sac/xaas
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW925 \
  mix test test/xaas/conference/enrollment_journey_court_test.exs \
           test/xaas/conference_deepening_test.exs \
           test/xaas/conference/conference_test.exs
```

Lane build root `_build-laneW925` deleted post-run. Not committed, per lane
contract.
