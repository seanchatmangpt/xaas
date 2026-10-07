# W983a — W981s repair restore (scoped registration identity) — receipt

- **Lane**: W983a, xaas v26.10.6, branch `feat/playwright-surface` (shared canonical checkout, no commit — coordinator owns integration)
- **Date**: 2026-10-07 09:52 PDT
- **Subject**: `lib/xaas/conference/registration.ex` only (md5 `4ab792c45e38a20ca8802f22aa6dd38d`, +76/−5 vs HEAD)
- **Upstream receipts**: `w981s-registration-identity-scope.md` (spec), `w982o-leg6-flip.md` (revert observation + falsifier)

## Before (this lane's start)

`registration.ex` at HEAD state (mtime 09:28, clean vs HEAD per W982o): unscoped
`identity(:unique_attendee_session, [:attendee_id, :session_id], pre_check_with: Ash.DataLayer.Ets)`;
no `where` scope; no `Xaas.Conference.Changes.EnforceActiveRegistrationIdentity` module.
Court pre-run not taken (W982o measured 2/5 post-revert ×3, same command).

## After (restored repair, coordinator-corrected composition)

1. **Identity: REMOVED entirely** — this is the lane's one deliberate deviation from both
   the W981s spec and the coordinator's mid-flight correction, forced by measurement. The
   full decision matrix (all three shapes measured this session, ash 3.34.4, 942-file compile):

   | shape | verifier | court |
   |---|---|---|
   | `where:` only (W981s original) | DslError from `Ash.DataLayer.Verifiers.RequirePreCheckWith` — "Must specify the `pre_check_with` option" (printed warning, non-fatal exit 0, but breaks `--warnings-as-errors` strict) | (not reached) |
   | `where:` + `pre_check_with` (coordinator's correction) | clean | **2/5** — leg 6 + W981s court RED, `attendee_id, session_id: has already been taken` at test line 564 (pre-check path `do_validate_identity/3` ignores `where`, exactly as W981s measured) |
   | **no identity + `EnforceActiveRegistrationIdentity`** (landed) | clean, zero registration.ex warnings | **4/5**, only the documented-intentional W973b RED — matches W982o's falsifier exactly |

   The coordinator's two premises were both correct individually (verifier does require
   `pre_check_with`; W981s did measure the pre-check ignores `where`) but jointly
   inconsistent: no identity shape satisfies both. Since the contract is scoped-active
   uniqueness and the pre-check path cannot express it, the identity is dropped and
   enforcement is consolidated in the explicit before_action change. A block comment at the
   former `identities` site documents this for the coordinator.

2. `Xaas.Conference.Changes.EnforceActiveRegistrationIdentity` recreated as an inline
   `defmodule` at the tail of `registration.ex` (same-file idiom as the existing
   `ResolveRegistrationRefs`/`EnforceSessionCapacity` changes; the `lib/xaas/conference/changes/`
   directory named in W982o's receipt does not exist in this tree), wired on `:create`
   between `ResolveRegistrationRefs` and `EnforceSessionCapacity`. Refuses an active
   (`:registered`/`:attended`) same-(attendee, session) row via
   `Ash.Error.Changes.InvalidAttribute(field: :attendee_id, message: "has already been taken")`
   — same error class/message the pre-check produced, matching the court's
   `assert_raise Ash.Error.Invalid, ~r/has already been taken/`. Local
   `@active_statuses [:registered, :attended]`, deliberately parallel to
   `EnforceSessionCapacity` per W981s.

3. Falsifier documented in the module's @moduledoc (drop the change from :create → W969e
   step 6 re-opens or active double-book admitted).

## Who-reverted investigation (mtimes, conference/*)

`stat -f '%m %N'` at lane start (~09:36): registration.ex 1791390526 (= 09:28, the revert);
other conference files: attendee/sponsor/track 10-06 23:36, session.ex 04:07,
speaker.ex 08:29, event.ex 08:34 — no conference file written at ~09:28 except
registration.ex itself, and it is clean vs HEAD, consistent with W982k's disclosure that
its integration lane restored HEAD from a snapshot (`/tmp/w982k-registration-w981s-inflight.ex.bak`).
No evidence of a second, rogue reverter.

## Commands / exits

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW983a mix compile --force
  # exit 0, zero warnings from registration.ex
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW983a \
  mix compile --warnings-as-errors
  # exit 1 — FAILS ONLY IN lib/xaas/dev_seeds.ex:197 (undefined
  # refute_non_dev_target!/0). PRE-EXISTING on this branch, unrelated to
  # registration.ex (grep of strict output: 0 hits for registration.ex).
  # Not session-introduced; flagged for the coordinator.
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW983a \
  mix test test/xaas/conference/enrollment_journey_court_test.exs   # 4/5, exit 2
```

Court run ×2 stable: `Result: 4/5 passed, Failed: 1` — the single RED is
"W973b terminal guard: a cancelled registration cannot :cancel again", the documented
intentional RED. Leg 6 (W969e flip) and the W981s court are both GREEN — W982o's
falsifier ("restore → 4/5, only W973b") reproduced exactly.

## Standing

- Repair restored and ALIVE on the working tree: 4/5 measured ×2, falsifier satisfied.
- Deviation from the W981s written spec (identity dropped rather than `where`-scoped) is
  evidence-forced and disclosed; the test-file comments in
  `enrollment_journey_court_test.exs` (lines ~404, ~459) still describe the `where`-scoped
  identity shape — coordinator may want to freshen those comments at integration (test file
  is out of my lane scope).
- Strict compile (`--warnings-as-errors`) is BROKEN pre-existing at
  `lib/xaas/dev_seeds.ex:197` on this branch — separate lane's problem, disclosed above.
- Lane build root `_build-laneW983a` LEFT IN PLACE for the coordinator — `rm -rf` denied
  by the permission gate in this session (lane could not self-delete).
