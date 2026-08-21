# ERRC Innovation Grid — xaas Real Feature Surface

Blue Ocean Strategy ERRC grid (Eliminate-Reduce-Raise-Create) grounded in what actually
exists on disk, re-verified against real `find`/`grep`/`git log` runs. One evolving doc, not
a new dated file per pass — this revision updates the grid in place after this pass's own
real-verified commits. The concurrently-running 25-prompt sequence completed at 25/25 (per
this pass's own task briefing, verified by a real 5x-run regression sweep) and is no longer
active; this ERRC cron is now the sole standing activity on this repo. Last Updated
2026-08-21 (thirteenth pass).

## Thirteenth-pass update

**Real HEAD confirmed: `cf233af`.** `git rev-parse HEAD` →
`cf233af8a8cc860484325fe9e7a4bf0ec70ea9e6`. Two real commits landed since the twelfth-pass
grid's own `98eeccd`: `e90d478` (round 11 — real-verified via `git show e90d478 --stat`, 4
files, 477 insertions — implements exactly item 11/this grid's own twelfth-pass CREATE spec:
`lib/xaas/dev_seeds.ex`, new `priv/repo/seeds.exs` body, `test/xaas/dev_seeds_test.exs`, and
this grid file itself, refreshed in place by that commit to what is now the "Twelfth-pass
update" section above) and `cf233af` (a real `mix xaas.capability_coverage` 3-run
repeatability report, `docs/COVERAGE-TREND-2026-08-21.md`, from this session's separate
Measure-phase standing activity — not this ERRC cron's own output, read for context, not
touched). **Item 11 is now RESOLVED for real**, confirmed independently this pass (not just
citing the commit message): `wc -l priv/repo/seeds.exs` → 45 lines (up from the 19-line stub),
`grep -c "Xaas\." priv/repo/seeds.exs` → 2 real calls, `lib/xaas/dev_seeds.ex` exists and was
read in full this pass (168 lines).

**This pass's real, run-verified answer to the task's own scoped question — does
`Xaas.DevSeeds.approve_seeded_pending!/0` double-charge under repeat calls — is nuanced: the
helper itself is safe, but the resource it exercises has a real, freshly-proven double-charge
bug on direct re-approval, unrelated to the helper's own idempotency design.**

- **The helper itself (`approve_seeded_pending!/0`, `lib/xaas/dev_seeds.ex:88-96`) does not
  double-charge on repeat calls, but not because it is idempotent — because each call
  operates on a fresh row.** Real-traced: `run/0`'s `get_or_create_pending_approval/1`
  (`dev_seeds.ex:144-167`) filters `is_nil(approved_by)` to find an existing unapproved row.
  After a first `approve_seeded_pending!/0` call approves that row (`approved_by` now
  non-nil), a second call's same filter no longer matches it, so `run/0` creates a **second**
  pending `ApprovalBackupRetentionChange` row and approves that one instead. Net real effect
  of calling the helper N times: N distinct approved rows, N real $6.00 overage charges (not
  one row double-charged N times) — a real, disclosed, honest characterization: not a bug
  (each charge corresponds to a distinct real approval event, not a duplicate of the same
  one), but also not the no-op idempotency `run/0`'s own moduledoc claims for itself acting
  alone — `approve_seeded_pending!/0`'s own doc comment does not make an idempotency claim,
  so this is a correct behavior for a smoke-test helper, not a doc/behavior mismatch.
- **The real, freshly-proven bug is one level down: `Xaas.Governance.Changes
  .ApprovalBackupRetentionChangeChargeOverage` — the exact resource/change `DevSeeds`'
  helper exercises, and the atomicity thread's own repeatedly-cited "reference exemplar"
  (rounds 7-9, `docs/claude/diataxis/explanation/errc-innovation-grid.md`'s own prior
  language) — has no guard against being run twice on the SAME already-approved record, and
  a real, live-run test this pass proves it double-charges.** Real-verified by writing and
  running a temporary, uncommitted test this pass (deleted immediately after, never landed —
  `git status --short test/xaas/governance/` confirmed clean before and after): create one
  real `Org` + one real `ApprovalBackupRetentionChange` (`:pro` tier, 90 requested days, 60
  real overage days), call `:approve` once (`approved_by: "approver-scratch"`), read the real
  `Xaas.Ledger.Balance` — `Money.new(:USD, "-6")`, matching the controller test's own known
  60-day-overage math. Call `:approve` a **second time on the identical record** with the same
  `approved_by` (passes `ApprovalBackupRetentionChangeRequiresApprover` — that validation only
  checks `approved_by` is present and differs from `requested_by`, never that the record's
  *prior* `approved_by` was nil) — real output: `Money.new(:USD, "-12")`. **A real, live,
  double-charge.** Root cause read in full,
  `lib/xaas/governance/changes/approval_backup_retention_change_charge_overage.ex:29-45`:
  `change/3` wires `Ash.Changeset.after_action/2` (correct, atomic — this part of the pattern
  is fine) but its callback unconditionally calls `charge_overage/2` any time
  `overage_days(record) > 0`, with **no check of `changeset.data.approved_by`'s pre-write
  value** — unlike its own Billing-domain siblings.
