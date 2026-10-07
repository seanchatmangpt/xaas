# W981c — parse_inline_idents? compile-break lane receipt

- Date: 2026-10-07, lane W981c, repo /Users/sac/xaas @ 6f235905 (feat/playwright-surface)
- Task: unblock billing compile break from in-flight `parse_inline_idents?(false)`
  edits in 4 billing files.

## Finding: already resolved upstream before first edit

At lane start (08:30 PDT) the 4 files
(`lib/xaas/billing/{approval_sla_credit_apply,approval_patch_sla_credit_apply,subscription,revenue_recognition}.ex`)
were `M` in the working tree, but contained **zero** `parse_inline_idents`
occurrences (grep, repo-wide: zero matches in lib/ and test/). Between 08:30 and
08:48 the owning lanes reverted all 4 files to HEAD; verified
`git diff --exit-code` = 0 on all four at close.

The break W978b/W980k recorded (`undefined function parse_inline_idents?/1`)
was therefore already gone; the correct DSL question is moot on-disk — the
in-flight edits were removed, not translated. `identities do ... end` blocks in
subscription.ex are HEAD content (ash 3.34.4 `identities` DSL, no inline-ident
option exists or is needed).

## Commands / exits (MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW981c, asdf shims PATH)

- `mix compile --force --warnings-as-errors` → EXIT=1 first (3 warnings):
  - `lib/xaas/bridges/graphlaw.ex` TokenMissingError (owning lane mid-edit;
    fixed by owner within ~8 min, observed green at 08:47)
  - unused `require Ash.Query` in
    `lib/xaas/platform/validations/route_projects_backups_retain_until_passed.ex`
    (another lane's in-flight file; shared-compile freeze → minimal SLA unblock)
  - `@envelope_domain_tag` unused warning in path dep `../ash_affidavit`
    (outside repo, not fixed; elixir did not fail that app's compile)
- After removing the single unused-require line (only edit this lane made):
  `mix compile --force --warnings-as-errors` → **EXIT=0**, 940 files.
- `mix test test/xaas/governance/multitenant_approval_deepening_test.exs
  test/xaas/ledger/reversal_deepening_test.exs` → EXIT=0, **23 passed**.
- `mix test test/xaas/billing/` → EXIT=2, 26/29, 3 failures in the untracked
  other-lane `test/xaas/billing/billing_multitenancy_court_test.exs`
  (Subscription.create required org_id/stripe_customer_id not supplied by that
  test).
- Final combined rerun after --force:
  `mix test <two named files> test/xaas/billing/` → EXIT=2, **51/52 passed**;
  sole failure: `Xaas.Billing.ApprovalTierDowngradeTest` — "changesets require a
  tenant to be specified", test calls `Ash.update!` without tenant. The lib file
  `approval_tier_downgrade.ex` carries another lane's uncommitted multitenancy
  edit (M in status, not in this lane's write scope); failure is that lane's
  in-flight drift, pre-existing relative to W981c.

## Per-file before/after (this lane)

- 4 billing files: before = working-tree M with no parse_inline_idents (owner
  already removed); after = byte-identical to HEAD (verified). No edits by
  W981c.
- `lib/xaas/platform/validations/route_projects_backups_retain_until_passed.ex`:
  before = had `  require Ash.Query` (line 21, unused) → after = line removed.
  Disclosed compile-freeze SLA unblock on another lane's in-flight file.

## Standing

- parse_inline_idents break: **ALIVE-fixed-by-owner** (verified: absent on disk,
  compile green).
- W981c named gates: compile EXIT=0; named tests 23/23. Billing drift courts:
  51/52, 1 failure attributable to another lane's in-flight
  approval_tier_downgrade.ex edit — BLOCKED(other-lane-in-flight), not regressed
  by W981c.
- Not committed (per instruction); `_build-laneW981c` deletion was denied by the
  permission layer — left in place for the coordinator per the lease rule.
