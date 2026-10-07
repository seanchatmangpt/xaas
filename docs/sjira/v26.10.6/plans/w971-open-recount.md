# W971 — OPEN-row recount audit (register sweep)

Lane W971, 2026-10-07. Repo `/Users/sac/xaas` @ `feat/playwright-surface`, uncommitted
working tree. Write scope: `w859-typed-gap-register.md` (audit note + stale-row flips) and
this receipt. No commit, no build root.

## Dispatch

Task from W945c's flips: register 50 rows = 25 OPEN / 23 REPAIRED / 2 TYPED-OPEN; audit all
25 OPEN rows against the tree for unflipped repairs.

## Method

Per row: read the row's surface claim, grep/read the named file(s) (or the DB, for W804)
for the claimed defect. STALE-REPAIRED (flip, citing on-tree evidence + identifiable repair
receipt) vs CONFIRMED-OPEN (leave, with on-tree absence evidence). Read disk state
immediately before each edit; concurrent edits reconciled.

## Concurrent-edit reconciliation (W968b)

Mid-audit, W968b's sweep landed on disk and flipped 5 rows I had independently found stale:
W665 kernel gap, W729 lifecycle-state-machine, W729 approve-idempotency, W731
registry-path-hardcoded, W893 NoServerActionForCancel. I re-read the register, verified
W968b's citations against my own on-tree evidence (all 5 matched — eu_ai_act_admission.ex:184,
subscription.ex:219, approval_sla_credit_apply.ex:133, catalog.ex:29, registration.ex:72),
and did not re-flip. Divergence count: 0.

## Per-row verdicts (25 OPEN rows at audit start)

STALE-REPAIRED — 8 found (5 by W968b concurrently, 3 by W971):

| Row | On-tree evidence | Repair receipt |
|---|---|---|
| W665 kernel gap (bare `:emotion_recognition` atom admits) | bare-atom trigger in `affective_in_context?/1`, eu_ai_act_admission.ex:184-188 | w897 row 1 (7/7, mutation 6/7) |
| W729 lifecycle-state-machine | `SubscriptionStripeTransitionAllowed` wired on `:sync_from_stripe`, subscription.ex:219 | w897 row 5 (13/13, mutation 12/13) |
| W729 db-level-approve-idempotency | `change(filter(expr(is_nil(approved_by))))`, approval_sla_credit_apply.ex:133 | W746 (cited by w897 row-selection drift note) |
| W731 capability-class enum | real attribute at capability.ex:28, accept at :45, migration 20261007210000 | w912-s-specs-impl.md SPEC-09 (committed per w940) |
| W731 registry-path-hardcoded | `Application.get_env(:xaas, :graphlaw_registry_path, ...)`, catalog.ex:29 | w897 row 11 (18/18, mutation 17/18) |
| W770 RouteProjects dead-write | real `update :approve` at route_projects.ex:63-71 | w792-approver-wiring.md |
| W893 NoServerActionForCancel | named `update :cancel` at registration.ex:72 | w947-cancel-action.md (4×2, mutation 0/1) |
| W866 dead-branch `maybe_refusal/2` | clause + `refusal_code/1` DELETED (git diff removal lines; on-tree note at execution_fabric_controller.ex:734) | NOT identifiable — uncommitted working-tree change; deleting-lane receipt absent (honesty boundary in row) |

CONFIRMED-OPEN — 17 (with absence evidence):

| Row | On-tree absence evidence |
|---|---|
| W722 gap-2 X-Org-Id caller-asserted | design-class (authenticated org identity = SPEC-04); stays per task direction |
| W729 multitenancy | moduledoc comments confirm unwired (approval_sla_credit_apply.ex:64, subscription.ex:249); SPEC-07 |
| W729 atomic_update | 0 grep hits in lib/xaas/billing/; SPEC-08 |
| W731 limits-not-enforced | EngineLimit referenced only inside graphlaw modules (graphlaw.ex, engine_limit.ex, catalog.ex) — no consumer gate; SPEC-10 |
| W750-G2 detect/1 blind | detect/1 (capability_liveness_regressions.ex:24) compares only last-two-by-inserted_at; no TTL/staleness; SPEC-14 |
| W765 GAP-D freeze-window runtime gate | only ApprovalFreezeOverride resource mentions in billing/operations; no runtime consumer gate; SPEC-18 |
| W770 RouteProjectsBackups transition path | 0 update/destroy actions in route_projects_backups.ex; SPEC-20 |
| W784 TOFU | 0 TOFU/pin-rotation/trust-anchor traces in lib/; deferred to campaign backlog |
| W793 NO_CROSS_REFERENCE | 0 castle refs in incident.ex; SPEC-24 |
| W796-G3 hold fulfillment | 0 Checkout refs in hold_request.ex (fulfillment = HoldRequest :fulfill → Book.borrow_copy); SPEC-26 |
| W799 reversal-action-absent | 0 refund/reverse/undo action hits in lib/xaas/ledger/; SPEC-27 |
| W804 operator action | PARTIALLY STALE, stays OPEN: index `ultracode_epochs_unique_run_cycle_index` now exists in xaas_dev (pg_indexes) but schema_migrations lacks 20261007120000/210000/220000 — direct DDL, not ecto.migrate; replay hazard annotated in row |
| W802/W819 graphql mounted | 0 graphql hits in lib/xaas_web/router.ex; SPEC-30 |
| GAP graphql-domain-coverage | graphql_schema.ex:5 still wires exactly 3 domains; SPEC-31 |
| W824 wire coupling | halt still rides the actuation verb (execution_fabric_controller.ex:760 comment); quiescent envelope surfaced additively only; SPEC-32 |
| W849 backlog-2 CI/regen leg | no drift-guard leg in .github/workflows/ (grep 0 hits); SPEC-34 |
| W902 sandbox contamination | environmental; coordinator hygiene pass pending |

## New totals (grep-verified)

```
$ grep -o '| (OPEN|REPAIRED|TYPED-OPEN) |' w859-typed-gap-register.md | sort | uniq -c
  17 | OPEN |
  31 | REPAIRED |
   2 | TYPED-OPEN |
```

50 rows = **17 OPEN + 31 REPAIRED + 2 TYPED-OPEN** (was 25/23/2 before W971+W968b; task
baseline 25 OPEN predates W968b's concurrent sweep).

## Standing

- Register: PARTIAL_ALIVE — totals grep-verified; all 8 flips carry on-tree evidence;
  7 of 8 carry identifiable repair receipts, 1 (W866 dead-branch) with an explicit
  not-identifiable honesty boundary.
- W804 residual: coordinator must stamp or drop-and-replay dev migrations
  20261007111457/120000/210000/220000 before the next dev `mix ecto.migrate`.
- Receipt subject: uncommitted working tree of `/Users/sac/xaas` @ feat/playwright-surface;
  writes confined to w859-typed-gap-register.md + w971-open-recount.md.
