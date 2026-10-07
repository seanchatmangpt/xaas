# W975b retroactive mint (lane receipt)

Lane W975b (retroactive mint), xaas v26.10.6 campaign, 2026-10-07. Repo: `/Users/sac/xaas`
(canonical checkout), branch `feat/playwright-surface`. No commit; no build root; zero
lib/test edits. Two doc writes only.

## Task

From W969f's adjudication (`docs/sjira/v26.10.6/plans/w969f-dispatch-confirm.md` §d
open item 1): W975b's design-wave-4 receipt was never written while the landed
SPEC-07 code is on tree and the `global?(true)` deviation was adjudicated
DEVIATION-ACCEPTED. Mint the receipt per the W790/w668 retroactive pattern.

## What was done

1. Confirmed absence: `ls docs/sjira/v26.10.6/plans/ | grep -i w975` → only
   `w975-refusal-negative-fold.md` (unrelated); no W975b receipt existed.
2. Read the landed surface from real code (sed on each file, this session):
   identical SPEC-07 `multitenancy` blocks (`strategy(:attribute)`, `attribute(:org_id)`,
   `global?(true)`, `parse_inline_idents?(false)`) at
   `lib/xaas/billing/subscription.ex:121-134`,
   `lib/xaas/billing/approval_sla_credit_apply.ex:46-59`,
   `lib/xaas/billing/revenue_recognition.ex:31-44`,
   `lib/xaas/billing/approval_patch_sla_credit_apply.ex:40-53`;
   `approval_pricing_override.ex:74-86` uses per-action `multitenancy(:allow_global)`
   instead (W969f open item 2, noted as skew, not this lane's).
3. Confirmed the Chesterton clause: `SlaCreditActorOrgMatches` retained —
   `lib/xaas/billing/checks/sla_credit_actor_org_matches.ex` plus `authorize_if`
   references in `approval_sla_credit_apply.ex:75` and `approval_patch_sla_credit_apply.ex:75,79`.
4. Read the court test source in full (`test/xaas/billing/multitenancy_deepening_test.exs`,
   68 lines; moduledoc names lane W975b design-wave 4) and witnessed its assertions.
5. Read the adjudication and pattern sources: `w969f-dispatch-confirm.md` (§c verdict,
   §d verification), `w790-w668-receipt-mint.md` (retroactive pattern).
6. Wrote the mint: `docs/sjira/v26.10.6/plans/w975b-design-wave4.md` — header
   "Retroactive receipt (W975b mint, 2026-10-07)", ≤15 lines, LANDED-UNCOMMITTED,
   4 files at exact line ranges, court, adjudication citation, falsifier.
   All facts sourced from disk reads this session; nothing re-executed.

## Commands (real, this lane)

```bash
grep -n "global?(true)" lib/xaas/billing/*.ex        # → 3 resource-level sites + patch file
sed -n '118,134p' lib/xaas/billing/subscription.ex   # → SPEC-07 block verbatim
ls docs/sjira/v26.10.6/plans/ | grep -i w975         # → no prior w975b receipt (absence)
```

No tests run, no code touched — documentation-only lane.

## Files written

- `docs/sjira/v26.10.6/plans/w975b-design-wave4.md` (new — the mint)
- `docs/sjira/v26.10.6/plans/w975b-retroactive-mint.md` (this file)

Nothing else updated, per lane contract.

## Standing

**LANDED-UNCOMMITTED** for the mint, matching W969f's adjudicated standing: every
claim in the minted receipt traces to a disk read this session, but this lane
re-executed nothing — the code's standing is exactly what W969f witnessed.
Falsifier: any cited multitenancy block or line range not matching disk, the court
test missing, or a prior `w975b*` receipt surfacing that contradicts the mint's
absence claim. Carried open (coordinator's, per W969f): pricing_override mechanism
skew; court executable bodies cover Subscription only.
