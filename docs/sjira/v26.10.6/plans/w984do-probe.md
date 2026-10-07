# W984do — burn-down continuation probe (conference terminal-cancel family)

Lane: W984do, xaas v26.10.6 campaign, branch `feat/playwright-surface`.
Not committed (per lane contract); build root `_build-laneW984do` LEFT FOR
COORDINATOR DELETION — this lane's `rm -rf` of it was permission-denied
(~430 MB, MIX_ENV=test, disposable).

## Census (fresh, CamelCase-aware)

Python census over `lib/xaas`: every `defmodule` name checked against all
`test/**.exs` sources three ways (short CamelCase, snake_case of the short
name, full-path snake). Results:

- 882 modules defined, **171 uncovered** (19.4%).
- Family 1, GraphQL-era remainder: **zero** `graphql`-named files/modules in
  `lib/` — the surface no longer exists. Typed disposition: EXHAUSTED
  (surface-absent). Nothing to court.
- Family 2, Wasmex-adjacent test/support residue: `test/support/graphlaw_spin_guest.rs`
  is referenced by the landed `test/xaas/semantics/graphlaw_wasm_test.exs` —
  not residue, ACTIVE. Typed disposition: RETAIN (witnessed firing).
- Census-ranked top state-bearing uncovered module:
  `Xaas.Conference.Validations.RegistrationTerminalCancelGuard`
  (lib/xaas/conference/registration.ex, guard + `:cancel` action), 328-line
  file, second-largest uncovered defmodule in the census and the largest that
  is state-bearing (guards the `Registration.status` terminal-state
  invariant on a named product action).

## Court

`test/xaas/conference/registration_terminal_cancel_guard_court_w984do_test.exs`
— 5 tests, Chicago-style (real ETS tables, real Ash actions, real persisted
state, no mocks). Per-test mutation rationale (documented in the moduledoc):

1. cancel-of-`:cancelled` refused, typed `InvalidChanges`, nothing written —
   kills guard-removal mutant.
2. cancel-of-`:attended` refused — kills `terminal_statuses` narrowed to
   `[:cancelled]` mutant.
3. `:cancel` of active registration succeeds and persists — kills
   over-wide guard mutant (refuse-all).
4. bare `:update` self-transition on terminal row still admitted — kills
   guard-moved-to-`:update` mutant (W973b scope is `:cancel`-specific).
5. re-register-after-cancel, cancel the new row — kills guard-reads-params
   mutant (guard must read persisted `get_data`, not changeset params).

## Verification (real output)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984do \
  mix test test/xaas/conference/registration_terminal_cancel_guard_court_w984do_test.exs
Running ExUnit with seed: 89418, max_cases: 32
.....
Finished in 0.7 seconds
Result: 5 passed
```

Zero compile warnings from the new file. Earlier red runs (fix-forward, no
reset): pin-operator compile error (missing `require Ash.Query` — replaced
with `Ash.get!`), wrong error struct (`Ash.Error.Invalid.Errors` →
`Ash.Error.Invalid`), Session/Track/Speaker/Event required-attr chain in the
seed helpers.

## Dispositions

| family | disposition |
|---|---|
| GraphQL-era remainder | EXHAUSTED (no graphql surface in lib/) |
| Wasmex test/support residue | RETAIN (active witness of graphlaw_wasm court) |
| Conference terminal-cancel family | COURT LANDED, 5/5 ALIVE |

## Standing

PARTIAL_ALIVE for the burn-down stream: the targeted module moved
uncovered→covered (census 171→170 uncovered of 882), two census families
typed-dispositioned. Remaining census backlog (171→170) passes to the
coordinator; next-ranked candidates: `Xaas.Conference.Validations.RegistrationStatusTransition`
(already named in deepening courts but not module-named), DurableAdapter
(lib/xaas/bridges/pplan.ex, 411 lines), GitHubActions project_measure module.
