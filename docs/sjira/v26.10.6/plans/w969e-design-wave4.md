# W969e — DESIGN wave 4 receipt

Lane W969e, xaas v26.10.6, repo `/Users/sac/xaas`, branch `feat/playwright-surface`.
Lane opened ~08:05, closed 08:15 local. **No commit** (lane contract). **Zero edits to
any implementation or test file by this lane.** Standing: **REFUSED(disjointness)** —
every remaining M spec in the W905 backlog was landed, in-flight on disk, banned, or
blocked at lane open.

## Spec selection sweep (full backlog re-derived from live disk, not the register)

Landed/in-flight state verified directly on disk before any edit:

| spec | status at lane open | evidence |
|---|---|---|
| SPEC-04/18 | landed (uncommitted) | W969b receipt + `authenticate_org.ex`, `freeze_window_active.ex` on disk 07:39 |
| SPEC-14/27 | landed (uncommitted) | W968c migrations `20261007230000/231000` + `transfer.ex`/`capability_liveness_receipt.ex` modified |
| SPEC-16/17 | landed | migrations `20261007220000_add_used_at...` |
| SPEC-09 | landed | migration `20261007210000_add_capability_class...` |
| SPEC-07 | **in-flight, lane W975b** | multitenancy blocks naming "lane W975b design-wave 4" in `subscription.ex`, `approval_sla_credit_apply.ex`, `approval_patch_sla_credit_apply.ex`, `revenue_recognition.ex`, mtimes 08:14:37 — **27 seconds before this lane's collision check** |
| SPEC-10 | in-flight | untracked `test/xaas/graphlaw_limit_gate_test.exs` |
| SPEC-20 | in-flight | `route_projects_backups.ex` mtime ~8 min before lane close |
| SPEC-24 | in-flight | untracked migration `20261007240000_add_castle_run_id_to_incidents.exs` |
| SPEC-30 | in-flight | untracked `test/xaas_web/graphql_http_surface_test.exs` |
| SPEC-26 | banned surface | `checkout.ex` (lane-dirty per task ban list) |
| SPEC-08/32/34 | L-estimate | out of lane scope (M-only contract) |
| SPEC-31 | blocked | on in-flight SPEC-30 |
| SPEC-04 | (cross-check) | `resolve_org_actor.ex` also lane-dirty (W969b) — untouched |

First pick was SPEC-07 (billing multitenancy): I had drafted the scope as the three
org_id-bearing resources plus call-site tenant passage, scoped down from the spec's
"all 8 resources" (the other 4 lack `org_id` entirely and would need attribute +
backfill — beyond M). During caller enumeration I found the live W975b work landing
mid-lane: my earlier read of `subscription.ex` (lane open, ~08:07) still carried the
"real Ash multitenancy wiring is named there as disclosed follow-up" disclosure; the
same file at 08:14:37 carried W975b's `multitenancy do ... global?(true)` block. I
backed the drafts out with zero edits. Note for the coordinator (O, not mine to fix):
W975b chose `global?(true)` where w905 SPEC-07 says "global? no" — a real spec
deviation to adjudicate at integration.

## Verification

None run. No build, no tests — nothing of mine to verify. The pre-existing
`_build-laneW969e/` full dep build (present at lane open, 08:10) was not used and is
**left in place for the coordinator** per the lease contract ("delete when done, else
leave") since an `rm -rf` of a full dep tree was likely to hit the same permission
boundary W969b hit, and the coordinator deletes lane leases at integration anyway.

## Standing

**REFUSED(disjointness)** — wave-4 selection is empty. The 18-row W905 backlog is now
fully claimed: 7 landed (04, 09, 14, 16/17, 18, 21, 27), 5 in-flight on disk by five
other lanes (07 W975b, 10, 20, 24, 30), 1 blocked (31), 3 L-estimate (08/32/34) out of
scope, 1 banned surface (26). Zero duplication risk introduced; zero files touched.
