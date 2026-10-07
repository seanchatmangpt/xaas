# W984cc — W729/SPEC-08 atomic_update retrofit: EXECUTED — disclosure-only for money-movers, 3 true conversions, court green ×2, mutation killed

## Header

- Lane W984cc, xaas v26.10.6, repo `/Users/sac/xaas`, branch
  `feat/playwright-surface`. **No commit made** (coordinator owns commits).
- Files written:
  - `lib/xaas/billing/` — 13 modified files (exact list below).
  - `test/xaas/billing/atomic_retrofit_court_test.exs` (new court).
  - `docs/sjira/v26.10.6/plans/w983p-register-flips.md` — W729 row flip only
    (shared register file; other rows untouched).
  - This receipt.
- Build root `_build-laneW984cc` left in place for the coordinator: its
  deletion was attempted and DENIED by the permission system. The coordinator
  should `rm -rf _build-laneW984cc` at integration per the lane-lease cleanup
  law.

## Precondition (W984bd contract) — met

At lane open, `git status --porcelain | grep billing` → **empty**: W984ao's
GraphQL-removal commits through `04a153f6` had landed. No billing file hot.

## Falsifier verdict — W984az's named falsifier FIRED: disclosure-only branch

Per the W984bd key warning, the court ran FIRST on the unconverted
money-mover (`ApprovalPatchSlaCreditApply :approve`; same evidence class as
`ApprovalSlaCreditApply`), before any conversion edit:

- Block (b) exactly-one-success `Task.async` double-approve: PASSED — 1 of 2
  concurrent approves succeeded, exactly one real `Xaas.Ledger.Transfer`.
- Block (a) forced-Ledger-failure rollback leg: PASSED — `approved_by` rolled
  back to nil, zero surviving transfers (proven
  `org_id == platform:revenue:sla-credits` forced-failure technique).

Both passed against the unconverted `after_action` body — W984az's predicted
finding fired exactly: `Ash.Changeset.after_action/2` already runs inside the
parent `:approve` transaction, so the approved-not-credited isolation SPEC-08
targeted is already guaranteed. SPEC-08 reduces to **disclosure-only for the
money-movers; no money-mover was force-rewritten**.

## Production diff (13 billing files)

Conversions, sites 3/6/8 — `require_atomic?(false)` dropped from `:approve`:

1. `lib/xaas/billing/approval_pricing_override.ex`
2. `lib/xaas/billing/approval_invoice_reconciliation_approve.ex`
3. `lib/xaas/billing/approval_quota_override.ex`

Conversions — `atomic/3` added so the now-atomic actions verify:

4. `lib/xaas/billing/changes/approval_pricing_override_approve.ex` (no-op
   stub: `def atomic(changeset, _opts, _context), do: {:ok, changeset}` +
   disclosure comment)
5. `lib/xaas/billing/validations/approval_pricing_override_requires_approver.ex`
6. `lib/xaas/billing/validations/approval_invoice_reconciliation_approve_requires_approver.ex`
7. `lib/xaas/billing/validations/approval_quota_override_requires_approver.ex`
   — all three: `{:atomic, [:approved_by], condition, error}` with the
   condition re-derived over `^atomic_ref(:approved_by)` vs persisted
   `requested_by` (first attempt used the bare attribute and evaluated
   against the persisted value — caught by the court, fixed to
   `^atomic_ref`).

Disclosures (typed `## Atomicity disclosure` moduledoc sections; sites
1/2/4/5/7, NOT converted per the falsifier):

8. `lib/xaas/billing/changes/subscription_charge_on_activate.ex`
9. `lib/xaas/billing/changes/subscription_prorate_tier_change.ex`
10. `lib/xaas/billing/changes/approval_sla_credit_apply_approve.ex`
11. `lib/xaas/billing/changes/approval_tier_downgrade_approve.ex`
12. `lib/xaas/billing/changes/approval_patch_sla_credit_apply_approve.ex`

(= 12 files; 13th = the court file, listed above.)

