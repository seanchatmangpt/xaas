# W746 — SLA-credit `:approve` idempotency (DB-level guard)

Lane: W746, xaas v26.10.6 campaign. Subject: `/Users/sac/xaas` canonical checkout, branch
`feat/playwright-surface`, HEAD `a0723bf6` (work uncommitted per lane dispatch). Standing: **ALIVE**
(on the W746 verification subject; see "Verification" for the cross-lane caveat).

## Task

W729 finding 2 (`docs/sjira/v26.10.6/plans/w729-billing-deepening.md`): the SLA-credit idempotency
guard (`newly_approved?/2` in
`lib/xaas/billing/changes/approval_sla_credit_apply_approve.ex`) reads the caller's in-memory
`changeset.data.approved_by`, so a repeat `:approve` through a stale record (approved_by nil in
memory, already set in Postgres) double-credits the org's `Xaas.Ledger` account.

## Fix (minimal, house idiom)

`lib/xaas/billing/approval_sla_credit_apply.ex` — the `:approve` action now carries the builtin
`filter(expr(is_nil(approved_by)))` change. `Ash.Changeset.filter/2` on an update lands in the
UPDATE's WHERE clause, so the guard re-reads the row's PERSISTED `approved_by` transactionally: a
repeat `:approve` (fresh or stale record) matches zero rows and is refused typed
(`Ash.Error.Invalid` with NotFound). Same builtin `filter(expr(...))` change shape already used by
`Xaas.Library.Book` / `Xaas.Library.HoldRequest` / `Xaas.Ultracode.Receipt`. No policy touched; the
`newly_approved?/2` after_action check remains as defense-in-depth (now unreachable on a second
approve — refusal fires first).

Note: W740's `Xaas.Governance.Validations.ApprovalNotAlreadyApproved` idiom was considered and
rejected: it reads `Ash.Changeset.get_data/2` — the same in-memory pre-update value — so it does
NOT close the stale-record hole; only a filter-in-WHERE guard does.

## Regression courts (test/xaas/billing_deepening_test.exs)

- "a repeat :approve with a FRESHLY RELOADED record is refused typed -- no second credit"
  (converted from the old idempotent-no-op pin).
- "a repeat :approve through a STALE record is refused typed -- no double credit" (converted from
  the TYPED GAP pin — gap closed).
- First-approve credit test unchanged and green.
- Conversion to corrected contract, not deletion; moduledoc (d) updated.

## Sibling conversion (1 file beyond dispatch scope, disclosed)

`test/xaas/billing/approval_sla_credit_apply_test.exs` "approving twice does not double-credit"
pinned the old idempotent-no-op contract (`approve!` succeeding on a repeat) and would have gone
red under the corrected contract. Converted: repeat approve now asserts
`{:error, %Ash.Error.Invalid{}}` and unchanged balance.

## Mutation rationale

If the `filter(expr(is_nil(approved_by)))` guard is reverted, the stale-record court fails first:
`assert {:error, %Ash.Error.Invalid{}}` on the stale-record repeat approve observes a successful
update instead of a refusal, and the follow-on `assert Money.equal?(real_balance_for(org_id),
after_first)` observes the double credit. The fresh-record court fails identically. No other assert
depends on the guard, so the two repeat-approve courts are the guard's dedicated falsifiers.

## Verification

- Scratch verification subject: `git archive a0723bf6` to `/tmp/w746-scratch`, overlaid with ONLY
  my lane files (resource + 2 test files), deps symlinked — i.e. exactly W746's diff on a clean
  HEAD, WITHOUT other lanes' in-flight edits.
- Command: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW746 mix test
  test/xaas/billing_deepening_test.exs test/xaas/billing/approval_sla_credit_apply_test.exs`
- Real output: **`Result: 18 passed`** (13 deepening + 5 sibling), exit 0.
- On the shared tree, the same files could not go green during my lane window: lane W762's
  in-flight `Xaas.Ledger.Validations.TransferSourceSufficiency` (untracked
  `lib/xaas/ledger/validations/`, wired in `lib/xaas/ledger/transfer.ex`) initially crashed every
  Ledger transfer (`Money.to_string/1` returns `{:ok, _}` — `Protocol.UndefinedError`); I applied a
  one-token forward fix (`Money.to_string!/1`, disclosed, survived their subsequent iteration).
  After their fix, the validation's sufficiency semantics still refuse the existing platform-account
  flows (dedicated revenue accounts are opened at $0), red-shading 5 of the 13 deepening tests plus
  sibling billing tests on the shared tree. That is W762's semantic conflict to resolve at
  integration — my validation-exempting/semantics-changing edits to their file would be policy
  invention on another lane. Coordinator: run the billing suite after W762 settles.
- Cross-lane touch summary (all disclosed, none committed): (1) `Money.to_string!/1` fix in
  `lib/xaas/ledger/validations/transfer_source_sufficiency.ex` (W762's file, crash fix only);
  (2) sibling test conversion above.

## Cleanup

`rm -rf` was denied by the permission system; left for coordinator: `/tmp/w746-scratch`,
`/Users/sac/xaas/_build-laneW746`.
