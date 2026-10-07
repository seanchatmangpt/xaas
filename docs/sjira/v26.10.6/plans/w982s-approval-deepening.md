# W982s — billing approval-surface LIFECYCLE deepening court

- Lane: W982s (v26.10.6 campaign, branch `feat/playwright-surface`)
- Subject: `/Users/sac/xaas` @ `49a719ab9975f752c36364fb66e70aa39d0347c1` (working tree; tests-only diff)
- Date: 2026-10-07
- Scope honored: no resource files touched; no commit; writes =
  `test/xaas/billing/approval_lifecycle_deepening_court_test.exs` (new) + this receipt.

## Interpretation note (scope "8 approval resources")

SPEC-07's 8-resource multitenancy set =
{4 × W970a landed} ∪ {4 × W982p in-flight} =
{pricing_override, quota_override, invoice_reconciliation_approve, tier_downgrade} ∪
{subscription, sla_credit_apply, patch_sla_credit_apply, revenue_recognition}.
Of those, exactly **6 carry an approval lifecycle** (`:approve` action):
the 6 billing `Approval*` resources. `Subscription` and `RevenueRecognition`
carry no `:approve` action (introspected — `Ash.Resource.Info.action/2`
returns nil for :approve on both). This court covers all 6 lifecycle
resources; the other 2 of the SPEC-07 8 are report-only here.

## Guard matrix (as witnessed at HEAD 49a719ab, 2026-10-07)

| resource | transition guard (re-approve) | self-approval guard | race-safe | isolated (cross-tenant read+update refused) |
|---|---|---|---|---|
| ApprovalPricingOverride | ABSENT | PRESENT (RequiresApprover) | NO — both race tasks succeed | YES |
| ApprovalQuotaOverride | ABSENT | PRESENT | NO — both succeed | YES |
| ApprovalInvoiceReconciliationApprove | ABSENT | PRESENT | NOT witnessed as safe — both succeed | YES |
| ApprovalPatchSlaCreditApply | ABSENT | PRESENT | NO — both succeed | YES |
| ApprovalSlaCreditApply | PRESENT (DB-level `filter(expr(is_nil(approved_by)))`, W746) | PRESENT | YES — exactly one success | YES |
| ApprovalTierDowngrade | INCIDENTALLY guarded (refused only by downstream `SubscriptionChangeTierNotNoOp` when the downgrade already applied; an approved record whose change_tier never applied can be re-approved) | PRESENT | PARTIAL — refused incidentally | YES |

(Note row header typo above: "race-safe" column spans tests 1a/3a; harmless.)

## Typed findings (report-only, per lane instruction)

1. **REFUSED(guard-absent) — re-approval transition guard missing on 4 resources**
   (pricing_override, quota_override, invoice_reconciliation_approve,
   patch_sla_credit_apply). Re-approving an already-approved record with a
   distinct second approver SUCCEEDS and overwrites approved_by. For the two
   SLA-credit resources this is money-adjacent (patch_sla_credit_apply's
   `:approve` change credits the ledger via
   `ApprovalPatchSlaCreditApplyApprove`; the WHERE filter that makes the
   sla_credit sibling safe is absent there). Recommended fix: same
   `change(filter(expr(is_nil(approved_by))))` shape as
   `approval_sla_credit_apply.ex` (W746 corrected contract).
2. **PARTIAL(guard-incidental) — ApprovalTierDowngrade**
   refused on re-approve only by downstream `SubscriptionChangeTierNotNoOp`;
   not an approval-lifecycle guard. If a downgrade's change_tier failed
   after `approved_by` persisted, re-approval would be possible. Fix shape:
   same `filter(expr(is_nil(approved_by)))` guard.
3. **UNSUPPORTED(delete-verb-absent)** — none of the 6 exposes a `:destroy`
   action (introspection witness, test 0b). Delete-verb isolation therefore
   cannot be probed at the Ash layer; surfaced so the coordinator routes the
   verb-probe decision.
4. **Report-only scope note**: `Subscription` and `RevenueRecognition` (the
   other 2 of SPEC-07's 8) have no approval lifecycle; lifecycle matrix is
   6-wide, not 8-wide, for this reason.

## What passed (ALIVE witnesses)

- 0a: all 6 `:approve` actions introspect their own RequiresApprover validation.
- 1a/3a: `ApprovalSlaCreditApply`: re-approve refused typed (Ash 3.34 zero-row UPDATE → `Ash.Error.Changes.StaleRecord`,
  Invalid class — the W746 DB-level filter); double-approve race (Task.async ×2,
  Sandbox.allow barrier) → exactly one success, loser refused typed zero-row.
  Ledger: exactly one real credit, single approved_by persisted.
- 2: self-approval refused typed (`:approved_by` validation error) on all 6.
- 4a/4b: cross-tenant read (`Ash.get!` Invalid) and cross-tenant
  update(`:approve`) (typed zero-row refusal) refused per resource; owner
  re-approve after cross-tenant attempt still works (4a); stale foreign-tenant
  record cannot approve (4b). Different verbs than the multitenancy court
  (read-only + get there; read+update+stale-record here); delete verb absent
  (finding 3).

## Verification receipt

- Build: fresh lane root `_build-laneW982s` (created this session from
  scratch; wasmex NIF from user cache after a transient disk-full enoent).
- Commands (real tails):
  - `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-... mix compile` → exit 0
  - `mix test test/xaas/billing/approval_lifecycle_deepening_court_test.exs`
    → `Result: 9 passed` (run 1)
  - `mix test test/xaas/billing/approval_lifecycle_deepening_court_test file` → `Result: 9 passed` (run 2)
  - `mix test test/xaas/billing/` → `Result: 40 passed` (siblings + multitenancy court + this court)
  - `mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage([...]))'` → `[]` (mock gate clean)
  - warning-clean for the new file (`@envelope_domain_tag` warning is pre-existing, other module).
- Toolchain: elixir 1.20.2-otp-28 / OTP 28 via asdf shims.
- Postgres: real local Postgres, `Ecto.Adapters.Sandbox` checked out per test.

## Standing

- Court: **ALIVE** — 9/9 real-Postgres tests green ×2 runs, 40/40 billing dir.
- Findings 1–3: report-only; standing UNKNOWN until a fix lane lands the
  transition guards / coordinator rules on the delete verb.
- Mid-run disclosures: (a) transient disk-full (1.9Gi avail) blocked the
  fresh-root deps compile; resolved without deleting any other lane's build
  root (space freed externally before my retry; 56Gi avail at retry).
  (b) W982p applied a disclosed compile-freeze-SLA unblock to my test file
  mid-lane (introspection fix in test 0a + `Ash.Error.Query.NotFound` →
  later generalized to the zero-row helper); retained.

## Falsifiers

- Court falsifier: delete the
  `change(filter(expr(is_nil(approved_by))))` line from
  `lib/xaas/billing/approval_sla_credit_apply.ex` → tests 1a/3a fail.
- Finding-1 falsifier: add the same filter guard to the 4 unguarded
  resources → test 1b/3b witnesses flip (fail) → update matrix with the fix.
- Multitenancy falsifier: delete any resource's `multitenancy do` block →
  tests 4a/4b fail (cross-tenant approve would succeed).
