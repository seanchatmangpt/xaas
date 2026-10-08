# W984gg — unclaimed-family probe: conference/booking domain

Lane W984gg on /Users/sac/xaas @ feat/playwright-surface (4eba5a44). Read-only over lib;
one new test file; no commit (per dispatch).

## Census

Conference family = `lib/xaas/conference.ex` + 7 resources under
`lib/xaas/conference/{event,track,session,speaker,sponsor,attendee,registration}.ex`
(718 lines total). Existing test holders (CamelCase grep against test/):

| module | holders | disposition |
|---|---|---|
| Conference (domain) | 7 conference test files | COVERED (domain module, no state) |
| Event | conference courts + deepening (sibling-modified, read-only) | COVERED (create/identity/destroy; lifecycle courts W984dn) |
| Track | same set | COVERED (W984dn tests 4/5: event_id required, unique_slug, dangling destroy) |
| Session | same set | COVERED (W984dm tests 3/4/5: capacity attribute, unique_slug, non-cascading destroy) |
| Speaker | same set | COVERED (create/identity via W984dm/W984dn helpers; no dedicated states) — indirectly-covered |
| Sponsor | conference_test, W984dn court, deepening | COVERED (tier one_of, unique_slug, tier counting) |
| Attendee | same set | COVERED (unique_email, lifecycle, destroy) |
| Registration | 5 courts + deepening | COVERED in the large; **partially uncovered state-bearing family found** (below) |

## Finding

`EnforceSessionCapacity` and `EnforceActiveRegistrationIdentity`
(lib/xaas/conference/registration.ex) both define
`@active_statuses [:registered, :attended]` — but every existing court exercises those guards with
`:registered`-holder rows only. The `:create` action accepts `:status`, so a
directly-`:attended` registration is a real reachable state with zero witnessed
behavior around its guard interaction:

- attended holder consuming a capacity slot: unwitnessed
- attended same-(attendee, session) duplicate refusal: unwitnessed
- interlock of the terminal-cancel guard with an attended slot-holder: unwitnessed
  (W984do held the terminal guard via bare update-walk rows, never against a
  capacity-bearing :attended row)

## Court

`test/xaas/conference/family_court_w984gg_test.exs` — 3 tests, real Ash actions over
real ETS tables, zero mocks, mutation rationale per test, fresh-root wipe per test.

1. `:attended` holder consumes a capacity-1 slot; later `:registered` create refused
   "at capacity (1/1 taken)", nothing persisted.
2. `:attended` same-(attendee, session) duplicate refused "has already been taken"
   (EnforceActiveRegistrationIdentity, `:attended` counted active).
3. Guards interlock: cancel-of-`:attended` refused by RegistrationTerminalCancelGuard
   ("cannot cancel a terminal registration... :attended") even though the row holds a
   capacity slot; slot stays consumed.

## Gates (real output)

```
MIX_BUILD_ROOT=_build-laneW984gg mix test test/xaas/conference/family_court_w984gg_test.exs
→ 3 passed, exit 0 (initial run + post-warning-fix rerun, both 3 passed)
MIX_BUILD_ROOT=_build-laneW8984gg mix run scan_mock_usage(["test","lib"]) → []  (mock gate)
```

(May note: heavy concurrent lane load; cold lane compile took ~18 min wall.)

## Dispositions

- COVERED: Conference domain, Event, Track, Session, Sponsor, Attendee
- INDIRECTLY-COVERED: Speaker (helpers only, no dedicated state test)
- UNCOVERED → held here: Registration `:attended`-holder guard family (3 branches)
- Sibling-modified `test/xaas/conference_deepening_test.exs` read-only, untouched.
