# W733 — Marketplace Deepening Receipt

- **Lane**: W733, v26.10.6 campaign
- **Subject**: `/Users/sac/xaas` @ branch `feat/playwright-surface`, HEAD `a0723bf6` (uncommitted new file only)
- **Standing**: **ALIVE** (observed execution, 17/17 real tests, real sandboxed Postgres, no mocks)
- **Lane lease**: `MIX_BUILD_ROOT=_build-laneW733` — `rm -rf` was denied by session permissions; **left on disk for coordinator cleanup** (same-checkout fanout cleanup law).

## Files written (2)

1. `test/xaas/marketplace_deepening_test.exs` (new) — the court.
2. This receipt.

No lib/ code touched. Nothing committed (per lane contract).

## What the court proves (Chicago-style, real Ash actions, real rows)

- **(a) Lifecycle read surface**: `:create` persists with the real `:pending`
  default; `:create` cannot smuggle `:status` (non-accepted input ->
  `Ash.Error.Invalid`); authorized `:read` with a `%{org_id: ...}` actor
  resolves same-org rows; `:update` accepts only name/description — passing
  `:status` is rejected (`Invalid`), a legal metadata-only update lands and
  status stays `:pending` (asserted on re-read).
- **(b) Fencing invariant**: `:actuate_status` refuses
  (`Ash.Error.Invalid` from `Xaas.Actuation.Validations.ReactorContext`)
  **even with `authorize?: false`** and with a policy-passing org actor; a
  bare changeset with the Reactor-context shape (same one the existing
  tests use) is admitted at the action layer and really persists
  `:active` — proving the fence is the context validation, not the policy
  layer. No `Xaas.Actuation.run/4` invocation anywhere in this file
  (consequential-DO discipline: refusals tested, not actuation).
- **(c) Multitenancy (policy filter semantics, not Ash multitenancy)**:
  org A's actor gets `{:ok, nil}` from `read_first` on org B's row;
  org A's authorized index contains exactly its own rows; cross-org
  `:update` and cross-org `:create` (forged `org_id`) yield typed
  `Ash.Error.Forbidden` (the `ActorOrgFilter` check is `:unknown` at
  strict-check time on a foreign row); forged rows were not created and
  foreign rows not mutated (asserted via `authorize?: false` re-read).
- **(d) Maker-checker refusals** on `ApprovalProviderStatusChange`:
  `:create` persists a real pending request readable by its own org;
  cross-org `provider_id` refuses (`:provider_id` field error,
  `ApprovalProviderStatusChangeProviderOrgMatches`); dangling `provider_id`
  refuses fail-closed; `:approve` refuses empty `approved_by` and
  self-approval (`ApprovalProviderStatusChangeRequiresApprover`, field
  `:approved_by`); foreign-org `:approve` is row-filtered
  (`{:error, _}`). Every refusal test asserts the target `Provider.status`
  is still `:pending` afterwards — zero DO leaked through any refusal.

## Real command + actual output

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW733 \
  mix test test/xaas/marketplace_deepening_test.exs
...
................. (17 dots)
Finished in 0.7 seconds (0.7s async, 0.00s sync)
Result: 17 passed
```

Final rerun after the fix round: `17 passed`, exit 0. (First run: 13/17;
4 assertion-shape failures — pinned-struct pattern, `Forbidden` vs
`Invalid` on filter-check refusals, unknown-input rejection on
`:status` — all repaired forward, no production code changed.)

## Typed gaps

- **UNKNOWN (integration edge, out of scope by contract)**: the successful
  `:approve` -> `Xaas.Actuation.run/4` receipt path is NOT witnessed by
  this lane (deliberately — refusals only). Covered elsewhere by the
  approval stress tests / actuation courts.
- **UNKNOWN**: pre-existing ambient noise observed but not owned by this
  lane: Grafana/PromEx `nxdomain` upload warnings, AshA2A
  `receipt_store_in_memory` legacy-compat warnings, `autofde` not on PATH.
- Pre-existing failures elsewhere in the suite: not run (lane scope is the
  single file), not claimed either way.