- **This is a real, disclosed regression relative to a pattern this exact codebase already
  established twice, just never applied here.** `lib/xaas/billing/changes
  /approval_sla_credit_apply_approve.ex:75-90` and
  `approval_patch_sla_credit_apply_approve.ex` (same shape) both wrap their real Ledger credit
  in a `newly_approved?(changeset, record)` guard (`prev = changeset.data.approved_by; is_nil
  (prev) or prev == ""`, real-read this pass) — `test/xaas/billing/approval_sla_credit_apply_
  test.exs:93-113`'s own "approving twice does not double-credit" test proves it holds there.
  `Xaas.Billing.Changes.ApprovalTierDowngradeApprove` (round 10's own CREATE item) was
  real-checked this pass for the identical gap and found protected, but by a different,
  incidental mechanism, not a `newly_approved?/2` guard of its own: its `apply_downgrade/1`
  (`approval_tier_downgrade_approve.ex:38-44`) calls `Subscription.change_tier` unconditionally
  too, but `Xaas.Billing.Validations.SubscriptionChangeTierNotNoOp`
  (`lib/xaas/billing/subscription.ex:226-233`'s `validate` line, real-read this pass) rejects
  a `:change_tier` call whose target tier matches the subscription's real current tier — so a
  second `:approve` call (subscription already at `requested_tier` from the first) fails
  validation cleanly and rolls back the second approval's own `approved_by`, inside the same
  outer transaction, with zero double-charge. Real, verified negative, not asserted from
  reading alone — this pass traced the actual validation and confirmed the mechanism, not
  just its absence of a `newly_approved?` call. **`ApprovalBackupRetentionChangeChargeOverage`
  is therefore the one real remaining unguarded instance among this session's own
  5-member "atomic `after_action/2` money/audit write" set** (the other 4 —
  `ApprovalSlaCreditApplyApprove`, `ApprovalPatchSlaCreditApplyApprove`,
  `SubscriptionProrateTierChange`/`ApprovalTierDowngradeApprove`, `WriteAuditLogEntry` — are
  each protected, by 2 different but real mechanisms).
- **Zero existing test coverage of this exact scenario, confirmed by direct grep, not
  inference**: `grep -n "test \""
  test/xaas/governance/approval_backup_retention_change_test.exs
  test/kanban_web/controllers/approval_backup_retention_change_controller_test.exs` shows 1
  unit test (the round-9 forced-Ledger-failure atomicity test) and 9 controller tests (auth,
  org-isolation, happy-path overage/no-overage) — none calls `:approve` twice on the same
  record. `test/xaas/dev_seeds_test.exs` (round 11's own new file) similarly has exactly one
  test of `approve_seeded_pending!/0`, called once. Selected as this pass's CREATE item; full
  spec in the structured output below.

**Doc-drift item real-recounted and fixed this pass, not just carried forward again — the
task's own invitation ("maybe it's time") was correct, and the fix was real but not quite the
predicted one-liner.** Re-ran `grep -rl "routes do" lib/xaas --include="*.ex" | wc -l` → still
56 (unchanged since round 7, now the 7th consecutive pass confirming this exact number).
`architecture-overview.md:27`'s "44 of the 69" **fixed to "56 of the 69"** — a real one-line
correction, applied this pass (the 69 denominator was independently re-verified accurate: a
real `Ash.Domain.Info.resources/1` count across all 7 domains run this pass returns 75 total,
but 6 of those are `AshPaperTrail`'s own auto-generated `.Version` shadow resources
(`ApprovalBackupRetentionChange.Version`, `ApprovalDeploymentQuarantine.Version`,
`ApprovalDrFailover.Version`, `ApprovalFreezeOverride.Version`,
`ApprovalLegalHoldRelease.Version`, `FreezeWindow.Version` — real-enumerated this pass via
`Ash.Domain.Info.resources(Xaas.Governance)`, 33 total, 27 non-`.Version`) — 75 − 6 = 69,
matching the doc's own explicitly-declared-`resources do`-block definition exactly; not a
bug, two real, consistent, differently-scoped counts, worth knowing apart). `http-api-surface
.md:75`'s "44 of 49" needed more than a number swap: real-checked, its own next sentence
("every one of the 44 declares **only** `get :read` and `index :read` — no create/update/
destroy route was added for any resource") is now flatly false — real-verified this pass via
a per-resource `routes do` block scan for `post :create|patch :approve|patch :update|delete
:destroy`: **44 of the 56** resources with a `routes do` block now carry a real mutation
route (the maker-checker wiring rounds 5-10 landed), only 12 are still read-only-only. Fixed
in place: corrected count (56 of 69), corrected mutation-route claim (44 of 56 now mutate, not
0 of 44), and a real, honest downgrade of the Phase-5-still-open framing to "substantially
addressed, not fully resolved" (the 5 deliberately-unwired sensitive resources are still
zero-route regardless of mutation status). Both fixes verified by direct `Read` of the edited
files after editing, not just the `Edit` tool's own success signal.

**This pass's real, task-directed check of `ApprovalTierDowngrade`'s and `DevSeeds`'s own
AshIam/multitenancy/audit-log coverage relative to the patterns rounds 1-9 established — real,
honest, mostly-negative finding, correctly disclosed rather than silently skipped.**
`Xaas.DevSeeds` is not an `Ash.Resource` at all (`grep -n "use Ash.Resource\|use Xaas.Resource"
lib/xaas/dev_seeds.ex` → zero matches, real-confirmed this pass) — it is a plain Elixir module
invoked by `mix run priv/repo/seeds.exs`, so AshIam/multitenancy/`AshPaperTrail`/audit-log
concepts (which apply to Ash resources under HTTP policy authorization) do not literally apply
to it; a real N/A, not an oversight. `Xaas.Billing.ApprovalTierDowngrade`
(`lib/xaas/billing/approval_tier_downgrade.ex`, real-read in full this pass) has **none** of
`multitenancy do`, `AshPaperTrail.Resource`/`paper_trail do`, or `WriteAuditLogEntry` wired —
but real-checked and confirmed this pass: **this is not a resource-specific regression, it is
the whole `Xaas.Billing` domain's real, consistent, existing scope** — `grep -rl
"multitenancy do\|AshPaperTrail.Resource\|WriteAuditLogEntry"
lib/xaas/billing --include="*.ex"` → zero hits across all 7 real Billing resources, not just
this one. The 3 mechanisms rounds 1-9 established are real but were only ever extended to the
Governance domain's `Approval*` resources (per this grid's own "What changed" section,
`dc7c3e9`/`7320791`), never proposed or landed for Billing. This is a real, larger,
cross-cutting question worth naming honestly — Billing's `Approval*` resources now move real
Ledger money (SLA credits, tier-change prorations, and now this pass's own found overage-charge
bug), the same real risk class Governance's multitenancy/audit-log treatment was built to
cover — but extending 3 mechanisms across 7 resources is real, larger-scoped work than one
batch, not this pass's selected CREATE item; carried forward as a named backlog item distinct
from (and broader than) the already-carried-forward item 7 (`MakerChecker` shared DSL).

**Concurrent peer-session churn, observed and left untouched.** `git status --short` this pass
(before this grid's own edit) showed: a modified `templates-hooks/terraform-validate.txt.tmpl`,
and untracked `GGEN-SH-AFTER-MIX-COMPILE.log`, `GGEN-SH-AFTER-PROOF.txt`,
`docs/innovation-exploration-v26.9.1-cycle-report.md`,
`modules/integrations/github/contributing_workflow/.terraform.lock.hcl` — real artifacts of
this session's other standing activities (Terraform, ggen, innovation-explorer), not this ERRC
cron's own output. None read beyond filenames, none touched. `docs/COVERAGE-TREND-2026-08-21.md`
(the Measure-phase report landed as `cf233af`) was read in full for context (its real
"75 total resources" figure fed this pass's own denominator cross-check above) but not edited
— not this cron's own file.

## Twelfth-pass update

**Real HEAD confirmed: `98eeccd`.** `git rev-parse HEAD` →
`98eeccda4ceb49a869006cac51eaac75e2cb8389`. This is round 10, the commit the task briefing
described as having wired `ApprovalTierDowngrade`'s dead no-op `:approve` change to really
drive `Subscription.change_tier` + a real `Ledger` credit, and separately real-root-caused
and resolved the recurring `20260821055848` shared-migration hazard for good. Real-verified
via `git show 98eeccd --stat`: it touches exactly 8 files — this grid, `approval_tier_
downgrade.ex`, `changes/approval_tier_downgrade_approve.ex`, a new `validations/approval_
tier_downgrade_targets_lower_tier.ex`, a new migration
(`..._add_requested_tier_to_approval_tier_downgrade.exs`), a new resource snapshot, and 2
test files (185 new lines in `test/xaas/billing/approval_tier_downgrade_test.exs` plus
controller-test updates). **Item 16/eleventh-pass-selected-CREATE is now RESOLVED**, real and
independently re-read this pass: `lib/xaas/billing/approval_tier_downgrade.ex` now carries a
real `belongs_to :subscription` FK and a real `requested_tier` attribute (`one_of:
[:standard, :pro, :enterprise]`, same enum `Subscription.tier` uses), guarded on `:create` by
a new `ApprovalTierDowngradeTargetsLowerTier` validation (rejects a `requested_tier` that
isn't strictly lower-ranked than the subscription's current tier); `changes/approval_tier_
downgrade_approve.ex` is no longer the byte-identical no-op — its `change/3` now wires
`Ash.Changeset.after_action/2` to `Ash.get/3` the target `Subscription` and call its real
`:change_tier` action with `requested_tier`, `authorize?: false`, matching this codebase's
established atomic pattern (nested transaction, real Ash source-confirmed safe by every other
`after_action/2` write in this repo). The commit's own message also documents a real,
disclosed root-cause resolution of the shared-migration hazard this grid has carried since
round 7/8 (`20260821055848`'s actual target state — 3 tables + `platform_webhooks.encrypted_
secret` — was already reached by earlier migrations; only its `tokens.extra_data` rename was
never applied and, per `Xaas.Accounts.Token`'s own current code still using plain `:extra_
data`, correctly should stay unapplied; resolved by inserting the real version row directly
into `schema_migrations` on both `kanban_dev`/`kanban_test`, no DDL executed, migration file
left untouched — fix-forward, not a history rewrite). **This hazard is now genuinely closed,
not just worked around** — not re-flagged below per this pass's own task instruction.

**This pass's real, systematic re-verification of the remaining 4 dead-no-op `*Approve.ex`
resources: all 4 confirmed still real, unwired no-ops, and — after real, dedicated
target-hunting this pass, not just the eleventh-pass's negative grep — none has a real,
concrete, already-built target to wire into. This is itself the pass's real, disclosable
finding.** Re-read all 4 change modules in full
(`lib/xaas/billing/changes/approval_quota_override_approve.ex`, `approval_invoice_
reconciliation_approve_approve.ex`, `lib/xaas/operations/changes/approval_castle_verb_
schedule_approve.ex`, `approval_k8s_fault_remediate_suggest_approve.ex`) — byte-identical
`def change(changeset, _opts, _context) do changeset end`, unchanged since round 5. Re-ran
the call-site grep (`grep -rn "Changes.ApprovalQuotaOverrideApprove\|Changes.ApprovalInvoice
ReconciliationApproveApprove\|Changes.ApprovalCastleVerbScheduleApprove\|Changes.ApprovalK8s
FaultRemediateSuggestApprove" lib/xaas --include="*.ex"`) → still zero call sites outside each
file's own `defmodule` line. Each resource's own `attributes do` block
(`approval_quota_override.ex`, `approval_invoice_reconciliation_approve.ex`,
`approval_castle_verb_schedule.ex`, `approval_k8s_fault_remediate_suggest.ex`) is still just
`requested_by`/`approved_by` — no FK, no target-identifying attribute at all, the exact same
shape `ApprovalTierDowngrade` had before this round's fix.

Went further than the eleventh pass's own negative grep and real-hunted for a plausible
target for each, real-checked, all four real-negative:
- **`ApprovalQuotaOverride`**: no `Quota`/`Invoice` Ash resource exists anywhere in `lib/xaas`
  (`grep -rli "quota\|invoice" lib/xaas --include="*.ex"` hits only the 2 resources' own
  files, their `changes/`/`validations/` siblings, and 2 unrelated moduledoc mentions). The
  closest real candidate — `Xaas.Billing.ApprovalPricingOverride`'s `AshRateLimiter`
  `rate_limit do backend Xaas.Hammer ... end` block — was read in full and real-rejected: it
  throttles that resource's own `:create` action call *frequency* (anti-abuse, 5/min per
  requester), a different real "quota" concept than an org's business usage quota a "quota
  override" approval would plausibly raise/lower. `Xaas.Billing.Subscription`'s own moduledoc
  (lines 1-59, read in full) — stale, pre-`:change_tier` vintage but still accurate on this
  point — explicitly lists `ApprovalQuotaOverride` among the 6 "presumes a subscription
  already exists... no real row... answers what plan is this org on" resources and names
  "rate-limit add-on SubscriptionItems" as real, undesigned, out-of-scope future Stripe work —
  confirming no real target exists today, only a plausible future one requiring new design.
- **`ApprovalInvoiceReconciliationApprove`**: same negative — no `Invoice` resource, and
  `Subscription`'s moduledoc explicitly scopes "Usage-based overage InvoiceItems" and invoice-
  related Stripe writes as real, separate, undesigned follow-up work, not a present target.
- **`ApprovalCastleVerbSchedule`**: `lib/xaas/operations/` does have 3 real sibling `CastleVerb*`
  catalog resources (`CastleVerbInventoryGoals`, `CastleVerbInventoryComponents`,
  `CastleVerbFortune5Requirements`, all read in full) — but each is `defaults [:read]` only,
  zero mutation actions, zero "schedule" concept on any of them (just `requested_by`/
  `approved_by` read-only rows themselves). Nothing for a "schedule" approval to drive.
- **`ApprovalK8sFaultRemediateSuggest`**: `grep -rli "k8s_fault\|k8s.fault" lib/xaas
  --include="*.ex"` outside the approval resource's own files → zero hits. No real
  remediation-suggestion or fault-tracking resource exists to apply a "suggestion" to.

**Conclusion, matching the task's own anticipated honest outcome: these 4 need a real design
decision (what does "override this org's quota," "reconcile this invoice," "schedule this
castle verb," "apply this k8s remediation suggestion" concretely mean and what data/resource
does it act on) before any of them can be mechanically wired the way `ApprovalTierDowngrade`
was. Forcing a shape onto any of them this pass would be fabricating a design, not
implementing one — not selected as this pass's CREATE item.** Carried forward as a named,
disclosed backlog of 4 design-decision-blocked resources, distinct from (and now the entire
remaining membership of) the dead-no-op-`*Approve.ex` finding class.

**This pass's CREATE item selected instead: the real, 6-times-flagged, design-decision-free
`priv/repo/seeds.exs` gap** (this grid's own carried-forward item 11, first flagged
fifth-pass, re-confirmed unchanged every pass since — sixth, eighth, tenth, eleventh, and now
twelfth). Re-verified this pass: still exactly 19 lines, still the unmodified book stub
(`wc -l priv/repo/seeds.exs` → 19; `grep -c "Xaas\." priv/repo/seeds.exs` → 0). Selected
because every higher-priority contender this pass real-checked out as either genuinely
design-blocked (the 4 dead no-ops above) or already resolved (item 16): with the
atomicity-bug thread closed (rounds 7-9) and the dead-no-op thread now correctly triaged
(1 fixed, 4 disclosed-as-design-blocked), no fresher correctness gap outranks this one.
Real-checked one candidate alternative before settling — `Xaas.Operations.AuditLogEntry`
still has no `AshPaperTrail.Resource` (item 9, `grep -n "AshPaperTrail"
lib/xaas/operations/audit_log_entry.ex` still matches only the moduledoc's own contrastive
prose) — but real-examined this pass and found genuinely thin: `AuditLogEntry`'s own
`actions do` block is `defaults [:read]` plus one `create :create` with **no `:update`, no
`:destroy` action at all** (confirmed by reading the file in full), so `AshPaperTrail`'s real
value (diffing an update against the prior version) has nothing to diff against — it would at
best record a single redundant "created" version per row, not the meaningful protection
against tampering the "audit log is not itself audited" framing implies. Real, honest
downgrade of that item's priority this pass (not a retraction that the gap is real, just a
correction that its value is smaller than previously framed); not selected. Full `seeds.exs`
spec in the structured output below.

**Doc-drift item re-verified unchanged, still not selected.**
`architecture-overview.md:27`/`http-api-surface.md:75`'s "44 of the 69"/"44 of 49" route-count
claim: `grep -rl "routes do" lib/xaas --include="*.ex" | wc -l` → still 56, unchanged, now
flagged in 6 consecutive passes (rounds 7-12). A doc fix, not a feature; still real, still
carried forward at its existing Create item number.

**Concurrent peer-session churn, observed and left untouched.** `git status --short` this
pass (before this grid's own edit) shows the same real artifacts prior passes have already
named as other standing activities' own output, not this cron's concern: a modified
`k8s/secret.yaml.example`, untracked `.terraform-validate-receipts/`,
`GGEN-SH-AFTER-MIX-COMPILE.log`, `GGEN-SH-AFTER-PROOF.txt`,
`docs/claude/diataxis/explanation/wasm4pm-process-intelligence-research.md`,
`e2e/ash-admin-destroy.spec.js`, `templates-hooks/terraform-validate.txt.tmpl`. None read
beyond filenames, none touched.

## Eleventh-pass update

**Real HEAD confirmed: `77c7c13`.** `git rev-parse HEAD` →
`77c7c132bf9d4f3532c0ac76be5d7fbd13118e9c`. This is round 9, the commit the task briefing
named as having "closed the whole after_transaction/after_action atomicity-bug thread
definitively... and added the missing regression test for the reference-pattern resource
itself." Real-verified via `git show 77c7c13 --stat`: it touches exactly 2 files —
`errc-innovation-grid.md` and a new `test/xaas/governance/approval_backup_retention_change_test.exs`
(132 lines) — and the commit message documents the same real forced-`Ledger.Transfer`-failure
technique this grid's own tenth-pass Create item 15 specified (an `Org.slug` equal to the
fixed `platform:revenue:backup-retention-overage` identifier, tripping
`AshDoubleEntry.Transfer.Changes.VerifyTransfer`'s same-account rejection), plus a real
disclosed extra verification step (temporarily reintroducing the historical
`after_transaction`-instead-of-`after_action` bug, confirming the new test genuinely fails,
then restoring the source file with zero diff). **Item 15/tenth-pass-selected-CREATE is now
RESOLVED** — the test-coverage parity gap on `ApprovalBackupRetentionChangeChargeOverage`
(the atomicity pattern's own reference exemplar) is closed; all 5 real money/audit-moving
`after_action/2` writes in this codebase now carry a real forced-failure regression test.
**This closes the entire atomicity-bug-class thread (rounds 7-9) for real, on both axes**:
zero live `after_transaction(` misuse (tenth-pass systematic sweep, unchanged) and zero
remaining test-coverage gaps on the fixed pattern (this pass, confirmed). Not re-opened;
per the task's own instruction, this thread is done.

**Fresh finding — a real, concretely-verified case of "wired but functionally dead":
5 of the 7 `Approval*` resources round 5 (`cec5025`) gave real `:create`/`:approve` mutation
routes to have an `*Approve.ex` Change module that is a pure no-op AND is never even wired
into the resource's `:approve` action at all.** Real-verified this pass, read in full:
`lib/xaas/billing/changes/approval_tier_downgrade_approve.ex`,
`approval_quota_override_approve.ex`, `approval_invoice_reconciliation_approve_approve.ex`,
and `lib/xaas/operations/changes/approval_castle_verb_schedule_approve.ex`,
`approval_k8s_fault_remediate_suggest_approve.ex` — all 5 are byte-for-byte the same shape:
`def change(changeset, _opts, _context) do changeset end`. Cross-checked whether any resource
actually references its own module: `grep -rn "Changes.ApprovalTierDowngradeApprove\|
Changes.ApprovalQuotaOverrideApprove\|Changes.ApprovalInvoiceReconciliationApproveApprove\|
Changes.ApprovalCastleVerbScheduleApprove\|Changes.ApprovalK8sFaultRemediateSuggestApprove"
lib/xaas --include="*.ex"` matches **only each file's own `defmodule` line** — zero call
sites anywhere. Reading each resource's real `update :approve do ... end` block
(`approval_tier_downgrade.ex`, `approval_quota_override.ex`, etc.) confirms why: the action
body has `accept`, `require_atomic? false`, and the `*RequiresApprover` validation, but no
`change {...}` line at all. These 5 modules are real, disclosed-as-dead-on-arrival code:
created (presumably scaffolded alongside their siblings' real wiring) but never connected —
distinct from the `after_transaction/after_action` bug class (which was live-and-wrong code),
this is unreachable code that does nothing, silently, forever. The other 2 of the 7
(`ApprovalSlaCreditApplyApprove`, `ApprovalPatchSlaCreditApplyApprove`) are real exceptions —
both correctly wired and (since round 7/8) atomicity-tested, which is exactly why the grid's
prior passes never flagged this: the 2 loudest, money-moving siblings got fixed and tested,
and the 5 quieter, currently-inert siblings were never independently checked.
- **The standout among the 5 — `Xaas.Billing.ApprovalTierDowngrade` — has a real, ready-made
  target already built and battle-tested to wire into, unlike the other 4.**
  `Xaas.Billing.Subscription`'s real `:change_tier` update action
  (`lib/xaas/billing/subscription.ex:226-236`) already exists, already accepts a `:tier`
  argument constrained to the exact same `one_of: [:standard, :pro, :enterprise]` enum
  `Subscription.tier` itself uses, already atomically (`after_action/2`, confirmed in the
  tenth-pass systematic `after_action` sweep) moves a real prorated `Xaas.Ledger.Transfer` via
  `Xaas.Billing.Changes.SubscriptionProrateTierChange`
  (`lib/xaas/billing/changes/subscription_prorate_tier_change.ex`), and that module's own
  moduledoc (lines 33-40, read in full this pass) explicitly documents handling **both**
  directions symmetrically: an upgrade charges the org, "a **downgrade** (`new_monthly_cents
  < old_monthly_cents`) is a real credit back to the org... the natural double-entry mirror of
  the upgrade charge." `ApprovalTierDowngrade`'s own real gap, by contrast: it currently has
  **no `subscription_id` and no target-tier attribute at all** — just `requested_by`/
  `approved_by` (`approval_tier_downgrade.ex`'s `attributes do` block, read in full) — so even
  with its dead Change module wired up as-is, there is no data on the record to say which
  subscription or which tier. The other 4 (`castle_verb_schedule`, `k8s_fault_remediate_suggest`,
  `quota_override`, `invoice_reconciliation_approve`) have no comparable real, already-built
  downstream action to drive at all (real-checked this pass: `grep -rli
  "castle_verb\|k8s_fault_remediat" lib/xaas --include="*.ex"` finds only unrelated
  `CastleVerbInventoryGoals`/`Components`/`Fortune5Requirements` catalog resources, no
  scheduling action; no `Invoice`/`Quota` resource exists anywhere in `lib/xaas` for the other
  two to target), so wiring them is a real, separate, larger design question each — not this
  pass's scoped pick. Selected as this pass's CREATE item; full spec in the structured output
  below.

**Doc-drift and dev-fixture items re-verified unchanged, real-reconfirmed, still not
selected.** `architecture-overview.md:27` / `http-api-surface.md:75`'s "44 of the 69"/"44 of
49" route-count claim: `grep -rl "routes do" lib/xaas --include="*.ex" | wc -l` → still 56,
unchanged since round 7 first found it, now flagged in 5 consecutive passes (rounds 7-11).
`priv/repo/seeds.exs`: still the unmodified 19-line book stub, `grep -c "Xaas\."
priv/repo/seeds.exs` → still 0, now flagged in 5 consecutive passes. Both carried forward at
their existing Create item numbers below — this pass's dead-code-wiring finding on
`ApprovalTierDowngrade` is more concrete (a real, checkable behavioral gap with a ready-made
fix target) and more valuable (closes an actual functional hole in a shipped mutation route,
not a stale prose number or a missing dev convenience) than either, so it is selected instead
— but both remaining items are real and neither should keep losing the priority contest
forever; a future pass with no fresher functional gap should take one of them.

**Concurrent peer-session churn, observed and left untouched.** `git status --short` this
pass (re-run after this grid's own edit, to separate this cron's own diff from everyone
else's) shows: a modified `templates-hooks/terraform-validate.txt.tmpl`, and untracked
`GGEN-SH-AFTER-MIX-COMPILE.log`, `GGEN-SH-AFTER-PROOF.txt`,
`docs/innovation-exploration-v26.9.1-cycle-report.md`, and
`modules/integrations/github/contributing_workflow/.terraform.lock.hcl` — real artifacts of
this session's other standing activities (ggen, innovation-explorer, Terraform), not this
ERRC cron's own output. None read beyond filenames, none touched. No `gauge_rr_op*`/
`gauge_verify_op*` migration churn observed this pass — the untracked migrations a couple of
passes back are gone from `git status` now, either committed or cleaned up by the peer
session; not this cron's concern either way.

## Tenth-pass update

**Real HEAD confirmed: `db17f3b`.** `git rev-parse HEAD` → `db17f3bab854e33ed41395ddb400c9ae9f6b83d8`.
This is the commit the task briefing named ("round 8 ... just fixed the same
after_transaction/after_action atomicity bug on WriteAuditLogEntry, the 4th resource in that
bug class"). Real-verified via `git show db17f3b --stat`: it touches exactly 3 files —
`errc-innovation-grid.md`, `lib/xaas/governance/changes/write_audit_log_entry.ex`, and
`test/xaas/governance/audit_log_entry_test.exs` — and its commit message documents the same
real fix (`after_action/2` + non-bang `Ash.create/2`), the same real regression test (a
sandboxed-transaction-scoped raw-SQL `CHECK` constraint), and the same real stash/restore
regression-guard proof this grid's own Ninth-pass section already described. **Correction to
that section**: its closing line ("Left uncommitted per this session's own convention...") is
now stale — the fix landed for real as part of `db17f3b`, not left uncommitted. `git status
--short` this pass shows zero diff on `write_audit_log_entry.ex`,
`audit_log_entry_test.exs`, or this grid file itself; the only tracked-file modification is
an unrelated `templates-hooks/terraform-validate.txt.tmpl` (a different session's real work,
not touched). Create item 14 below is updated to cite `db17f3b` as its real resolving commit.

**This pass's real, systematic answer to "is there a 5th `after_transaction` misuse
anywhere in `lib/xaas/`": no — the bug class is definitively closed.** Ran the exact
requested sweep: `grep -rn "after_transaction(" lib/xaas/ --include="*.ex" | grep -v
"^\s*#"` (the real call-site pattern, not moduledoc prose mentioning the term) returns
**exactly one match**: `lib/xaas/governance/changes/enqueue_webhook_deliveries.ex:79`. Read
that module's moduledoc in full this pass (lines 17-55): it is the one real,
correctly-scoped usage — `after_transaction/2` holding a real blocking outbound HTTP
dispatch decision until after the parent transaction durably commits, precisely the case
`after_transaction/2` exists for. Every other hit from the broader `grep -rn
"after_transaction"` (no paren) — `write_audit_log_entry.ex` (3 moduledoc lines describing
the now-fixed history), `approval_sla_credit_apply_approve.ex` /
`approval_patch_sla_credit_apply_approve.ex` / `subscription_prorate_tier_change.ex` (each 3
moduledoc lines, same shape, round 7's real fix narrative), and 2 stale file-level comments
(`approval_sla_credit_apply.ex:86`, `approval_patch_sla_credit_apply.ex:86`, both already
flagged in this grid's Raise section as minor doc-drift, not re-flagged as a new finding) —
is prose, not code. Cross-checked the positive side too: `grep -rln "after_action\b"
lib/xaas/ --include="*.ex"` → 9 files, and reading each confirms every real internal
Postgres-only write in this codebase (`WriteAuditLogEntry`,
`ApprovalBackupRetentionChangeChargeOverage`, `ApprovalSlaCreditApplyApprove`,
`ApprovalPatchSlaCreditApplyApprove`, `SubscriptionProrateTierChange`,
`SubscriptionChargeOnActivate`, `ApplyProviderStatusChange`) now correctly uses
`after_action/2`, while the 2 real outbound-HTTP dispatchers (`EnqueueWebhookDeliveries`,
`DeliverWebhook`) correctly stay on `after_transaction/2` (`DeliverWebhook` doesn't even
call either hook directly — it's a `:deliver` generic action's `run` implementation, not a
changeset hook, so it was never a candidate for this bug class at all). **Zero live
instances of the misuse remain; do not re-open this bug class without a genuinely new
`after_transaction(` call site appearing in a future `git log`.**

**Fresh finding — a real test-coverage parity gap, not a bug, on the pattern's own original
exemplar.** Every one of the 4 resources round 7-8 fixed
(`ApprovalSlaCreditApplyApprove`, `ApprovalPatchSlaCreditApplyApprove`,
`SubscriptionProrateTierChange`, `WriteAuditLogEntry`) now carries a real, deterministic,
forced-failure regression test proving its `after_action/2` atomicity — verified this pass
via `grep -n "test \""` on each file:
`test/xaas/billing/approval_sla_credit_apply_test.exs:164`,
`test/xaas/billing/approval_patch_sla_credit_apply_test.exs:164`,
`test/xaas/billing/subscription_test.exs:278`, and
`test/xaas/governance/audit_log_entry_test.exs`'s 4th test. But
`Xaas.Governance.Changes.ApprovalBackupRetentionChangeChargeOverage`
(`lib/xaas/governance/changes/approval_backup_retention_change_charge_overage.ex`) — the
resource every one of those 4 fixes' moduledocs cites as the pre-existing correct pattern
to match ("approval and the money movement succeed or fail together," its own moduledoc
line 11) — has **no such test of its own**. Real-verified: `find test/xaas/governance
-iname "*backup_retention*"` → only `approval_backup_retention_change_stress_test.exs` (one
test, "30 real concurrent Tasks..."; round 7's own investigation already real-verified
`Task.async`/`Sandbox.allow/3` does NOT reproduce this TOCTOU race — 0/120 collisions across
8x15 trials — so this stress test cannot be the atomicity proof); the only other coverage,
`test/kanban_web/controllers/approval_backup_retention_change_controller_test.exs`, has 9
real tests (`grep -n "test \""`) covering auth, org-isolation, and the happy-path overage
charge, but none forces a real `Ledger.Transfer` failure mid-approval. No
`test/xaas/governance/approval_backup_retention_change_test.exs` unit-test file exists at
all (`find` returns nothing at that path). The exact deterministic technique the 4 sibling
tests already use transfers directly: `charge_overage/2`
(`approval_backup_retention_change_charge_overage.ex:52-53`) calls `open_or_get_account/1`
twice, once for `record.org_id` and once for the fixed
`@platform_revenue_account_identifier` (`"platform:revenue:backup-retention-overage"`,
line 22) — setting a request's real `org_id` to that exact literal string makes both calls
resolve to the identical `Xaas.Ledger.Account` row, deterministically tripping
`AshDoubleEntry.Transfer.Changes.VerifyTransfer`'s real `from_account_id == to_account_id`
rejection, the identical mechanism `approval_sla_credit_apply_test.exs:164-183` already
uses and documents in its own comment. Selected as this pass's CREATE item; full spec in
the structured output below.

**Doc-drift and dev-fixture items re-verified unchanged, not re-selected.**
`architecture-overview.md:27` / `http-api-surface.md:75`'s "44 of 69"/"44 of 49" real
route-block count is still wrong (`grep -rl "routes do" lib/xaas --include="*.ex" | wc -l`
→ still 56, unchanged since round 7 first found it). `priv/repo/seeds.exs` is still the
unmodified 19-line book stub (`grep -c "Xaas\." priv/repo/seeds.exs` → still 0). Both
carried forward in Create below at their existing item numbers, not re-litigated further —
neither is more concrete or more valuable this pass than the test-parity gap above.

**Concurrent peer-session churn, observed and left untouched, per this task's own
instruction.** `git status --short` this pass shows 3 untracked migration files
(`priv/repo/migrations/20260821073032_gauge_rr_op1_happy_v2.exs`,
`20260821073059_gauge_verify_op3_widget_a.exs`, `20260821073114_gauge_rr_op1_happy_v3.exs`)
— the same `gauge_rr_op*`/`gauge_verify_op*` naming pattern round 8 already documented
seeing appear/disappear during its own verification. Also untracked:
`GGEN-SH-AFTER-MIX-COMPILE.log`, `GGEN-SH-AFTER-PROOF.txt`,
`docs/innovation-exploration-v26.9.1-cycle-report.md`,
`modules/integrations/github/contributing_workflow/.terraform.lock.hcl` — real artifacts of
this session's other concurrently-running standing activities (ggen, innovation-explorer,
Terraform), not this ERRC cron's own output. None read or referenced beyond their filenames;
none are xaas backlog items.

## Ninth-pass update

**This grid's own item 14 (the eighth pass's selected CREATE item) is real,
implemented, and independently verified this pass — RESOLVED, uncommitted.**
`Xaas.Governance.Changes.WriteAuditLogEntry` (`lib/xaas/governance/changes/
write_audit_log_entry.ex`) is switched from `Ash.Changeset.after_transaction/2` +
`Ash.create!/2` to `Ash.Changeset.after_action/2` + `Ash.create/2` (non-bang), matching
round 7's now-established atomic-write pattern exactly. Moduledoc rewritten in place to
honestly correct the prior, over-generalized `after_transaction/2` rationale (the same
correction shape round 7 applied to its 3 Ledger changes), rather than leaving the stale
claim in place.

Real regression coverage added to `test/xaas/governance/audit_log_entry_test.exs` (now 4
tests, not 3): a new test forces a genuine `AuditLogEntry` write failure and asserts the
parent `Approval*` record's `approved_by` rolls back rather than being left
approved-but-unaudited. `AuditLogEntry` has no real, legitimately-triggerable unique/check
constraint reachable from valid `Approval*` data (unlike round 7's
`AshDoubleEntry.Transfer.Changes.VerifyTransfer` trick, there was no pre-existing real
validation to lean on) — disclosed and solved differently: a real Postgres `CHECK`
constraint added via raw SQL, scoped to the test's own sandboxed transaction only
(Postgres DDL is transactional; `Ecto.Adapters.SQL.Sandbox` rolls the whole test's
transaction back at checkin, so the constraint never touches the real schema or any other
test). Real stash/restore regression-guard proof performed (matching round 7's own
verification discipline): temporarily reverted the fix via `git stash`, re-ran the new
test, confirmed it fails with a real unhandled `Ecto.ConstraintError` raised through
`Ash.create!/2` (crashing instead of cleanly rolling back — exactly the bug being fixed),
then restored the fix and re-confirmed all 4 tests pass.

Verified for real, independently re-run this pass: `mix compile --force` clean; no schema
change needed (dev + test Postgres both `Migrations already up` with zero code changes to
`priv/repo/migrations/`); the known shared-migration hazard
(`20260821055848_resolve_pending_backlog_20260821.exs`) was still present and still blocks
`mix test` with a real `duplicate_table` error as documented — moved out for verification
runs only and restored unedited immediately after each run, confirmed clean via `git
status` before and after; `mix test` run 3× on the full suite, 1 property + 285 tests, 0
failures each run; `grep -rn "unittest.mock\|Mock(\|MagicMock\|patch(\|monkeypatch\|Mox\b\
|:meck\|meck\."` over `test/` and `lib/` — only the known false positives (Phoenix
`ConnTest.patch/2` HTTP-verb calls and one `json_api` `patch(:update)` route DSL line),
zero real matches.

Left uncommitted per this session's own convention of leaving commits to whoever lands the
paired code fix (this grid update was itself left uncommitted by the eighth pass for the
same reason) — item 14 below marked RESOLVED to reflect real, on-disk, verified state.

## Eighth-pass update

**Round 7's selected CREATE item is real, landed, and independently re-verified this
pass — RESOLVED.** `aec265a` (HEAD's parent's parent at the start of this pass) switched
`ApprovalSlaCreditApplyApprove`, `ApprovalPatchSlaCreditApplyApprove`, and
`SubscriptionProrateTierChange` from `after_transaction/2` to `after_action/2`. Real-verified
this pass: `grep -n "after_action\|after_transaction"` on all 3 files plus their sibling
`ApprovalBackupRetentionChangeChargeOverage` shows all 4 now call
`Ash.Changeset.after_action/2` for the actual Ledger write; each moduledoc carries a "Real
fix: `after_action/2`, not `after_transaction/2` (corrected...)" section explaining the
original wrong generalization from the HTTP-dispatch lesson. Round 7's own commit message
also reports a real, disclosed test-methodology finding (`Task.async`/`Sandbox.allow/3` does
NOT reproduce the race under Ecto Sandbox — 0/120 real collisions across 8×15 trials — so the
regression test instead forces a deterministic failure via `AshDoubleEntry.Transfer.Changes
.VerifyTransfer`'s real `from_account_id == to_account_id` rejection) and a real stash/restore
regression-guard proof. Not re-proposed; item 12 in Create below is now marked RESOLVED.

**A second, real commit landed since round 7 — `6fdca0c`, unrelated to the Ledger-atomicity
work, from the same session's other standing activity (the `xaas.safe_generate_migrations`
mix task).** Fixes a real Design-FMEA-scored gap (RPN=490): `touched_tables/1`'s regex only
recognized the literal `<verb> table(:x)` wrapper, missing `references(:other_table, ...)`
calls nested inside `alter table(:x) do ... end` blocks and bare top-level
`index(:other_table, ...)`/`unique_index(...)` calls — both real forms
`ash_postgres.generate_migrations` emits. Real before/after proof in the commit against the
actual cited file (`.../20260821034020_add_org_fk_....exs`): before, `orgs` (the real FK
target) was silently dropped from the detected table set; after, it's caught. Not this ERRC
cron's own authorship; verified live and not re-proposed.

**The disclosed shared-migration hazard is resolved to a stable, non-blocking state — not
itself rewritten, but no longer an in-progress file to avoid touching.** Real-verified:
`priv/repo/migrations/20260821055848_resolve_pending_backlog_20260821.exs` is fully committed
(`git log --oneline -- <path>` → `53c7340`), present in `HEAD`'s tree
(`git cat-file -e HEAD:<path>` succeeds), and `git status --short -- <path>` is clean — the
prior pass's "deleted" working-tree state was transient and has since resolved itself. Read
in full this pass: it is a real, still-uncorrected instance of the exact cross-table sweep
`xaas.safe_generate_migrations` now exists to prevent (`create table(:autofde_planner_
cache_stats_requests, ...)`, a second `create table(:autofde_planner_match_requests, ...)`,
`alter table(:platform_webhooks)`, `create table(:autofde_planner_cache_hotset_requests,
...)`, and `alter table(:tokens)` all in one `up/0`). It is history now, not a live edit target
— splitting or rewriting an already-committed, presumptively-already-applied migration is its
own real operational hazard (rewriting migration history that may have already run against a
real database) rather than a fix, and the forward-looking guard (`xaas.safe_generate_
migrations`, now also FMEA-hardened by `6fdca0c`) is the correct real mitigation already in
place. Not a CREATE candidate.

**Spot-checked `architecture-overview.md`'s domain/resource-count table and cross-cutting
claims against real code — accurate except the one already-known drift.** Real-verified
per-domain resource counts by reading each `resources do ... end` block directly
(`lib/xaas/{accounts,billing,ledger,marketplace,operations,platform,governance}.ex`): 5 + 7 +
4 + 2 + 17 + 7 + 27 = **69**, matching the doc's table exactly, including the easy-to-miscount
`Operations` 17 (uses `resource(Module)` call syntax, not a DSL block naive grep patterns
expect). `AshPaperTrail` "6 of 69" claim (line 82) also real-verified:
`grep -rl "AshPaperTrail.Resource" lib/xaas | wc -l` → 6. Router tier line-number claims
(`router.ex:57-64`, `73-77`, `79-83`, `96-100`) are all within a few lines of the real
anchors (`scope "/internal-api"` at 57, `forward "/internal-api"` at 82, `forward "/api"` at
99) — accurate close enough to navigate by. The one real drift already on record —
`architecture-overview.md:27`'s "44 of the 69" `json_api routes do` count, real count now 56
— is **still unfixed**: `aec265a`'s commit message documents finding it (as this grid's prior
pass did) but its diff never touched either `architecture-overview.md` or
`http-api-surface.md`, only this grid file and the 3 Ledger changes. Carried forward
unchanged in Raise/Create below, still not selected (a doc fix, not a feature, and a fresh
higher-value item was found this pass — see next finding).

**Fresh finding — the exact same atomicity-bug class round 7 fixed on Ledger writes is
still live on a 4th resource round 7 never touched: the audit-trail write itself.**
`Xaas.Governance.Changes.WriteAuditLogEntry`
(`lib/xaas/governance/changes/write_audit_log_entry.ex:42`) wires its own `Ash.create!/2`
write of `Xaas.Operations.AuditLogEntry` via `Ash.Changeset.after_transaction/2`. Its own
moduledoc (lines 7-17) justifies this explicitly by citing
`EnqueueWebhookDeliveries`'s real, correct `after_transaction/2` pattern ("for the same
reason documented there") — but its own next sentence undercuts that justification: "This
change's own work (a single `Ash.create!/2` on `AuditLogEntry`) is comparatively cheap" (line
12) and, unlike `EnqueueWebhookDeliveries`, it makes **no blocking outbound HTTP call** — it
is a second, purely-internal Postgres write, the identical over-generalization shape round
7's own fix diagnosed and corrected on the 3 Ledger changes ("The HTTP-specific lesson was
over-generalized to a same-database write it doesn't apply to" — this grid's own prior-pass
language, which applies to this file verbatim). Round 7's diff never touched
`write_audit_log_entry.ex` — confirmed via `git show aec265a --stat`, which lists only the 3
Billing changes, the 3 new Billing tests, and this grid file.
- **Where it's wired**: real-verified `grep -rln "WriteAuditLogEntry" lib/xaas` → 3 Governance
  `:approve` actions (`approval_backup_retention_change.ex`, `approval_legal_hold_release.ex`,
  `approval_dr_failover.ex`), each via `change {WriteAuditLogEntry, action: "...", 
  resource_type: "..."}`.
- **Real, concretely triggerable failure mode**: `write_entry/3`
  (`write_audit_log_entry.ex:54-73`) calls `Ash.create!/2` — raises on any failure, does not
  return `{:error, _}` — inside the `after_transaction/2` callback, which fires only once the
  parent `:approve` transaction has **already durably committed**
  (`Ash.Changeset.after_transaction/2` semantics, the same real Ash source
  `deps/ash/lib/ash/changeset/changeset.ex` round 7's own investigation already read). Any
  real failure at that point — a transient Postgres connection error, pool exhaustion, a
  future schema/validation change on `AuditLogEntry` — crashes the request *after* the
  approval is permanently persisted, with **zero compensating action anywhere in this
  codebase**: the caller likely sees a 500 that reads as "the approval failed," when it
  actually succeeded and silently has no corresponding audit-trail row, forever. For a
  resource whose own moduledoc states its job is "who did what, when" compliance record-
  keeping (`audit_log_entry.ex:1-8`), a silent, permanent, undetectable gap in that record is
  a real correctness defect in the audit trail's own core guarantee.
- **Real, verified zero test coverage of this exact scenario**: `grep -n "test \""
  test/xaas/governance/audit_log_entry_test.exs` → exactly 3 tests, all happy-path ("approving
  a real DR failover/legal hold release/backup retention change writes a real AuditLogEntry
  row"). None force a real `write_entry/3` failure and assert what state the parent `Approval*`
  record is left in — the same class of gap round 7 closed for the Ledger writes, still open
  here.
- **Minor, related doc-drift, not itself a bug**: `lib/xaas/billing/approval_sla_credit_apply.ex:85`
  and `lib/xaas/billing/approval_patch_sla_credit_apply.ex:85` (resource-file comments, not the
  `changes/` moduledocs round 7 rewrote) still read "why after_transaction/2" — stale, since
  the actual code these comments describe now uses `after_action/2`. Flagged in Raise, not
  selected as a CREATE item on its own (a one-line comment fix, folds naturally into whichever
  pass next touches these files).
- Selected as this pass's CREATE item; full spec in the structured output below.

**Honest correction on the 25-prompt sequence's claimed completion.** The task briefing for
this pass stated the sequence "has now reached its FINAL prompt... and is
completing/complete." Real `git log --oneline -5` as run this pass shows the opposite of that
claim: HEAD is still `008927d` ("prompt 23/25"), the same commit the sixth-pass grid already
cited. No commit for prompt 24/25 or prompt 25/25 exists in `git log` as of this pass. `git
status --short` does show working-tree changes, but they are not that sequence's own: a
deleted `priv/repo/migrations/20260821055848_resolve_pending_backlog_20260821.exs` (last
touched by `53c7340`, the `xaas.safe_generate_migrations` mix task, unrelated to prompts
24-25), a modified `templates-hooks/terraform-validate.txt.tmpl`, and untracked
`docs/innovation-exploration-v26.9.1-cycle-report.md` plus a `modules/integrations/github/`
Terraform lock file — real artifacts of the separate `innovation-explorer` and Terraform/ggen
work this session also has running, not the 25-prompt sequence. Per this task's own
instruction ("note the 25-prompt sequence's own completion **if git log confirms it**"): it
does not. Real, current, verifiable state is prompt 23/25 landed, 24-25 not yet in `git log`.

**Fresh finding — a real money-movement atomicity gap on 3 of the session's newest
Ledger-writing changes, exactly the failure-path class this pass was asked to hunt.** Four
`Ash.Resource.Change` modules move real `Xaas.Ledger.Transfer` money as a side effect of a
parent `:approve`/`:change_tier` action, and they split into two real, contradictory patterns:

- **Atomic (correct)**: `Xaas.Governance.Changes.ApprovalBackupRetentionChangeChargeOverage`
  (`lib/xaas/governance/changes/approval_backup_retention_change_charge_overage.ex:29`) wires
  its Ledger write via `Ash.Changeset.after_action/2`, which real Ash source
  (`deps/ash/lib/ash/changeset/changeset.ex`'s `transaction_hooks/2`, confirmed by reading it
  this pass) runs *inside* the parent action's own DB transaction. Its own moduledoc states
  the reason plainly: "approval and the money movement succeed or fail together" (lines
  10-12) — a real Ledger failure here rolls the whole `:approve` back, so the record can never
  end up "approved but uncharged."
- **Non-atomic (a real, freshly-found gap)**: `Xaas.Billing.Changes.ApprovalSlaCreditApplyApprove`
  (`lib/xaas/billing/changes/approval_sla_credit_apply_approve.ex:60`),
  `Xaas.Billing.Changes.ApprovalPatchSlaCreditApplyApprove` (same shape,
  `approval_patch_sla_credit_apply_approve.ex:60`), and
  `Xaas.Billing.Changes.SubscriptionProrateTierChange`
  (`lib/xaas/billing/changes/subscription_prorate_tier_change.ex:93`) all instead wire their
  Ledger write via `Ash.Changeset.after_transaction/2`, which real Ash source confirms runs
  only *after* the parent transaction has already committed. All three moduledocs justify this
  by citing the same real prior lesson (commit `f2d57ac`, `EnqueueWebhookDeliveries`'s fix for
  holding a transaction open during a blocking outbound HTTP call) — but none of these three
  make an HTTP call; each does a second, purely-internal Postgres write
  (`Xaas.Ledger.Account` read/open + `Xaas.Ledger.Transfer` create), the exact same shape
  `ApprovalBackupRetentionChangeChargeOverage` correctly keeps atomic. The HTTP-specific lesson
  was over-generalized to a same-database write it doesn't apply to.
- **Real, concretely triggerable failure mode, not theoretical**: `Xaas.Ledger.Account`
  carries a real unique constraint, `identity :unique_identifier, [:identifier]`
  (`lib/xaas/ledger/account.ex:98-99`), and all four changes' shared `open_or_get_account/1`
  helper does a plain read-then-create with no `upsert` — a real TOCTOU race. Two concurrent
  `:approve`/`:change_tier` calls that are each the first to touch a given not-yet-opened
  Ledger account identifier (a real possibility for any org's first SLA credit, first tier
  change, or a client-side retry racing the original request) can both observe `{:ok, nil}`
  from the read and both attempt `Ash.Changeset.for_create(:open, ...)`; the loser hits the
  real unique-constraint violation and `credit_sla/1`/`prorate_tier_change/2` returns
  `{:error, error}`. On the atomic path this rolls the whole approval back — safe. On the
  non-atomic path, the parent record's `approved_by` (SLA credit resources) or `tier`
  (`Subscription`) is **already committed** by the time that error surfaces, the HTTP caller
  gets an error response that looks like the approval/tier-change itself failed, and no money
  ever moved. Worse: each resource's own idempotency guard
  (`newly_approved?/2`/`newly_activated?/2`-style, checking `changeset.data`'s *pre*-write
  value) now sees the record as no longer newly-transitioning on any retry, so the credit/
  charge can never be automatically re-driven — the record is stuck "approved but never
  credited/charged" with no compensating action anywhere in the codebase.
- **Real, verified zero test coverage of this exact failure mode.** `grep -n "test \""
  test/xaas/billing/approval_sla_credit_apply_test.exs
  test/xaas/billing/approval_patch_sla_credit_apply_test.exs` shows 4 tests each (create,
  approve-credits, double-approve-no-double-credit, self-approval-rejected); `grep -n "test
  \"" test/xaas/billing/subscription_test.exs` shows the equivalent set for `:change_tier`.
  None of them force a real `Xaas.Ledger.Transfer`/`Xaas.Ledger.Account` failure mid-approval
  and assert what state the parent record is left in — the exact scenario this pass was
  asked to investigate ("what happens if the Ledger.Transfer itself fails mid-approval").
  Selected as this pass's CREATE item; full spec in the structured output below.

**Fresh finding — real drift between `architecture-overview.md`'s own route-count claim and
current code, not previously spot-checked.** `architecture-overview.md:27` states "which 44 of
the 69 get a real `json_api routes do` block." Real-verified this pass: `grep -rl "routes do"
lib/xaas --include="*.ex" | wc -l` → **56**, not 44. Tracing the number's origin:
`http-api-surface.md:75` itself still says "44 of 49 real resources have that block" — a
real, stale count from when the domain surface totaled 49 resources (before the 25-prompt
sequence grew `Governance` alone to 27 and the total to 69, per both docs' own current
7-domain table). `architecture-overview.md` (written in round 6, after the total had already
reached 69) copied the "44" numerator forward unchanged and only updated the denominator to
69, producing a claim neither doc's own current code supports. Neither doc is more than a
partial-day stale by wall-clock time (`http-api-surface.md` and `architecture-overview.md`
are both dated 2026-08-20), which is itself the real finding: at this session's real commit
velocity (multiple resource-route-adding commits per hour across `b3a169a`/`9f6831f`/
`008927d` alone), a same-day "verified" timestamp is not a same-hour guarantee, and a
cross-doc numeric claim copied instead of re-derived carries the stale source forward
silently. Not selected as this pass's CREATE item (a doc fix, not a feature), but flagged in
Raise below since the task asked for a real drift spot-check.

**`priv/repo/seeds.exs` — third pass flagging the identical, unchanged gap.** Re-verified
this pass: still 19 lines, `grep -c "Xaas\." priv/repo/seeds.exs` → 0. Fifth-pass grid found
it, sixth-pass grid re-confirmed it unchanged, this pass re-confirms it unchanged a third
time. Carried forward in Create below, still not selected (the Ledger-atomicity gap above is
more concrete, more valuable, and more tightly scoped for one batch), but the flag count
itself is now a real signal that this item keeps losing the CREATE-list priority contest
round after round rather than that it isn't real.

## Sixth-pass update

Since the fifth-pass grid, `cec5025` (round 5, real per-30min ultracode cadence) landed
**both** of that grid's top two CREATE items in one commit, verified live this pass:

- **RESOLVED — prior CREATE item 4** (wire real `:create`/`:approve` maker-checker actions
  onto the 7 read-only `Approval*` skeletons). Real-verified: `grep -n "actions do" -A8
  lib/xaas/operations/approval_castle_verb_schedule.ex` and the same check on the other 6
  (`approval_invoice_reconciliation_approve.ex`, `approval_k8s_fault_remediate_suggest.ex`,
  `approval_patch_sla_credit_apply.ex`, `approval_quota_override.ex`,
  `approval_sla_credit_apply.ex`, `approval_tier_downgrade.ex`) now show real `:create`/
  `:approve` actions plus a paired `*_approve.ex` change and `*_requires_approver.ex`
  validation module for each (`find lib/xaas -iname "*requires_approver*" | wc -l` → 45, up
  from 2 at the fifth-pass count).
- **RESOLVED — prior CREATE item 6** (HTTP-level controller tests for those 7, plus the 2
  already-complete-but-untested resources). Real-verified: `find test/kanban_web/controllers
  -iname "approval*controller_test*" | wc -l` → 30, and each of the 7 new test files
  (`approval_castle_verb_schedule_controller_test.exs`, etc.) contains a real `401`
  no-token assertion (`grep -n 401 test/.../approval_castle_verb_schedule_controller_test.exs`
  → lines 63 and 153, matching the existing `RequireInternalApiToken` pattern this project's
  CLAUDE.md requires). Only **2 of 32** `Approval*` resources (`comm -23` between the real
  32-resource list and the real 30-test list) still lack a controller test:
  `approval_freeze_override` and `approval_org_delete` — both are the same 2 the fifth-pass
  grid already named as the narrower residual, not a new finding.
- The concurrent 25-prompt sequence advanced from prompt 20/25 (etcd encryption) to prompt
  21/25 (`9f6831f`, real `Subscription :change_tier` action with prorated Ledger
  adjustment) since the fifth-pass grid — not re-proposed below, per task instructions. It
  is now in flight on prompt 22/25 (SLA-credit Ledger integration).

Fresh, real-verified findings this pass (neither prior grid rounds nor the concurrent
sequence cover these):

- **No single onboarding/architecture-overview doc exists.** Real-verified: `find docs
  -iname "*overview*" -o -iname "*architecture*"` → zero hits. `ls
  docs/claude/diataxis/explanation/` lists 8 files, each a narrow single-topic explainer
  (`ashiam-create-update-limitation.md`, `r2rml-ontop-prototype.md`,
  `reactor-autofde-planners-design.md`, `security-and-testing-decisions.md`,
  `wasm4pm-process-intelligence-research.md`, this grid, 2 others) — none is a top-level map
  of the real 9-domain/49-resource surface, the real routing tiers
  (`lib/kanban_web/router.ex:31-99` — `/webhooks`, `/internal-api` (3 separately-piped
  sub-scopes for capability-liveness, SPARQL proxy, and the general internal API router),
  `/api`), or how AshIam/multitenancy/AshPaperTrail/AuditLogEntry/webhooks/Reactor/Ontop/
  R2RML fit together. A new reader has to reconstruct that picture by reading this ERRC grid
  plus 7+ other explanation docs plus individual moduledocs — real, scattered, no single
  entry point.
- **`priv/repo/seeds.exs` is still the unmodified 19-line book stub** (`wc -l` re-verified
  this pass, unchanged from fifth-pass grid) — carried forward, not re-analyzed further here
  since fifth pass already covered it in full.
- **`Xaas.Operations.AuditLogEntry` still carries no `AshPaperTrail.Resource`**
  (`grep -n "AshPaperTrail" lib/xaas/operations/audit_log_entry.ex` still matches only the
  moduledoc's contrastive prose, line 4) — unchanged from fifth pass, real-reconfirmed, not
  touched by `cec5025` or the concurrent sequence's prompt 21.

## What changed since the last grid (resolved / advanced items)

- **This grid's own prior #3 CREATE item — a real `/internal-api/health` aggregation
  endpoint — is now real and landed, outside this pass's own authorship but verified live**
  (`97768fb`, the concurrent session's own per-30min cadence, round 4): real-verified
  `ls lib/kanban_web/controllers` now includes a health controller wired into
  `lib/kanban_web/router.ex`. The prior grid's Raise finding ("no real health-check or
  readiness aggregation endpoint anywhere in this repo") is resolved.
- **A real cross-resource audit trail, `Xaas.Operations.AuditLogEntry`, landed** (`c5fe889`,
  prompt 17/25 of the concurrent sequence) — wired via
  `lib/xaas/governance/changes/write_audit_log_entry.ex` onto 3 Governance `:approve`
  actions (`approval_dr_failover.ex`, `approval_backup_retention_change.ex`,
  `approval_legal_hold_release.ex`). Per this pass's own fresh investigation (see Raise
  below), `AuditLogEntry` itself carries no `AshPaperTrail.Resource` — a real, freshly-found
  gap this grid did not previously flag.
- The concurrently-running 25-prompt sequence advanced from prompt 15/25 to prompt 20/25
  since the last grid pass, additionally landing real PromQL allowlist hardening
  (`377fc5a`), a real Postgres-pod chaos test (`2a639f3`), real e2e negative-path hardening
  (`c03fc9c`), and real k8s NetworkPolicy application (`9caa85d`, prompt 19/25, a real
  surprising finding that kindnet does enforce it on this kind version) — none of these are
  re-proposed below, per task instructions. It is now working prompt 20/25 (etcd-encryption
  verification), per its own commit history; no disruptive control-plane restart has landed
  in git log as of this pass.

- **This grid's own prior #1 CREATE item — extending real `AshPaperTrail` change-tracking to
  the 4 already-org-scoped Governance `Approval*` resources — is now real and landed**
  (`dc7c3e9`, landed inside this same session, outside this pass's own authorship but
  verified live): `grep -rl "AshPaperTrail.Resource" lib/xaas` now returns 6 files
  (`approval_freeze_override.ex`, `approval_backup_retention_change.ex`,
  `approval_legal_hold_release.ex`, `freeze_window.ex`, `approval_dr_failover.ex`,
  `approval_deployment_quarantine.ex`) — up from 2 last pass. The prior grid's Raise
  finding ("31 of 32 Approval* resources are unaudited") is now real-narrower: 26 of 32.
- The concurrently-running 25-prompt sequence advanced from prompt 10/25 to prompt 15/25
  since the last grid pass, landing real Reactor compensate mechanics (`e5206bd`), real
  Ontop SPARQL auth hardening (`0ff2b97`), real R2RML mapping for 3 more tables
  (`3016c59`), and real stress coverage for `WebhookDelivery`/`ApprovalProviderStatusChange`
  (`9f4255f`) — none of these are re-proposed below, per task instructions.

- **This grid's own prior #1 CREATE item — wiring `ActorOrgMatches` onto the 4 Governance
  resources' `:create`/`:approve` policies — is real and landed** (`7320791`):
  `lib/xaas/governance/checks/actor_org_matches.ex` (a disclosed, domain-local twin of the
  Marketplace check, per this repo's one-Checks-module-per-domain convention), wired via
  `authorize_if Xaas.Governance.Checks.ActorOrgMatches` in place of bare `authorize_if
  always()` on `approval_backup_retention_change.ex`, `approval_dr_failover.ex`,
  `approval_legal_hold_release.ex`, `approval_deployment_quarantine.ex`. Real, disclosed
  finding mid-implementation: these resources' existing `multitenancy do attribute :org_id
  end` already force-overwrites `:create`'s `org_id` to the resolved tenant before policy
  checks run, so `ActorOrgMatches`'s `:create` branch is real-but-currently-unreachable
  defense-in-depth — the `:approve` branch (reading the persisted row) is the genuinely
  load-bearing half, proven by 4 new real cross-org `:approve`-rejected tests.
- **`Xaas.Marketplace.Provider` gained real `:create`/`:update` mutation routes with a
  designed access-control split** (`d9a7006`): `Xaas.Marketplace.Checks.ActorOrgFilter`
  (`Ash.Policy.FilterCheck`) for `:read`/`:update`, `Xaas.Marketplace.Checks.ActorOrgMatches`
  (`Ash.Policy.SimpleCheck`) for `:create` only — split for a real, live-repro'd reason
  (a `FilterCheck` on `:create` forces `access_type: :filter` field authorization, which has
  no row to filter yet and serializes every attribute to `Ash.ForbiddenField`/null in the
  real HTTP response). The pre-existing `AshIam` pilot on `Provider` was removed as a real,
  disclosed casualty of the same root-cause class as
  `ashiam-create-update-limitation.md`.
- **A real marketplace listing lifecycle now exists**: `Xaas.Marketplace.ApprovalProviderStatusChange`
  (`adc839a`) — a maker-checker resource (`requested_by`/`requested_status`/`approved_by`)
  mirroring the Governance `Approval*` shape, with a real `after_action` change
  (`lib/xaas/marketplace/changes/apply_provider_status_change.ex`) that actually flips the
  target `Provider`'s `status` on `:approve`, inside the same transaction.
- **The K-graph MAPE-K loop closed**: `mix xaas.close_coverage_gap` (`53788ea`) now Monitors
  (SPARQL count over the real Turtle-serialized graph), Analyzes (least-exercised class),
  Plans, Acts (invokes that class's real Ash create action against the running server), and
  Monitors again — a real, live-run-verified decide-and-act cycle, not just observation.

- **`Xaas.Accounts.OrgMembership` (the prior grid's #1 CREATE item) is real and landed**
  (`lib/xaas/accounts/org_membership.ex`) — a real join resource (`user_id`, `org_id`,
  `role`) with a real Postgres unique index on `(user_id, org_id)` via `identities do`.
- **`Xaas.Accounts.Checks.ActorBelongsToOrg` is real and landed**
  (`lib/xaas/accounts/checks/actor_belongs_to_org.ex`) — a real `Ash.Policy.SimpleCheck`
  that queries `OrgMembership` rows (`authorize?: false`, mirroring the system-internal
  pattern in `org_test.exs`). It replaces `Xaas.Accounts.Org`'s `actor_present()` fallback
  on `:update` (`org.ex:90-98`); `:create` is deliberately kept on `actor_present()` per the
  check's own disclosed scope limit (no membership can exist for a not-yet-created org).
- **A second, sibling check — `Xaas.Marketplace.Checks.ActorOrgMatches`
  (`lib/xaas/marketplace/checks/actor_org_matches.ex`) — also landed**, wired onto
  `Xaas.Marketplace.Provider`'s `:create`/`:update`. It is the org-asserting-actor shape
  (`%{org_id: org.slug}`, as set by `KanbanWeb.Plugs.ResolveOrgActor`) rather than the
  user-membership shape `ActorBelongsToOrg` uses — a real, disclosed, deliberately smaller
  alternative to full `multitenancy` DSL adoption for a resource whose actor is an org, not
  a user.
- **`KanbanWeb.Plugs.ResolveOrgActor` is real and landed**
  (`lib/kanban_web/plugs/resolve_org_actor.ex`) — resolves the caller-asserted `X-Org-Id`
  header against a real `Xaas.Accounts.Org` row, sets both `conn.assigns[:current_actor]`
  and the real Ash actor/tenant via `Ash.PlugHelpers`. Scoped (by real path-info inspection,
  not a router rewrite) to exactly the 4 Governance resources this grid's prior Raise item
  named, plus `Provider`.
- **The `AshIam` `:create`/`:update` root cause is real, documented, and closed as
  "investigated, not silently left open"**
  (`docs/claude/diataxis/explanation/ashiam-create-update-limitation.md`) — real repro,
  real finding (a `ForbiddenField`-serialization bug in `ash_iam`'s non-`:read` check
  path), real check of the upstream repo (404, no public tracker), files reverted
  byte-identical (`git diff` clean per the doc). This is a genuine root-cause, not a stalled
  investigation — it explains *why* `Org`/`OrgMembership`/`Provider` all still gate
  `:create`/`:update` behind hand-written `SimpleCheck`s instead of `AshIam.Check`.
- **4 more Governance resources went to real, strictly-enforced `multitenancy do ... end`**
  (`global? false`, `attribute :org_id`) this pass — verified live in
  `approval_backup_retention_change.ex:78-80`, `approval_dr_failover.ex:77-79`,
  `approval_legal_hold_release.ex:76-78`, `approval_deployment_quarantine.ex:93-95`, each
  commented "Real Ash-core multitenancy wiring, now strictly enforced."

## Eliminate

- **`lib/xaas/autofde/status_parser.ex` — status changed, not resolved.** Real `git log`
  since the last grid shows 3 real `autofde`-adjacent commits (`0175d4a`, `99c4493`,
  `f542b18`), but all 3 touch `lib/xaas/operations/` (`AutofdePlannerCacheStats`,
  `AutofdePlannerCandidate`, `AutofdePlannerCatalog`/`Match` RDF projection) and
  `lib/xaas/sparql_bridge.ex` — none touch `lib/xaas/autofde/` itself. Re-verified: no
  `Xaas.Autofde` domain module exists in `lib/xaas.ex`'s domain list (real, current 9-domain
  list: `Accounts`, `Billing`, `Governance`, `Hammer`, `Ledger`, `Marketplace`,
  `Operations`, `Platform`, `Secrets` — no `Autofde`), and `status_parser.ex` is still the
  entire real footprint of that directory. Same real eliminate/adopt fork as before; the
  `autofde` *name* has since accreted real, separately-wired functionality under
  `Operations` instead, which if anything strengthens the case that this orphaned file
  should be deleted or merged into that real home rather than kept as a second, unwired
  `autofde` surface.
- **`lib/kanban/aws_repo/fixture_adapter.ex`** — unchanged, still the one disclosed
  permanent no-mocking exception (`docs/AWS-CHAPTERS-SUBSTITUTION.md`); no new sibling
  introduced this pass (checked: no new file under `lib/kanban/aws_repo/`).

## Reduce

- **The 31 top-level `Approval*` resources — count unchanged, duplication unchanged.**
  Re-verified: `find lib/xaas -iname "approval*.ex" ! -path "*/changes/*" !
  -path "*/validations/*"` still returns exactly 31. No `Xaas.Resource.MakerChecker`
  fragment or equivalent shared module exists anywhere in `lib/xaas` (checked: `find
  lib/xaas -iname "*maker_checker*"` → empty). The prior grid's Reduce analysis
  (`approval_freeze_override.ex` vs `approval_pricing_override.ex`, same policy block
  verbatim) still holds exactly as written; nothing this pass touched that duplication.
- **Loose string `org_id` — now a two-tier picture, not one.** 4 Governance resources
  (`approval_backup_retention_change`, `approval_dr_failover`, `approval_legal_hold_release`,
  `approval_deployment_quarantine`) moved from loose string to real, strictly-enforced
  `multitenancy do attribute :org_id; global? false end` this pass (see "What changed"
  above) — real progress, not just documentation. The other ~27 `Approval*` resources are
  unchanged: still plain string `org_id` attributes with no `multitenancy` block and no
  relationship, so the "31 resources independently re-implement loose string FKs" framing
  from the prior grid now applies to a real, smaller, shrinking subset (~27 of 31) rather
  than the whole set — real, measurable reduction of the gap, not a full close.

## Raise

- **NEW this pass, real, live-run-verified — `Xaas.Governance.Changes
  .ApprovalBackupRetentionChangeChargeOverage` double-charges on re-approval of the same
  record.** No `newly_approved?/2`-style guard (unlike its 2 Billing SLA-credit siblings);
  a real, temporary, deleted-after-run test proved `-$6.00` → `-$12.00` across 2 real
  `:approve` calls on 1 record. Full evidence in "Thirteenth-pass update" above. Selected as
  this pass's CREATE item; item 18 in Create below.
- **NEW this pass, real, negative-checked — `ApprovalTierDowngrade`'s equivalent path is
  safe, but by an incidental mechanism, not a deliberate guard.**
  `SubscriptionChangeTierNotNoOp` rejects a same-tier `:change_tier` call, so a second
  `:approve` on an already-downgraded record fails validation and rolls back cleanly. Real,
  traced, not assumed. See "Thirteenth-pass update" above.
- **NEW this pass, real, domain-wide, not resource-specific — `Xaas.Billing`'s entire 7-resource
  surface (including `ApprovalTierDowngrade`, round 10's own CREATE item) has zero
  `multitenancy`, zero `AshPaperTrail.Resource`, zero `WriteAuditLogEntry` wiring.** The 3
  mechanisms rounds 1-9 established were only ever extended to Governance's `Approval*`
  resources, never proposed for Billing, despite Billing's `Approval*` resources now moving
  real Ledger money (SLA credits, tier-change prorations, and this pass's own found overage
  bug) — the same real risk class the Governance treatment was built to cover. Real, larger
  than one batch (7 resources × 3 mechanisms); named as a standing backlog item, not this
  pass's CREATE selection. `Xaas.DevSeeds` itself is confirmed real N/A — not an `Ash.Resource`
  at all, a plain module.
- **RESOLVED this pass — the "44 of the 69"/"44 of 49" real HTTP-route-block/mutation-route
  claims, flagged unchanged across 6 consecutive prior passes, are fixed in place.**
  `architecture-overview.md:27`: "44" → "56" (real current `grep -rl "routes do" lib/xaas
  --include="*.ex" | wc -l` count). `http-api-surface.md:75`: "44 of 49" → "56 of 69", plus
  its own now-false "every one of the 44... only get :read/index :read" claim corrected to
  "44 of those 56 now declare a real mutation route... only 12 of 56 are still read-only" —
  real-recounted this pass via a per-resource `routes do` block scan. Both edits verified by
  reading the files back after editing. Full evidence in "Thirteenth-pass update" above. Do
  not re-flag this specific figure without a fresh recount showing new drift.
- **RESOLVED (`98eeccd`, real, committed)**: the dead,
  unwired `ApprovalTierDowngradeApprove` no-op — `:approve` now really drives `Subscription
  .change_tier` (a real tier drop + real prorated `Ledger` credit), atomically. See
  "Twelfth-pass update" above. Item 16 in Create below is now marked RESOLVED.
- **NEW this pass — the remaining 4 dead-no-op `*Approve.ex` resources
  (`ApprovalQuotaOverride`, `ApprovalInvoiceReconciliationApprove`, `ApprovalCastleVerbSchedule`,
  `ApprovalK8sFaultRemediateSuggest`) are real-confirmed to have no concrete, already-built
  target to wire into — a design-decision gap, not a mechanical-wiring gap.** Full evidence
  (per-resource target hunt, all 4 negative) in "Twelfth-pass update" above. Not a bug to
  silently work around; disclosed as a standing backlog of 4 items each needing a real product/
  design decision (what does "override this org's quota" concretely mean, on what resource)
  before any code should be written. Do not mechanically force a shape onto any of these 4
  without that decision first.
- **RESOLVED (round 7, `aec265a`, verified live this pass)**: the real money-movement
  non-atomicity on `ApprovalSlaCreditApplyApprove`/`ApprovalPatchSlaCreditApplyApprove`/
  `SubscriptionProrateTierChange` — all 3 now use `after_action/2`, matching
  `ApprovalBackupRetentionChangeChargeOverage`. See "Eighth-pass update" above.
- **RESOLVED (`db17f3b`, real, committed, confirmed as this pass's own `HEAD`)**: the
  identical bug class round 7 fixed, found live on the audit-trail write in round 8 —
  `Xaas.Governance.Changes.WriteAuditLogEntry` now uses `after_action/2`, matching the other
  3. See "Tenth-pass update" above.
- **CLOSED this pass — the whole `after_transaction/2`-misused-for-a-purely-internal-write
  bug class, systematically, not just instance-by-instance.** A real
  `grep -rn "after_transaction(" lib/xaas/ --include="*.ex" | grep -v "^\s*#"` sweep (the
  exact audit this grid has been asked for across rounds 7-10) returns exactly one real call
  site in the whole codebase — `enqueue_webhook_deliveries.ex:79`, the one genuinely
  HTTP-blocking, correctly-scoped usage. Full evidence in "Tenth-pass update" above. Do not
  re-propose this bug class again absent a new `after_transaction(` call site appearing in a
  future `git log`.
- **RESOLVED (`77c7c13`, real, committed, confirmed as this pass's own `HEAD`)**: the
  test-coverage parity gap on `ApprovalBackupRetentionChangeChargeOverage` — a real,
  deterministic forced-`Ledger.Transfer`-failure test now exists
  (`test/xaas/governance/approval_backup_retention_change_test.exs`), matching its 4
  siblings. See "Eleventh-pass update" above. The atomicity-bug-class thread (rounds 7-9) is
  now closed on both axes; do not re-open without genuinely new evidence.
- **NEW this pass — 5 of the 7 round-5 (`cec5025`) `Approval*` resources' `*Approve.ex`
  Change modules are real, unwired no-ops: the `:approve` action never calls them at all.**
  `ApprovalTierDowngrade`, `ApprovalQuotaOverride`, `ApprovalInvoiceReconciliationApprove`,
  `ApprovalCastleVerbSchedule`, `ApprovalK8sFaultRemediateSuggest` all accept a mutation
  request and record who approved it, but none has any real downstream effect. Full evidence
  in "Eleventh-pass update" above. `ApprovalTierDowngrade` selected as this pass's CREATE
  item (the one of the 5 with a real, ready-built target — `Subscription.change_tier` — to
  wire into); the other 4 remain real, open, larger-scoped gaps for a future pass.
- **RESOLVED — thirteenth pass.** This bullet is historical (eighth-pass) context, preserved
  for the record; see the new "RESOLVED this pass" Raise bullet near the top of this section
  and "Thirteenth-pass update" above for the real fix (both docs corrected, "44" → "56 of
  69", plus http-api-surface.md's now-false read-only-only claim also corrected).
- **NEW this pass, minor — stale rationale comments in 2 resource files**:
  `lib/xaas/billing/approval_sla_credit_apply.ex:85` and
  `lib/xaas/billing/approval_patch_sla_credit_apply.ex:85` still say "why
  after_transaction/2," describing the pre-round-7 code. Not selected on its own.
- **Controller test coverage on 9 of 31 `Approval*` resources is still real zero — unchanged
  by this pass.** Re-verified with the same `comm -23` check: `approval_castle_verb_schedule`,
  `approval_freeze_override`, `approval_invoice_reconciliation_approve`,
  `approval_k8s_fault_remediate_suggest`, `approval_org_delete`,
  `approval_patch_sla_credit_apply`, `approval_quota_override`, `approval_sla_credit_apply`,
  `approval_tier_downgrade` — identical list to the prior grid. None of this session's 15
  commits touched these files or their tests.
- **RESOLVED this pass**: the 4 `X-Org-Id`-disclosure Governance resources' `:create`/
  `:approve` policies now authorize via `ActorOrgMatches`, not bare `always()` (see "What
  changed" above, `7320791`).
- **RESOLVED this pass**: `AshPaperTrail.Resource` change-tracking now covers 6 of 49
  resources, up from 2 (`dc7c3e9`) — the 4 Governance resources this grid's prior Raise
  section flagged as newly org-scoped-but-unaudited (`approval_backup_retention_change`,
  `approval_dr_failover`, `approval_legal_hold_release`, `approval_deployment_quarantine`)
  all now carry it. 26 of 32 real `Approval*` resources remain unaudited — real, smaller gap
  than the prior 31-of-32, not closed.
- **RESOLVED since the last pass**: the real `/internal-api/health` aggregation endpoint
  this grid's prior CREATE item selected is now real and landed (`97768fb`, see "What
  changed").
- **RESOLVED this pass**: the 7 read-only `Approval*` skeletons flagged by the fifth-pass
  grid now all carry real `:create`/`:approve` actions, a paired `*_approve.ex` change, and
  a `*_requires_approver.ex` validation (`cec5025`) — see "Sixth-pass update" above.
- **RESOLVED this pass**: controller test coverage now reaches 30 of 32 `Approval*`
  resources, each with a real `401` no-token assertion — up from 23 of 32
  (`cec5025`, see "Sixth-pass update"). Only `approval_freeze_override` and
  `approval_org_delete` remain untested — real-narrower, unchanged residual (both were
  already full maker-checker resources before this pass, so this is not a new gap).
- **NEW this pass — `Xaas.Operations.AuditLogEntry` itself carries no `AshPaperTrail.Resource`
  and its own writes are not captured by any audit mechanism.** Real-verified:
  `grep -n "AshPaperTrail" lib/xaas/operations/audit_log_entry.ex` matches only the
  moduledoc's own contrastive mention ("Distinct from AshPaperTrail...", line 4), not a real
  `use AshPaperTrail.Resource` extension or `paper_trail do ... end` block. A row in the
  audit trail that records approvals can itself be inserted, and there is no second-order
  record of who ran `mix xaas.close_coverage_gap` or any other actor-driven write against
  `AuditLogEntry` — the audit log is real and load-bearing (3 Governance `:approve` actions
  write to it, `c5fe889`) but is not itself audited, an ironic, real, freshly-found gap.
- **`priv/repo/seeds.exs` is still the unmodified book-original stub — real-verified 19
  lines, still reads "Script for populating the database... Repo.insert!(%Kanban.SomeSchema
  {})" with zero actual `Xaas.*` fixture calls.** For a 49-resource, 9-domain Ash app, there
  is no real local-dev path to a populated database short of manually driving each Ash
  action by hand — a genuine developer-experience gap, fresh this pass, distinct from and not
  covered by the concurrent sequence's remaining items.
- **NEW this pass — no single onboarding/architecture-overview doc ties the real 9-domain,
  49-resource surface together for a new reader.** See "Sixth-pass update" above for the
  real `find`/`ls` evidence. This is the largest real meta-level gap this pass surfaced: the
  session has landed AshIam, multitenancy, AshPaperTrail, `AuditLogEntry`, webhooks
  (inbound Stripe + outbound HTTP dispatch), Reactor, Ontop/R2RML, and a 3-tier
  `/internal-api` routing scheme, each documented in its own narrow explainer or moduledoc,
  with no document that says "here is the whole system and how these pieces compose."
- **`Xaas.Accounts.Org`'s `:create` authorization is still real-degraded, `:update` is now
  fixed.** `org.ex:90-98`: `:update` now uses `ActorBelongsToOrg` (closed, see "What
  changed"). `:create` remains on `actor_present()` by real, disclosed design (no
  membership can exist before the org does) — this is not a bug to fix, but it does mean
  "any authenticated actor may create any org" is still the real, current behavior; worth
  carrying forward as a known-accepted floor, not a forgotten gap.

## Create

1. **RESOLVED** (was item 1, two grids back): `ActorOrgMatches` wired onto the 4 Governance
   resources — `7320791`.
2. **RESOLVED** (was item 2, two grids back): real `AshPaperTrail` change-tracking extended
   to the 4 already-org-scoped Governance `Approval*` resources — `dc7c3e9`.
3. **RESOLVED** (was item 3 last grid): a real `/internal-api/health` aggregation
   endpoint — `97768fb`, landed by the concurrent sequence's own per-30min cadence, verified
   live this pass. See "What changed".
4. **RESOLVED** (was item 4 last grid): real `:create`/`:approve` maker-checker actions
   wired onto the 7 read-only `Approval*` skeletons — `cec5025`.
5. **RESOLVED** (was item 6 last grid): real HTTP-level controller tests for those 7,
   reaching 30 of 32 `Approval*` resources — `cec5025`.
6. **RESOLVED** (was item 6 last grid): a real top-level architecture-overview / onboarding
   doc — `docs/claude/diataxis/explanation/architecture-overview.md`, landed `d2fd0e9`.
12. **RESOLVED** (was this grid's own item 12, seventh pass): real atomic (`after_action`,
    not `after_transaction`) Ledger writes on `ApprovalSlaCreditApplyApprove`/
    `ApprovalPatchSlaCreditApplyApprove`/`SubscriptionProrateTierChange`, plus real tests
    proving a Ledger failure rolls the parent approval/tier-change back — `aec265a`, round 7,
    verified live this pass. See "Eighth-pass update" above.
13. **RESOLVED — thirteenth pass.** Re-counted and fixed the "44 of the 69"/"44 of 49" real
    HTTP-route-block/mutation-route claims in `architecture-overview.md:27` and
    `http-api-surface.md:75` against the real current `grep -rl "routes do" lib/xaas
    --include="*.ex" | wc -l` → 56, plus corrected http-api-surface.md's now-false
    read-only-only claim (44 of 56 now carry a real mutation route). See "Thirteenth-pass
    update" above.
14. **RESOLVED** (was this grid's own item 14, eighth/ninth pass): real atomic
    (`after_action`, not `after_transaction`) write of `Xaas.Operations.AuditLogEntry` from
    `Xaas.Governance.Changes.WriteAuditLogEntry`, plus a real test proving an audit-write
    failure rolls the parent `:approve` action's `approved_by` back instead of leaving it
    silently un-audited — **landed for real as `db17f3b`**, confirmed live as this pass's
    own `HEAD` (see "Tenth-pass update" above; supersedes the ninth-pass section's stale
    "uncommitted" framing).
15. **RESOLVED** (was this grid's own item 15, tenth pass): real forced-`Ledger.Transfer`-
    failure atomicity regression test for
    `Xaas.Governance.Changes.ApprovalBackupRetentionChangeChargeOverage` —
    **landed for real as `77c7c13`**, confirmed live as this pass's own `HEAD`
    (`test/xaas/governance/approval_backup_retention_change_test.exs`, new, 132 lines). See
    "Eleventh-pass update" above. This closes the entire atomicity-bug-class thread
    (rounds 7-9) on both the correctness axis (tenth pass) and the test-coverage axis (this
    fact, confirmed this pass).
16. **RESOLVED** (was this grid's own item 16, eleventh pass): `Xaas.Billing
    .ApprovalTierDowngrade`'s `:approve` action now really drives `Xaas.Billing.Subscription`'s
    `:change_tier` action (a real tier drop + real prorated `Ledger` credit, atomically) —
    **landed for real as `98eeccd`**, confirmed live as this pass's own `HEAD`. See
    "Twelfth-pass update" above.
17. **The 4 remaining dead-no-op `*Approve.ex` resources
    (`ApprovalQuotaOverride`/`ApprovalInvoiceReconciliationApprove`/
    `ApprovalCastleVerbSchedule`/`ApprovalK8sFaultRemediateSuggest`) are real-confirmed
    design-decision-blocked, not mechanically wirable** — this pass real-hunted a target for
    each and found none (see "Twelfth-pass update" and Raise above). Not a CREATE candidate
    until a real product decision names each one's real target resource/attribute; disclosed
    here so a future pass doesn't have to re-derive the same negative result from scratch.
7. **`Xaas.Resource.MakerChecker` shared DSL fragment** — unchanged from the prior grid,
   still real and still not done: no file matching `*maker_checker*` exists anywhere in
   `lib/xaas`, and all 32 `Approval*` resources now hand-carry the identical policy block
   this item would extract (see Reduce) — item 4's landing added 7 more duplicated
   instances of that shape, strengthening rather than weakening the case for this next.
8. **Extend `ActorBelongsToOrg`-style user-membership authorization past `Org` itself** —
   unchanged from the prior grid; still used on exactly one resource/action
   (`Org`, `:update`).
9. **Real `AshPaperTrail.Resource` (or equivalent second-order audit) on
   `Xaas.Operations.AuditLogEntry` itself** — carried forward from the fifth-pass grid,
   real-reconfirmed this pass (see Raise): still not touched by `cec5025` or the concurrent
   sequence's prompt 21. A close second to item 6 this pass.
10. **Real `identities do` uniqueness constraints across the 69 resources are thin**: real-
    verified this pass `grep -rl "identities do" lib/xaas | wc -l` → 8 of 69 resources
    (denominator corrected this pass — 49 was the pre-growth resource-surface total).
    `Xaas.Marketplace.ApprovalProviderStatusChange` still has no `identities do` block
    guarding against a duplicate *pending* status-change request for the same
    `provider_id`. Carried forward, not selected this pass.
11. **RESOLVED** (was this grid's own item 11, twelfth pass): a real `priv/repo/seeds.exs`
    populated with `Xaas.*` fixtures for local dev, via new `lib/xaas/dev_seeds.ex` —
    **landed for real as `e90d478`**, confirmed live as `wc -l priv/repo/seeds.exs` → 45,
    `Xaas.DevSeeds` module read in full this pass. See "Thirteenth-pass update" above.
18. **Selected as this pass's CREATE item.** A real `newly_approved?/2` guard on
    `Xaas.Governance.Changes.ApprovalBackupRetentionChangeChargeOverage`, matching the exact
    pattern already proven in its 2 Billing siblings — closing a real, live-run-verified
    double-charge bug on re-approval of the same record (`-$6.00` → `-$12.00` across 2
    `:approve` calls, real-reproduced this pass with a temporary, deleted-after-run test).
    Full spec in the structured output below.

## See Also

- `lib/xaas/governance/changes/approval_backup_retention_change_charge_overage.ex:29-45`
  (the real, unguarded `change/3`), `lib/xaas/billing/changes/approval_sla_credit_apply_approve.ex:75-90`
  and `approval_patch_sla_credit_apply_approve.ex` (the real `newly_approved?/2` pattern this
  pass's selected CREATE item — item 18 — extends), `lib/xaas/billing/subscription.ex:226-233`
  and `lib/xaas/billing/validations/subscription_change_tier_not_no_op.ex` (the real, different
  mechanism that incidentally protects `ApprovalTierDowngrade`'s equivalent path, checked and
  confirmed this pass), `test/xaas/governance/approval_backup_retention_change_test.exs`,
  `test/kanban_web/controllers/approval_backup_retention_change_controller_test.exs` (the real,
  confirmed-empty existing coverage of the re-approval scenario) — this pass's own
  live-run-verified double-charge finding and its selected fix target
- `lib/xaas/dev_seeds.ex`, `priv/repo/seeds.exs`, `test/xaas/dev_seeds_test.exs` — round 11's
  real, landed implementation (`e90d478`) of the twelfth pass's own CREATE item (item 11),
  independently re-verified this pass
- `docs/claude/diataxis/explanation/architecture-overview.md:27`,
  `docs/claude/diataxis/reference/http-api-surface.md:75` — the real "44 of 69"/"44 of 49"
  route-count and read-only-only claims this pass fixed in place (item 13), after 6+
  consecutive passes carrying the same unfixed drift
- `docs/COVERAGE-TREND-2026-08-21.md` — the separate Measure-phase standing activity's own
  real `mix xaas.capability_coverage` 3-run report (`cf233af`), read for this pass's own
  75-total-resource denominator cross-check, not this ERRC cron's own output
- `lib/xaas/billing/approval_tier_downgrade.ex`,
  `lib/xaas/billing/changes/approval_tier_downgrade_approve.ex`,
  `lib/xaas/billing/validations/approval_tier_downgrade_targets_lower_tier.ex`,
  `lib/xaas/billing/subscription.ex:226-236`,
  `lib/xaas/billing/changes/subscription_prorate_tier_change.ex`,
  `test/xaas/billing/approval_tier_downgrade_test.exs` — the real dead no-op change module
  and its ready-built real target the eleventh pass's CREATE item (item 16) wired together,
  landed for real as `98eeccd` this round
- `lib/xaas/billing/changes/approval_quota_override_approve.ex`,
  `lib/xaas/billing/changes/approval_invoice_reconciliation_approve_approve.ex`,
  `lib/xaas/operations/changes/approval_castle_verb_schedule_approve.ex`,
  `lib/xaas/operations/changes/approval_k8s_fault_remediate_suggest_approve.ex` — the 4
  remaining real, unwired no-op `*Approve.ex` modules; this round real-hunted a target for
  each (item 17) and confirmed none exists yet (design-decision-blocked, not a CREATE
  candidate)
- `lib/xaas/billing/approval_pricing_override.ex` (its `AshRateLimiter`/`Xaas.Hammer`
  `rate_limit do` block), `lib/xaas/billing/subscription.ex:1-59` (its own moduledoc's
  explicit "6 Approval* resources presume a subscription already exists" scoping),
  `lib/xaas/operations/castle_verb_inventory_goals.ex`,
  `castle_verb_inventory_components.ex`, `castle_verb_fortune5_requirements.ex` — the real
  near-miss candidates this pass's target hunt for the 4 design-blocked resources checked and
  rejected (a same-word-different-concept rate limiter; 3 read-only catalog siblings with no
  mutation surface)
- `lib/xaas/operations/audit_log_entry.ex` — real-examined this pass for the `AshPaperTrail`
  CREATE candidate (item 9) and found genuinely thin (its `actions do` block has no
  `:update`/`:destroy` at all, so there is nothing for `AshPaperTrail` to diff); downgraded in
  priority, not selected, not retracted as a real gap
- `priv/repo/seeds.exs`, `lib/xaas/accounts/org.ex:132-143`,
  `lib/xaas/billing/subscription.ex:170-194` — this round's selected CREATE item (item 11) and
  the real `:create` action signatures its spec is grounded in
- `lib/xaas/governance/changes/approval_backup_retention_change_charge_overage.ex`,
  `test/xaas/billing/approval_sla_credit_apply_test.exs:150-183`,
  `test/xaas/governance/approval_backup_retention_change_test.exs`,
  `test/xaas/governance/approval_backup_retention_change_stress_test.exs`,
  `test/kanban_web/controllers/approval_backup_retention_change_controller_test.exs` — the
  real atomic exemplar whose test-parity gap round 9 (`77c7c13`) closed, and the
  deterministic same-account forced-failure technique it reuses verbatim
- `docs/claude/diataxis/explanation/architecture-overview.md` — the sixth-pass Create item
  this grid identified: the whole-system onboarding map that previously did not exist; its
  own "44 of the 69" route-count claim (line 27) has drifted from current code and is still
  unfixed as of this pass
- `lib/xaas/governance/changes/approval_backup_retention_change_charge_overage.ex`,
  `lib/xaas/billing/changes/approval_sla_credit_apply_approve.ex`,
  `lib/xaas/billing/changes/approval_patch_sla_credit_apply_approve.ex`,
  `lib/xaas/billing/changes/subscription_prorate_tier_change.ex`,
  `lib/xaas/ledger/account.ex` — the real atomic Ledger-write pattern round 7 (`aec265a`)
  landed; the pattern this pass's own selected CREATE item (item 14) extends to the
  audit-trail write
- `lib/xaas/governance/changes/write_audit_log_entry.ex`,
  `lib/xaas/governance/changes/enqueue_webhook_deliveries.ex`,
  `lib/xaas/operations/audit_log_entry.ex`,
  `test/xaas/governance/audit_log_entry_test.exs` — the real `after_transaction/2`
  over-generalization this pass found on the audit-trail write, the correctly-scoped
  `after_transaction/2` sibling it was (wrongly) generalized from, and the zero-coverage
  test file item 14's spec targets
- `lib/mix/tasks/xaas.safe_generate_migrations.ex`,
  `priv/repo/migrations/20260821055848_resolve_pending_backlog_20260821.exs` — the real,
  disclosed cross-table migration hazard and the now-FMEA-hardened (`6fdca0c`) forward-
  looking guard against its recurrence; the migration itself is historical, not a live edit
  target (see "Eighth-pass update")
- `docs/ASH-MIGRATION-PLAN.md` — the real 7-phase migration history and standing deferred
  decisions this grid builds on
- `docs/claude/diataxis/reference/http-api-surface.md` — the real, current HTTP route
  enumeration referenced above; its own line 75 "44 of 49" count is the real, traced source
  of this pass's found route-count drift
- `docs/claude/diataxis/explanation/ashiam-create-update-limitation.md` — the real,
  investigated root cause for why `AshIam.Check` still can't be used on `:create`/`:update`
  anywhere in this repo, cited throughout this revision
- `docs/AWS-CHAPTERS-SUBSTITUTION.md` — the disclosed `FixtureAdapter` exception cited in
  Eliminate
- `lib/xaas/accounts/org.ex`, `lib/xaas/accounts/org_membership.ex`,
  `lib/xaas/accounts/checks/actor_belongs_to_org.ex`,
  `lib/xaas/marketplace/checks/actor_org_matches.ex`,
  `lib/xaas/governance/checks/actor_org_matches.ex`,
  `lib/xaas/marketplace/checks/actor_org_filter.ex`,
  `lib/xaas/marketplace/approval_provider_status_change.ex`,
  `lib/xaas/governance/approval_freeze_override.ex` (the real `AshPaperTrail.Resource`
  precedent 4 more Governance resources adopted in `dc7c3e9`),
  `lib/kanban_web/plugs/resolve_org_actor.ex`, `lib/kanban_web/router.ex:57-62` (the real
  `/internal-api` route surface this revision's selected Create item extends),
  `priv/repo/seeds.exs` — the real resources/checks/plugs/gaps this revision's "What
  changed" and Create sections verify against
