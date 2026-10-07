# W969f — dispatch confirm / SPEC-07 `global?` deviation adjudication — receipt

Date: 2026-10-07. Lane W969f (coordination audit), xaas v26.10.6, `/Users/sac/xaas`,
branch `feat/playwright-surface`. No commit; no build root; zero edits to lib/test.
Two doc writes only: this receipt + the SPEC-07 row-note append in
`docs/sjira/v26.10.6/plans/w905-design-gap-specs.md` (W971a's tracking table), which
option (c) of the dispatch mandates on a DEVIATION-ACCEPTED verdict.

## (a) The spec vs the deviation

- w905 SPEC-07 (lines 62-67 of `w905-design-gap-specs.md`): `multitenancy :attribute
  :org_id` **(global? no — attribute strategy)** on all 8 billing resources; court =
  mirror W722's lens (a): tenant-bound read filtered, cross-org action → typed refusal.
- Flagged by W969e (`w969e-design-wave4.md`, "Note for the coordinator"): "W975b chose
  `global?(true)` where w905 SPEC-07 says 'global? no' — a real spec deviation to
  adjudicate at integration."
- **Premise discrepancy (witnessed)**: the dispatch says the W975b wave-5 receipt is
  `docs/sjira/v26.10.6/plans/w969f-design-wave5.md`. `test -f` fails — that file does
  not exist, and `find docs/sjira/v26.10.6 -iname '*975*'` returns only the unrelated
  `w975-refusal-negative-fold.md`. No W975b receipt exists anywhere on disk. W975b's
  attribution rests on (i) w969e's collision receipt and (ii) the code comments
  themselves, which read "lane W975b design-wave 4" (`subscription.ex:60-67`,
  `approval_sla_credit_apply.ex:24-32`). The code is real and on disk regardless of
  the missing receipt.

## (b) Is the deviation load-bearing?

**Yes — load-bearing, not gratuitous.** Landed state (real greps, 2026-10-07):

- `subscription.ex:122-132`, `approval_sla_credit_apply.ex:47-57`,
  `revenue_recognition.ex:31-41`, `approval_patch_sla_credit_apply.ex:42-51` — each
  carries `multitenancy do attribute(:org_id); global?(true) end` with the identical
  documented rationale: "every existing caller runs tenant-less today, so a required
  tenant (`global?(false)`) would break them all in a design wave. With global?(true),
  tenant-less [reads keep working]."
- `approval_pricing_override.ex:82-93`: same block minus the resource-level
  `global?`; instead every action is explicitly `multitenancy(:allow_global)` —
  same tenant-optional semantics via a different mechanism; a fourth mechanism
  variant, worth noting for future normalization but not a gate defect.
- The Chesterton requirement in SPEC-07 ("SlaCreditActorOrgMatches policy checks may
  become redundant — keep, don't delete") is satisfied: `SlaCreditActorOrgMatches`
  is still referenced in `approval_sla_credit_apply.ex`,
  `approval_patch_sla_credit_apply.ex`, and `lib/xaas/billing/checks/sla_credit_actor_org_matches.ex`.
- Counterfactual: `global?(false)` would have required every tenant-less caller to
  bind a tenant in the same design wave — exactly the kind of cross-tree caller
  retrofit that exceeds M-scope (w969e independently scoped SPEC-07 down from "all 8
  resources" to the 4 org_id-bearing ones for the same reason).

## (c) Verdict: **DEVIATION-ACCEPTED**

Spec amendment noted in W971a's tracking table (SPEC-07 row,
`w905-design-gap-specs.md:264`). The court still gates correctly per the on-disk
test — record of what the court actually asserts
(`test/xaas/billing/multitenancy_deepening_test.exs`):

1. tenant-bound read (`Ash.Query.set_tenant("org-a")`) is hard-filtered to org-a's
   rows (`assert Enum.all?(rows, &(&1.org_id == "org-a"))`);
2. cross-tenant read of another org's row is typed
   `Ash.Error.Query.NotFound` — the W722 lens-(a) block SPEC-07 demanded;
3. tenant-less global read still returns both orgs' rows — the exact property the
   `global?(true)` deviation preserves (the test documents it as deliberate).
4. Non-vacuity documented in the moduledoc: pre-lane, the tenant-bound read leaked
   org-b's row (no filter existed), so the test fails on the pre-state — the court
   kills the un-landed counterfactual.

Also satisfied from SPEC-07: scope honestly reduced to the 4 org_id-bearing
resources (matches w969e's M-scope note); migration/backfill deferred per the spec's
own "verify NOT NULL + index" advisory, disclosed in the code comments as backstop
on the repo's loose-string `org_id` convention.

## (d) Verification (real commands, real output)

- `test -f .../w969f-design-wave5.md` → no output (file absent); `ls .../plans |
  grep -iE 'w975|wave5|wave-5'` → only `w975-refusal-negative-fold.md`.
- `grep -n "multitenancy\|org_id\|global?"` on the four resources → blocks quoted
  above with exact line numbers.
- `grep -rln SlaCreditActorOrgMatches lib/xaas/billing/` → 3 files (policy kept).
- `grep -n "global?(true)\|global?(false)" lib/xaas/billing/` → 4 resources, all
  `global?(true)` (pricing_override via per-action `allow_global` instead).
- `sed -n '62,67p' w905-design-gap-specs.md` → SPEC-07 spec text confirmed
  ("global? no — attribute strategy").
- One doc edit: appended the SPEC-07 row note to the W971a tracking table in
  `w905-design-gap-specs.md` (Edit succeeded; Edit failure would have aborted the
  receipt).

## Standing

**LANDED-UNCOMMITTED.** Adjudication executed, row-note on disk, court assertions
witnessed from real test source. Open items for the coordinator (not this lane's):
(1) W975b owes a receipt file — attribution is secondhand until one lands;
(2) `approval_pricing_override.ex` uses per-action `allow_global` where the other
three use resource-level `global?(true)` — mechanism skew to normalize at
integration; (3) the court covers Subscription only in its executable bodies
(SlaCreditApply/PricingOverride/RevenueRecognition covered at the resource block
level, witnessed by grep, not by executable test bodies); (4) `global?(true)` means
tenant is optional-by-default across the billing tree — a later SPEC-class hardening
wave could tighten to required-tenant once callers pass tenant.