## Court

`test/xaas/billing/atomic_retrofit_court_test.exs` (real Postgres via
`Ecto.Adapters.SQL.Sandbox`, real `Xaas.Ledger`, no mocking):

- (b) exactly-one-success `Task.async` double-approve on the unconverted
  money-mover (`ApprovalPatchSlaCreditApply :approve`): exactly one success,
  exactly one real Transfer.
- (a) forced-Ledger-failure rollback leg on the same unconverted money-mover:
  `approved_by` rolled back, zero surviving transfers.
- (c) converted-site leg: same double-approve court on converted site #8
  (`ApprovalQuotaOverride :approve`, atomic).

## Verification ladder (real tails)

1. Baseline (unconverted): `mix compile` green (fresh lane build root, full
   dep compile, exit 0); court `3 passed` (1.4s).
2. Post-conversion first run: `43/43 billing` initially 38/43 → 39/43 (real
   `MustBeAtomic` + wrong-atomic-expr failures, both caught by courts and
   sibling courts — see Learnings), then after the `^atomic_ref` fix:
   **`Result: 43 passed`** (`mix test test/xaas/billing/`).
3. Mutation kill: stripped the DB-level re-approval guard
   (`change(filter(expr(is_nil(approved_by))))`) from converted site #8
   (`ApprovalQuotaOverride :approve`) via file swap (no `git stash`) → court
   **RED `2/3 passed`** (quota double-approve leg failed: second approve
   succeeded). Restored byte-identical (`diff` clean). This proves the court
   is not vacuous.
4. Confirmation runs: court `Result: 3 passed` ×2, full billing dir
   `Result: 43 passed`.

## Register flip

`docs/sjira/v26.10.6/plans/w983p-register-flips.md`: W729 row
`still OPEN` → `**FLIPPED → REPAIRED (w984cc)**` with full evidence line;
tally line updated 12→11 OPEN / 39→40 REPAIRED (with a re-grep note — the
file's literal-grep convention didn't match my shell re-grep patterns, so the
coordinator should re-grep the tally on disk).

## Learnings / boundary notes

- The bare-attribute atomic validation expr (`approved_by == requested_by`)
  silently evaluates `approved_by` against the PERSISTED value, so a valid
  first approve fails. `^atomic_ref(:approved_by)` is required to reference
  the new value. Caught by two existing courts (1b / 3b legs) + the new
  court — generate-and-kill worked as designed.
- Two cross-lane compile breaks hit mid-lane (`approval_causal_anatomy.ex`
  literal `...` at mtime+40s; `xaas.release_audit.ex` delimiter error) —
  both fixed by their owner lanes within the ~10-minute compile-freeze SLA;
  no intervention, no stash.
- `--force --warnings-as-errors` recompile surfaced an unrelated untracked
  broken file; plain `mix compile` (the campaign gate) was the gate used.

## Standing summary

| item | standing |
|---|---|
| SPEC-08 money-movers (sites 1/2/4/5/7) | REPAIRED(disclosure-only) — falsifier fired, court-witnessed |
| SPEC-08 convert-candidates (sites 3/6/8) | REPAIRED — converted, atomic, court green ×2, mutation killed |
| Court `atomic_retrofit_court_test.exs` | ALIVE — 3 passed ×2 + full billing dir 43/43 |
| Mutation kill (court anti-vacuity) | ALIVE — court RED 2/3 under mutation, green after restore |
| W729 register row | FLIPPED → REPAIRED (w984cc) |
| Compile gate | GREEN (exit 0) at final state |

## Falsifiers going forward

- A duplicate Transfer appearing on any guarded `:approve` must fail the
  court's exactly-one assertions.
- A regression that breaks the after_action rollback isolation on the
  money-movers must fail the rollback leg (forced-failure technique).
- If a future Ash version changes `{:atomic, ...}` validation semantics,
  the converted sites' `*RequiresApprover` validations are the pinned
  surface to re-verify first.
