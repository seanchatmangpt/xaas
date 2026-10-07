# W982o — W969e legal-walk leg 6 flip (slot cycling now legal) — receipt

- **Lane**: W982o, xaas v26.10.6, branch `feat/playwright-surface` (shared canonical checkout, no commit — coordinator owns integration)
- **Date**: 2026-10-07
- **Subject**: `test/xaas/conference/enrollment_journey_court_test.exs` only (W969e legal walk, leg 6 flip)
- **Upstream receipts**: `w981s-registration-identity-scope.md` (repair), `w969e-journey-legal.md` (pre-named flip: "product-side close: scoped identity")

## Before (leg 6, as measured by W969e)

```elixir
# --- step 6: typed observation of the same-attendee gap, probed while
#     the slot is FREE: A's re-registration is refused by
#     unique_attendee_session (no status scope) even though capacity
#     would admit (GAP(same-attendee-re-register-blocked-by-identity),
#     product-side close: scoped identity or explicit re-open action).
#     The task-spec step 6 "A re-registers succeeds" is REFUTED by this
#     measurement; the second slot release is witnessed instead by
#     attendee C at step 7. ---
assert_raise Ash.Error.Invalid,
             ~r/has already been taken/,
             fn ->
               register(attendee_a.id, session.id)
             end
```

plus attendee C's slot-witness at step 7 and a 3-row / 1-active determinism block
(active row = C's), all downstream of the asserted GAP refusal.

## After (leg 6, this lane)

```elixir
# --- step 6: A re-registers into the released slot — SUCCEEDS.
#     Repair of GAP(same-attendee-re-register-blocked-by-identity):
#     unique_attendee_session is now status-scoped
#     (where: expr(status in [:registered, :attended])) with
#     EnforceActive-only enforcement on :create, so a CANCELLED
#     row no longer consumes the (attendee_id, session_id) identity
#     and a previously-cancelled attendee legally re-registers
#     (W981s receipt; W969e receipt pre-named this flip:
#     "product-side close: scoped identity"). ---
reg_a2 = register(attendee_a.id, session.id)
assert reg_a2.status == :registered
assert reg_a2.id != reg_a1.id
assert reg_a2.id != reg_b.id
```

Downstream restructured: step 7 (attendee C slot-witness) removed — with capacity 1
A's successful re-register occupies the slot, so C would now hit the capacity
ceiling; A's new row is itself the slot-cycling witness. Determinism block now
asserts: 1 active (A's new row `reg_a2`), 2 cancelled (A1, B), 3 rows total, and
that capacity-1 was never double-booked. W973b's terminal-guard leg untouched
(documented intentional RED).

## CRITICAL FINDING — repair reverted from tree mid-lane

**The W981s repair is NOT in the working tree at completion of this lane.** Timeline
(real mtimes + run results, all 2026-10-07):

- 09:06 — test file freshened (W982a/W981s-era state); run 1 (started ~09:19) with the
  repair present: **4/5**, only W973b intentional RED. Leg-6 flip PASSED against the
  repaired product code.
- 09:28 — `lib/xaas/conference/registration.ex` mtime; on inspection it is back to the
  **unscoped** `identity(:unique_attendee_session, [:attendee_id, :session_id], pre_check_with: Ash.DataLayer.Ets)`
  and is **clean vs HEAD** (`git status` shows it unmodified). The scoped `where:` and the
  `Xaas.Conference.Changes.EnforceActiveRegistrationIdentity` module (grep across `lib/`+`test/`:
  only my comment references it) are **gone**. Not done by this lane — W982o wrote only the
  test file. Some other actor on the shared checkout reverted the W981s working-tree repair
  (it was never committed; HEAD never contained it).
- Runs 4 and 5 (post-revert, ×2): **2/5** each, identical failure class — leg 6 and the
  W981s court both RED with `attendee_id, session_id: has already been taken` (the
  unscoped identity refusing the cancelled attendee), plus W973b's intentional RED.

## Standing

- Leg-6 flip itself: **VERIFIED-then-BLOCKED**. VERIFIED against the repaired tree (run 1,
  4/5, flip green); BLOCKED at completion because the repair it asserts is no longer in the
  tree. The test now correctly encodes the W981s-repaired contract; with the repair restored
  it is expected 4/5 (only W973b RED).
- W973b terminal guard: untouched, still intentional RED by design.

## Commands / exits

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW982o \
  mix test test/xaas/conference/enrollment_journey_court_test.exs   # ×5 total
```

- Run 1 (repair present): `Result: 4/5 passed, Failed: 1` — only W973b. exit 0.
- Run 2 (09:2x, repair being reverted mid-run): `Result: 2/5 passed, Failed: 3`.
- Run 3 (full capture): 2/5 — W969e leg 6 + W981s court `has already been taken` (line 411
  / 564), W973b intentional.
- Run 4: `Result: 2/5 passed` — same three failures (W973b + leg 6 + W981s).
- Run 5: `Result: 2/5 passed` — same three failures. Stable post-revert.
- Full tails: `/tmp/w982o-run3.txt`, `/tmp/w982o-run4.txt`, `/tmp/w982o-run5.txt`.

## Falsifier

With the W981s repair restored (scoped identity + EnforceActiveRegistrationIdentity),
`mix test test/xaas/conference/enrollment_journey_court_test.exs` → 4/5 (only W973b RED).
Measured as run 1 of this lane. With the repair absent (current tree), the same command →
2/5 with `has already been taken` on the re-register legs. Either state reproduces.

## Boundary notes for the coordinator

- W982o wrote only the test file + this receipt. No product code touched, no commit.
- **Action needed**: restore W981s's repair to `lib/xaas/conference/registration.ex`
  (scoped identity `where: expr(status in [:registered, :attended])`, no `pre_check_with`)
  and recreate `lib/xaas/conference/changes/enforce_active_registration_identity.ex`
  (wired on `:create` between `ResolveRegistrationRefs` and `EnforceSessionCapacity`) —
  full spec in `docs/sjira/v26.10.6/plans/w981s-registration-identity-scope.md`. It was
  working-tree-only and is now reverted by an unknown actor at ~09:28.
- Who reverted it: not W982o. Check other conference-file lanes (event.ex/speaker.ex were
  also concurrently modified at 08:34/08:29).
- Lane build root `_build-laneW982o` left in place for the coordinator (not deleted).
