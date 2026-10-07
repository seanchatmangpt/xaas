# W970b — OPEN-row sweep (3 cheap repairs), receipt

- **Lane**: W970b, v26.10.6 campaign, `/Users/sac/xaas` @ `feat/playwright-surface`.
- **Subject**: work performed on tree at ~HEAD `a0723bf6` (dirty tree); by verification time
  the integration lane had committed my repairs as `b2758300` ("W969c SPEC-21 route create +
  W970b hold checkout/retention/castle link") and HEAD had moved to `6f235905` — the final
  green ×2 runs and mutation runs were re-verified at `6f235905` with the repairs on tree.
- **Nothing committed by this lane.** The landing commit `b2758300` was made by the
  integration lane, not W970b.

## Rows repaired (3 of 25 OPEN)

### 1. W770 "no transition path: RouteProjectsBackups lacks :update/:destroy (no retention sweep)" → REPAIRED

- `lib/xaas/platform/validations/route_projects_backups_retain_until_passed.ex` (new):
  fail-closed typed validation — a backup may be pruned only once its own `retain_until`
  has passed; absent deadline refuses.
- `lib/xaas/platform/route_projects_backups.ex`: new `destroy :purge_expired` (accept([]),
  validation wired), `delete(:purge_expired)` json_api route, `bypass action(:purge_expired)`
  gated by `ActorOrgMatches` (cross-org purge → Forbidden). A bare generic `:update`/`:destroy`
  stays deliberately absent (status transitions remain unimplemented by design).
- Court: `platform_route_deepening_test.exs` (4c) — future `retain_until` → typed refusal
  with row surviving on disk; cross-org → Forbidden; expired → real destroy, row gone
  (asserted `{:error, NotFound}` on re-get).
- **Mutation**: unwiring the validate line → 19/20 with exactly (4c) RED; restored
  byte-identical.

### 2. W793 GAP(NO_CROSS_REFERENCE) → REPAIRED

- `priv/repo/migrations/20261007240000_add_castle_run_id_to_incidents.exs` (new): nullable
  `castle_run_id` uuid column + index on `incidents`.
- `lib/xaas/operations/incident.ex`: `belongs_to :castle_run → Xaas.Operations.RouteCastleRun`
  (nullable, public, writable), `:castle_run_id` added to `:update` accept.
- The four route-castle ledgers stay untouched read-only projections (link is
  Incident-owned, one-directional) — the ledger-side refutes in the old pin test still hold.
- Tests: the W793 pin test flipped to assert the link's presence on the Incident side
  (resource attribute + relationship + real `:update` accept), plus a court proving
  `castle_run_id` is really settable through `:update` and persists (read-back).
- **Mutation**: unwiring relationship + accept → compile-level kill (type check
  "unknown key :castle_run_id for struct Incident"); RED, but honest disclosure: this is a
  compile-level kill, not a behavioral RED court.

### 3. W796-G3 "fulfilled hold mints no real Checkout row; hand-off implicit" → REPAIRED

- `lib/xaas/library/hold_request.ex` `:fulfill`: second after_action now really mints an
  open `Xaas.Library.Checkout` (`:borrowed`, book/user/school from the hold) in the same
  transaction as the `borrow_copy` inventory decrement; Checkout create failure fails the
  fulfillment and rolls back both.
- Court: `hold_request_test.exs` "fulfills an active hold…" now also asserts the real
  Checkout row (`:borrowed`, school_id match, `returned_at == nil`) exists after fulfill.
- **Mutation**: unwiring the minting change → 11/12 with exactly the fulfill court RED;
  restored byte-identical.

## Skipped rows (with reasons)

- **W765 GAP-D (FreezeWindow runtime consumer gates)**: started as this lane's third
  repair; discovered mid-flight that DESIGN lane W969c/SPEC-18 had already wired
  `FreezeWindowActive` on `ApprovalEnvironmentPromote :approve` — I deleted my duplicate
  validation module and ceded the row to W969c. (W801 already covered the audit-export
  path.) Do not double-register.
- **W799 / W750-G2 / W824 / W731**: surface files (`ledger/transfer.ex`,
  `capability_liveness_receipt.ex`, `execution_fabric_controller.ex`, graphlaw catalog)
  had mtimes < 30 min from other lanes — skipped per dispatch contract.
- **W804**: operator action on the dev DB, not a lane-safe code repair.
- **W784 TOFU, W819 graphql ×2, W849 backlog-2 (CI leg), W902 environmental, W722 gap-2,
  W729 multitenancy/atomic_update**: non-cheap for this lane — disclosed, not attempted.

## Verification (real tails, all on `_build-laneW970b`)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW970b \
    mix test test/xaas/platform/platform_route_deepening_test.exs \
             test/xaas/operations/incident_lifecycle_deepening_test.exs \
             test/xaas/operations/incident_test.exs \
             test/xaas/library/hold_request_test.exs \
             test/xaas/library/return_fulsills_hold_test.exs
→ (typo guard: return_fulfills_hold_test.exs)
```

Actual consecutive runs:

```
=== PASS 1 ===
Result: 65 passed
=== PASS 2 ===
Result: 65 passed
```

(first pass-1 attempt was 64/65 — my own test's final assertion used `Ash.get` wrong;
fixed to assert `{:error, NotFound}`; rerun green before mutations.)

Mutation runs:

```
MUT1 (purge validation unwired):        Result: 19/20 — exactly (4c) RED
MUT2 (castle link unwired):             compile-level kill (type check: unknown key :castle_run_id)
MUT3 (hold checkout mint unwired):      Result: 11/12 — exactly the fulfill court RED
```

## Standing

- **ALIVE** (row 1, row 2, row 3): repairs observed executing green ×2 on the exact tree,
  mutation-killed courts, restored byte-identical (mutations were sed/perl restores from
  /tmp copies taken before mutating).
- **PARTIAL_ALIVE honesty boundary**: `route_projects_backups_retain_until_passed.ex` was
  extended by another lane (W981d, atomic/3 bulk-destroy branch) after my landing; my
  two green passes cover the combined tree, so the row stands on the combined subject.
- Concurrent-edit witness: W969c appended to `platform_route_deepening_test.exs`
  mid-lane; both lanes' tests coexist green in the same file.

## Cleanup

`_build-laneW970b` deletion was attempted and DENIED by the permission system; left in
place as a lease for the coordinator per the same-checkout fan-out cleanup law.

## Replay

```
cd /Users/sac/xaas && git rev-parse HEAD   # 6f235905 (verify >= b2758300 for the repairs)
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW970b \
  mix test test/xaas/platform/platform_route_deepening_test.exs \
           test/xaas/operations/incident_lifecycle_deepening_test.exs \
           test/xaas/operations/incident_test.exs \
           test/xaas/library/hold_request_test.exs \
           test/xaas/library/return_fulfills_hold_test.exs
# expect: 65 passed, twice consecutively
```
