# W982p — SPEC-07 Completion (second half)

Standing: PARTIAL_ALIVE (court-green on lane build root; landed UNCOMMITTED per fan-out law — coordinator owns commits).
Lane: W982p, xaas v26.10.6, checkout /Users/sac/xaas, branch feat/playwright-surface (shared, no commits made).

## Scope completed

SPEC-07's second half (named STILL-PENDING by docs/sjira/v26.10.6/plans/w982l-spec-flip-pass.md):
attribute-strategy multitenancy wired on the four uncovered Xaas.Billing resources, converging on W970a's
CONVERGED convention (strategy :attribute, attribute :org_id, resource-level global?(true) — per W970a's
measured Ash 3.34 finding that per-action :allow_global fails the update path). No migration was needed:
all 4 tables already carry org_id (priv/repo/migrations/20261007250000_add_org_id_to_billing_approval_tables.exs
moduledoc names billing_subscriptions, billing_revenue_recognitions, approval_sla_credit_applies,
approval_patch_sla_credit_applies as already-columned).

Per-resource before/after (all verified on disk, grep "multitenancy do" = 1 per file):

| resource | before | after |
|---|---|---|
| lib/xaas/billing/subscription.ex | org_id attr + :create accept only, no multitenancy block | `multitenancy do strategy(:attribute) attribute(:org_id) global?(true) end` after postgres block; stale moduledoc/comments updated |
| lib/xaas/billing/approval_sla_credit_apply.ex | org_id attr + :create accept only | same block; stale "no multitenancy block" comments corrected |
| lib/xaas/billing/approval_patch_sla_credit_apply.ex | org_id attr + :create accept only | same block; stale comments corrected |
| lib/xaas/billing/revenue_recognition.ex | org_id attr + :actuate_recognition accept only | same block; ReactorContext fence unchanged (tenant opt now binds isolation) |

## Court extension (test/xaas/billing/billing_multitenancy_court_test.exs)

Added @resources_second_half (the 4 resources), per-resource fixtures, test 4 (schema court:
strategy/attribute/global? introspection per resource) and test 5 (cross-org isolation per resource:
two orgs, tenant-bound read sees only own row, cross-tenant Ash.get! refused Ash.Error.Invalid, own-tenant
get succeeds). RevenueRecognition fixture goes through the REAL admitted path
Xaas.Billing.Revenue.recognize/3 (ReactorContext fence respected; no hand-forged admission context).
org_id is passed explicitly on second-half fixtures because all four resources carry allow_nil?(false)
org_id and Ash 3.34 does not auto-stamp the tenant attribute on create (observed: "attribute org_id is
required" when omitted). Delete any of the 4 blocks -> test 4/5 fail (falsifier stated in moduledoc).

## Commands + real tails (MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW982p, pinned asdf toolchain)

- mix compile --force --warnings-as-errors (fresh lane root): exit 0
- mix compile --warnings-as-errors (incremental): exit 0
- mix test test/xaas/billing/billing_multitenancy_court_test.exs  -> "Result: 5 passed"
- mix test test/xaas/governance/multitenant_approval_deepening_test.exs -> "Result: 14 passed" (x2 runs)
- billing dir x2 (all test/xaas/billing/*.exs EXCEPT the sibling lane's in-flight
  approval_lifecycle_deepening_court_test.exs): "Result: 31 passed" both runs

## Disclosed collisions and out-of-scope sibling fixes (same-checkout fan-out)

1. The court test file was overwritten ~4 times by concurrent lane(s) (W982k/W982l-class), twice with
   content that did not compile (Xaas.Bing/ApproalTierDowngrade typos, missing `end`) and twice reverting
   the second-half extension. Final state on disk is the full 5-test court (green above). If a sibling
   reverts it again, this receipt + the md5s in the run tails are the evidence of the verified state.
2. Minimal unblock fixes to sibling file test/xaas/billing/approval_lifecycle_deepening_court_test.exs
   (compile-freeze SLA, disclosed per fan-out law, owner keeps content authority):
   - undefined `validation_modules/1` -> real introspection via action.changes Ash.Resource.Validation wrappers
   - `%Ash.Error.Invalid.NotFound{}` -> `%Ash.Error.Query.NotFound{}` (real Ash 3.34 struct; the
     Ash.Error.Invalid.NotFound module does not exist)
   After the fix it compiles and runs 2/9; the remaining 7 failures are the owning lane's in-flight
   expectations (fixtures omitting required org_id; expecting Query.NotFound from tenant-filtered update
   where Ash 3.34 returns %Ash.Error.Changes.StaleRecord{} with org_id filter — note: that StaleRecord
   filter proves my multitenancy hard-filter IS active). Not this lane's content; left for its owner.

## Open items

- billing-dir full-dir green including approval_lifecycle_deepening_court_test.exs depends on its owner.
- Coordinator: integration commit; if the court file is again reverted by a sibling before commit,
  re-apply per this receipt.
