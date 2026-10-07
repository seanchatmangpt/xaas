# W968b — Register final flips (per W967 reconcile)

Lane W968b, 2026-10-07. Repo `/Users/sac/xaas` @ `feat/playwright-surface`.
Doc-only lane: no code, no build root, no commit. Wrote only
`docs/sjira/v26.10.6/plans/w859-typed-gap-register.md`.

## Flips (5, OPEN → REPAIRED)

| Row | Gap | Disclosure | Repair receipt | On-tree confirmation (grep hit before flip) |
|---|---|---|---|---|
| 1 | W665 kernel gap: bare `:emotion_recognition` atom admits | w665-art50-deepening.md | w897-cheap-repairs.md row 1 (7/7, mutation 6/7) | `lib/xaas/semantics/eu_ai_act_admission.ex:184` (W897 trigger) |
| 2 | W729 `UNSUPPORTED(lifecycle-state-machine)` | w729-billing-deepening.md | w897-cheap-repairs.md row 5 (13/13, mutation 12/13; siblings 18/18) | `lib/xaas/billing/subscription.ex:219` (`SubscriptionStripeTransitionAllowed`) |
| 3 | W729 `UNSUPPORTED(db-level-approve-idempotency)` (w897 triage row 6) | w729-billing-deepening.md | w897 row-selection drift note — repair already on HEAD by W746 | `lib/xaas/billing/approval_sla_credit_apply.ex:133` (`change(filter(expr(is_nil(approved_by))))`) |
| 4 | W731 `GAP(graphlaw-registry-path-hardcoded)` | w731-graphlaw-deepening.md | w897-cheap-repairs.md row 11 (18/18, mutation 17/18) | `lib/xaas/graphlaw/catalog.ex:29` (`Application.get_env`) |
| 5 | W893 `GAP(NoServerActionForCancel)` | w925-slot-release.md | w947-cancel-action.md (4 passed ×2, mutation 0/1 court-killed, restored) | `lib/xaas/conference/registration.ex:72` (`update :cancel`) |

Every flip is dual-cited (disclosure + repair receipt) in the register row.
Each named receipt (w897 rows 1/5/11, w897's row-6 drift note for W746,
w947-cancel-action.md) was read in full before flipping, and each repair was
independently confirmed present on the working tree by grep before the row
moved.

## Unverifiable rows

None — all 5 dispatched rows verified.

## Totals (awk field-5 recount, before and after)

- Before: 50 rows = 25 OPEN + 23 REPAIRED + 2 TYPED-OPEN
- After: **50 rows = 20 OPEN + 28 REPAIRED + 2 TYPED-OPEN** (grep/awk-verified
  on disk after the edit; matches W967's predicted 21 OPEN + 27 REPAIRED plus
  the extra NoServerActionForCancel flip W967's falsifier did not count).

## Standing

PARTIAL_ALIVE — documents on the exact subject; no tests or builds were run in
this lane (the courts cited belong to w897/w947's real runs on the same
working tree, verified by reading their receipts and grepping the landed
code). Register/triage hygiene note from w897 carried forward: triage rows
6/13 were stale — row 13 (W750-G1) was already flipped by w945c; row 6 flipped
here.
