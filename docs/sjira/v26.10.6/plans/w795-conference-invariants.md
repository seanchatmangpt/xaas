# W795 — Conference Invariants (receipt)

- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface` HEAD `a0723bf6` (uncommitted lane; no commit per lane contract)
- **Lane**: W795, v26.10.6 campaign.
- **Standing**: ALIVE (witnessed execution on the exact subject, 11/11 passing ×2).

## Before (W715, docs/sjira/v26.10.6/plans/w715-conference-deepening.md)

Three typed `UNSUPPORTED` gaps, each pinned by an "honest gap" court in
`test/xaas/conference_deepening_test.exs`:

1. `UNSUPPORTED(transition-guard)` — Registration `status` accepted any
   one_of member → any one_of member on `:update` (e.g. `:attended → :registered`).
2. `UNSUPPORTED(capacity-invariant)` — no capacity field, no attendance ceiling;
   5 registrations on one session all accepted.
3. `UNSUPPORTED(referential-integrity)` — bare uuid attrs, no FK enforcement;
   dangling `attendee_id`/`session_id` stored without refusal.

## What was done (μ/diff)

Read `lib/xaas/conference.ex` + 7 resources; landed the three invariants in the
house idioms:

1. **Forward-only transition guard** — `Xaas.Conference.Validations.RegistrationStatusTransition`
   (in `lib/xaas/conference/registration.ex`), W772/W740 idiom
   (mirror: `Xaas.A2a.Validations.ForwardOnlyTransition`). Allowed edges:
   `registered→cancelled`, `registered→attended`, `cancelled→attended`, plus
   every self-transition; `:attended` is terminal. Wired on Registration `:update`.
2. **Session capacity** — `Session.capacity` `:integer`, `constraints(min: 1)`,
   `allow_nil? true` (nil = unlimited, backward compatible), added to the
   create accept list (`lib/xaas/conference/session.ex`). Ets-backed, so no
   migration was needed — tables are per-runtime private, created from the
   current schema. Enforced on Registration create by
   `Xaas.Conference.Changes.EnforceSessionCapacity`
   (counts existing registrations for the session, refuses at ceiling, typed
   `InvalidChanges`).
3. **Referential integrity** — `Xaas.Conference.Changes.ResolveRegistrationRefs`:
   real `Ash.get` resolve of `attendee_id`/`session_id` on Registration
   create; dangling id → typed `InvalidChanges`, nothing written.

## Courts (test/xaas/conference_deepening_test.exs)

- 3 gap-pinning tests converted to the corrected contract:
  - "honest gap: cancelled→attended→registered accepted" → "invariant: forward edges admitted, backward edge refused" (+ separate self-transition court).
  - "honest gap: dangling refs accepted" → "invariant: dangling refs refused on create" (asserts zero rows written).
  - "honest finding: no capacity invariant" → "invariant: capacity enforced at ceiling; nil stays unlimited" (+ positive-integer court).
- Each conversion carries an inline mutation rationale (what edit would make
  the court vacuous), W715's (a)/(b)/(d) courts untouched.

## Commands + exits (real tails)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW795 \
  mix test test/xaas/conference_deepening_test.exs
# run 1 (first wiring attempt: create-time pieces were wired with validate/1
# instead of change/1 → Ash called has_validate?/0 on the change modules,
# 2/11 passed, 9 failed) — repaired to change/1, rerun:
# run 2: 10/11 passed, 1 failed (my own test bug: a second seed() inside the
#        capacity court collided on unique slugs) — restructured to one seed,
# run 3: 11 passed
# run 4 (confirmation):
...........
Finished in 0.8 seconds (0.00s async, 0.8s sync)
Result: 11 passed
[exited with code 0]
```

11/11 green ×2 (runs 3 and 4, warm build). Default ExUnit tag exclusions apply
(`:stress`, `:eu_ai_act`, etc.); none apply to this file.

## Files written

- `lib/xaas/conference/registration.ex` — 3 new modules
  (`RegistrationStatusTransition` validation,
  `ResolveRegistrationRefs` + `EnforceSessionCapacity` changes) wired into
  `:create`/`:update`.
- `lib/xaas/conference/session.ex` — `capacity` attribute (`:integer`,
  `constraints(min: 1)`, nil = unlimited) + create accept.
- `test/xaas/conference_deepening_test.exs` — extended only (9 W715 courts
  preserved, 3 gap-pinners converted, new self-transition + capacity-shape
  courts).
- This receipt.

## Falsifiers

Re-run `mix test test/xaas/conference_deepening_test.exs` on the exact head:
green 11/11 means the invariants hold; a red run on any invariant court is
the refutation. Each court carries an inline mutation rationale naming the
exact deletion that would make it vacuous.

## Cleanup

`_build-laneW795` LEFT IN PLACE for coordinator — `rm -rf` was refused by the
permission system in this lane (same as W715). It is a pure build artifact;
safe to delete wholesale (no lane-specific sources inside).
