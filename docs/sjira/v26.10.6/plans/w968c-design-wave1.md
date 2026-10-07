# W968c — DESIGN wave 1 receipt (SPEC-27 + SPEC-14)

- Lane W968c, xaas v26.10.6, repo `/Users/sac/xaas`, branch `feat/playwright-surface`,
  base HEAD `fc14f10bf68f9bebc5458580afbd2ed61eccee39` (shared tree with concurrent
  lanes; NOT committed per dispatch — coordinator owns transitions/commits).
- Source backlog: `docs/sjira/v26.10.6/plans/w905-design-gap-specs.md` (W905),
  register `docs/sjira/v26.10.6/plans/w859-typed-gap-register.md`.
- Spec selection: chose the 2 M-specs whose surface files were lane-free at dispatch.
  Avoided SPEC-16/17 (already landed, W935 commit fab56ae1), SPEC-07 (billing tree
  in-flight), SPEC-20/21 (route_projects family in-flight), SPEC-24/26 (incident.ex /
  checkout.ex lane activity + CHEAP-wave sequencing preconditions), SPEC-30/31
  (router/mix.exs in-flight).

## SPEC-27 (W799-GAP-1) — dedicated ledger `:reverse` action — M — IMPLEMENTED

Surface (exact):
- `priv/repo/migrations/20261007230000_add_reverses_transfer_id_to_ledger_transfers.exs`
  — nullable `reverses_transfer_id :binary` + partial unique index
  `ledger_transfers_reverses_transfer_id_index` (WHERE NOT NULL).
- `lib/xaas/ledger/transfer.ex` — attribute `reverses_transfer_id`
  (AshDoubleEntry.ULID, public, not accepted by any action — only `:reverse` writes
  it); `create :reverse` (argument `transfer_id`, TransferSourceSufficiency
  validation, change `Xaas.Ledger.Changes.ReverseTransfer`); identity
  `:unique_reversal`.
- `lib/xaas/ledger/changes/reverse_transfer.ex` — reads the original transfer live
  (real-table read, authorize?: false); typed refusals: unknown id ("no such
  transfer", field `:transfer_id`) and already-reversed ("transfer already
  reversed"); mints the compensating transfer with from/to swapped, same amount,
  marking `reverses_transfer_id`. Mechanism remains the w799-disclosed compensating
  round trip; the guards make double-reversal refusal reversal-aware instead of an
  accident of sufficiency.

Spec adaptation (disclosed, not M-growth): spec said `reverses_transfer_id :uuid`;
implemented as `AshDoubleEntry.ULID` to match the resource's `:id` type (column
`:binary`, uuid-formatted ULIDs). Same null + unique semantics, same migration shape.

Court: `test/xaas/ledger/reversal_deepening_test.exs`, new
`describe "W968c SPEC-27 :reverse action"` (4 tests):

1. mints a real compensating transfer, from/to swapped, `reverses_transfer_id` set;
   balances asserted on real rows (org restored to 0, platform +20.00).
2. **mutation-kill leg**: double-reverse refused reversal-aware EVEN WHEN the org is
   re-funded. The pre-existing refusal was an accident of sufficiency (the W799
   disclosure), so the court deliberately funds the org and treasury first; killing
   the `already_reversed?/1` guard admits the second reversal and fails this test
   while every pre-existing sufficiency test still passes.
3. unknown `transfer_id` refuses typed on field `:transfer_id`.
4. the reversal is discoverable by `reverses_transfer_id`; the guard is
   per-original — reversing the reversal is lawful and marked against the reversal.

Real tails: `Result: 9 passed` ×2 consecutive, re-witnessed again in later windows;
final joint run (this suite + the liveness suite, 20 tests) `Result: 20 passed` ×2
consecutive on the final tree state. Real defects found and fixed while landing: (a)
attribute writes in
before_action are refused post-validation — switched to `force_change_attributes/2`
(lawful: values read from a trusted row, documented in-file); (b) **pre-existing
test-helper bug** in this court file: `open_account!/1` returned the account id
string on the already-exists branch (it read via `account_id_for`, which returns
`account.id`), raising BadMapError the moment a test called it twice for the same
identifier — only my multi-seed tests exercised it; fixed in-place to read the real
account row.

## SPEC-14 (W750-G2) — regression-detectable liveness history — M — IMPLEMENTED

Surface (exact):
- `priv/repo/migrations/20261007231000_add_previous_status_to_capability_liveness_receipts.exs`
  — nullable `previous_status :text`.
- `lib/xaas/operations/capability_liveness_receipt.ex` — attribute `previous_status
  :string` (public, nullable, NOT in the `:ingest` accept list); `:ingest` change
  `Xaas.Operations.Changes.SetPreviousStatus`.
- `lib/xaas/operations/changes/set_previous_status.ex` — before_action reads the real
  existing `(capability, subject)` row and captures its status into
  `previous_status` before the identity upsert overwrites the row in place. Caller
  forgery refused typed (`NoSuchInput` naming `:previous_status`).
- `lib/xaas/operations/capability_liveness_regressions.ex` — `detect/1` now checks
  the latest row's `previous_status` for an in-place ALIVE→non-ALIVE regression
  (in-place branch takes precedence; the cross-subject branch is behaviorally
  unchanged).

Court: `test/xaas/operations/capability_liveness_deepening_test.exs`:
- flipped the W750-G2 blindness pin — the refresh-semantics test previously asserted
  `regressions == []` (the pinned blindness); it now asserts detect/1 reports the
  in-place ALIVE→REFUTED regression with was/now same-subject. Visible diff = the pin
  flip.
- new courts: caller-forgery of `previous_status` refused typed; non-ALIVE→non-ALIVE
  in place does not fire; ALIVE→ALIVE does not fire.
- the pre-existing cross-subject court ("fires only for ... distinct subjects") is
  unchanged and green.

Real tails: `Result: 11 passed` ×5 consecutive greens (plus one earlier green); final
joint run (this suite + the reversal suite, 20 tests) `Result: 20 passed` ×2
consecutive on the final tree state. One earlier run, executed amid observed
concurrent-lane compile churn on the shared tree, reported "Failed: 2 tests" with no
captured failure names — disclosed as a single un-diagnosed transient; 5+ subsequent
consecutive 11/11 greens, zero reproductions. Adjacent suites re-witnessed:
capability_liveness_receipt_test 8/8, capability_liveness_receipt_check_regressions_test
3/3, property suite excluded by tag (0 tests, 1 excluded), registry_drift_guard_test 1/1.

## Shared-tree hazards (disclosed; none of these files are W968c's)

Concurrent lanes were observed mid-write broken on the shared tree during this lane:
`lib/xaas/graphlaw/limit_gate.ex` (SPEC-10 lane), `lib/xaas/billing/*` (SPEC-07
multitenancy lane: `approval_patch_sla_credit_apply.ex` multitenancy macro error),
`lib/xaas/bridges/graphlaw.ex` (SPEC-10 lane, missing `end`). All W968c verification
runs were taken in compile windows between neighbor writes.

## Build root

`_build-laneW968c` left on disk for the coordinator (dispatch allowed either
behavior). One typo'd build root created by a background-command mistake during this
session was deleted in the same session. No other build roots created.