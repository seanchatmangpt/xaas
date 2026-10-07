# W981s — GAP(same-attendee-re-register-blocked-by-identity) REPAIR receipt

- **Lane**: W981s, xaas v26.10.6, branch `feat/playwright-surface` (shared canonical checkout, no commit — coordinator owns integration)
- **Date**: 2026-10-07
- **Subject**: `lib/xaas/conference/registration.ex` + appended court in `test/xaas/conference/enrollment_journey_court_test.exs`; gap-register row added in `docs/sjira/v26.10.6/plans/w859-typed-gap-register.md`
- **Disclosing receipt**: `w969e-journey-legal.md` step-6 probe (A's re-register refused "has already been taken" while slot FREE)

## Before (measured, run 1 baseline)

`unique_attendee_session` was `identity(:unique_attendee_session, [:attendee_id, :session_id], pre_check_with: Ash.DataLayer.Ets)` — no status scope. A CANCELLED registration permanently consumed the (attendee_id, session_id) identity: cancelled A could never re-register into the same session, even with a free slot (W969e step 6 measured the refusal).

## After

1. Identity re-declared with the Ash identity `where` option (syntax read from `deps/ash/lib/ash/resource/identity.ex:43-47`; not guessed):

```elixir
identity(:unique_attendee_session, [:attendee_id, :session_id],
  where: expr(status in [:registered, :attended])
)
```

(no `pre_check_with` anymore)

2. MEASURED ash 3.34.4 boundary: the `pre_check_with` path — `Ash.Changeset.do_validate_identity/3` (`deps/ash/lib/ash/changeset/changeset.ex:3313-3389`) — does **not** apply `identity.where`: it filters only on the identity keys, so the unscoped pre-check would keep refusing cancelled attendees. The scoped form IS honored on the ETS **upsert** path (`deps/ash/lib/ash/data_layer/ets/ets.ex:1536-1542`). Because ETS enforces no constraint at plain-create time without the pre-check, the scoped enforcement is landed as an explicit before_action change:

`Xaas.Conference.Changes.EnforceActiveRegistrationIdentity` — wired on `:create` between `ResolveRegistrationRefs` and `EnforceSessionCapacity`; refuses an active (`:registered`/`:attended`, statuses sourced from `EnforceSessionCapacity.active_statuses` semantics) same-(attendee, session) row with `fields: [:attendee_id, :session_id], message: "has already been taken"` (same error class as the pre-check used). Statuses re-declared locally as `@active_statuses [:registered, :attended]`, deliberately parallel to `EnforceSessionCapacity` (single definition not shared, to avoid touching the capacity module).

## Court (appended, existing tests untouched)

`test/xaas/conference/enrollment_journey_court_test.exs` — test "W981s: cancelled attendee re-registers into the same session (slot free) and an active duplicate is still refused": unlimited-capacity session (capacity ceiling fires before the identity on a capacity-1 session and would mask the identity refusal), full inline seed; asserts (a) active A+A duplicate refused "has already been taken", (b) B coexists, B duplicate refused, (c) A cancels → re-registers SUCCESSFULLY (the repair), (d) cancel/re-register cycles a third time, (e) determinism: 2 active + 2 cancelled, 4 rows.

## Commands / exits

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW981s mix compile    # exit 0
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW981s \
  mix test test/xaas/conference/enrollment_journey_court_test.exs                        # ×2 stable
```

Final runs ×2 (identical): `Result: 3/5 passed, Failed: 2 tests` —

- **RED #1 (pre-existing, not mine)**: "W973b terminal guard: a cancelled registration cannot :cancel again" — the documented intentional RED falsifier (self-`:cancel` admitted; "do not soften" note in the test). Unrelated to this change (update-path, not create-path). Session-introduced? No.
- **RED #2 (expected behavior flip)**: "W969e legal walk …" step 6 asserts the GAP behavior itself (cancelled A's re-register is a refusal). With the repair, that re-register succeeds, so its `assert_raise` is RED. This is the GAP-closing transition the W969e receipt itself named ("product-side close: scoped identity or explicit re-open action"); that leg needs a coordinator-owned flip to a success assert at integration. **Do not treat this RED as a regression.**

## Falsifier / mutation

Drop `EnforceActiveRegistrationIdentity` from `:create` (or widen its filter to all statuses): court goes RED — re-register refused "has already been taken" (unscoped) or active double-book admitted. Comment on the change and in the court documents this.

## GAP disposition

Row added by this lane to `docs/sjira/v26.10.6/plans/w859-typed-gap-register.md` as **REPAIRED**, citing this receipt; REPAIRED total 31 → 32 (row was absent before; added per dispatch, register's existing rows untouched).

## Boundary notes for the coordinator

- One out-of-lane minimal fix under the compile-freeze SLA, disclosed: `lib/xaas/generated/regen_check.ex` (untracked, written corrupted by another lane with a stray `sharing_off` line at :234 causing TokenMissingError for every mix test run) — removed the stray line only.
- Lane build root `_build-laneW981s` left in place for the coordinator (not deleted).
- No commit, per dispatch.
