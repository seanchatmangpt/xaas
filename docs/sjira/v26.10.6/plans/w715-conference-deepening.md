# W715 — Conference Domain Deepening (receipt)

- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface` HEAD `a0723bf6` (uncommitted lane; no commit per lane contract)
- **Lane**: W715, v26.10.6 campaign. Files written: `test/xaas/conference_deepening_test.exs` (new, this receipt).
- **Standing**: ALIVE (witnessed execution on the exact subject, 9/9 passing).

## What was done

Read `lib/xaas/conference.ex` and all 7 resources
(`lib/xaas/conference/{event,track,session,speaker,sponsor,attendee,registration}.ex`),
then wrote `test/xaas/conference_deepening_test.exs`: Chicago-style courts on
real `Ash.DataLayer.Ets` tables via real Ash actions, no mocks.

## Courts (9 tests, all real row-state assertions)

(a) Registration lifecycle: create defaults to `:registered`; `:registered →
:cancelled → :attended` transitions persist and re-read correctly.

(b) Cross-resource integrity: a Registration's `attendee_id`/`session_id`
resolve via `Ash.get!` to the real Attendee/Session rows, and Session→Track→Event
chains to the seeded event (application-level join; asserted as the real load path).

(c) Capacity/sponsorship invariants — honest findings, read before writing:

- **ENFORCED**: Sponsor `tier` `one_of` (`:diamond/:gold/:silver/:bronze`) —
  `:platinum` refused with `Ash.Error.Invalid` "invalid value".
- **NOT ENFORCED (asserted as behavior)**: no capacity/attendance-limit logic
  exists anywhere in the domain (5 registrations on one session all accepted).
- **NOT ENFORCED (asserted as behavior)**: no transition guard on Registration
  `status` — `:cancelled → :attended → :registered` is accepted; attended work
  can "un-happen".
- **NOT ENFORCED (asserted as behavior)**: no Ash `relationship` on any
  resource, so no FK enforcement — a Registration with a dangling (nonexistent)
  `attendee_id`/`session_id` is stored without refusal.

(d) Determinism: 6 repeated reads after writes (including after a failed
duplicate write) return an identical row projection.

Additional typed refusals witnessed: `unique_attendee_session` identity
conflict (`Ash.Error.Invalid`), duplicate-registration case leaves exactly 1 row.

## Commands + exits (real tails)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW715 \
  mix test test/xaas/conference_deepening_test.exs
# first run (cold build, 437M): 9 passed, 1 compiler warning (reg3 unused) — fixed
# rerun (warm):
.........
Finished in 0.8 seconds (0.00s async, 0.8s sync)
Result: 9 passed
[exited with code 0]
```

Excluded by default ExUnit tags (`:stress`, `:eu_ai_act`, etc.); none apply.

## Typed gaps / refusals

- `UNSUPPORTED(capacity-invariant)`: no capacity model exists to test.
- `UNSUPPORTED(transition-guard)`: status state machine absent; lifecycle
  refusals are limited to the atom `one_of` + identity constraint.
- `UNSUPPORTED(referential-integrity)`: bare uuid attributes, no relationships;
  dangling references accepted by the data layer.
- `@moduletag :eu_ai_act` NOT applied: no genuine Art-line tie — the domain is
  conference roster projection with no AI-provider, ART.12 chain, or EU AI Act
  admission surface involved.

## Cleanup

`_build-laneW715` (437M) LEFT IN PLACE for coordinator — `rm -rf` was refused
by the permission system in this lane. It is a pure build artifact; safe to
delete wholesale (no lane-specific sources inside).
