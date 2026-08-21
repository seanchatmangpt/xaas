# ERRC Innovation Grid — xaas Real Feature Surface

Blue Ocean Strategy ERRC grid (Eliminate-Reduce-Raise-Create) grounded in what actually
exists on disk, re-verified against real `find`/`grep`/`git log` runs. One evolving doc, not
a new dated file per pass — this revision updates the 2026-08-20 grid in place after this
pass's own real-verified commits and the concurrently-running 25-prompt sequence's real
landings since the fourth pass (`97768fb` health-check aggregation endpoint — closes this
grid's own prior #3 CREATE item; `c5fe889` real cross-resource `AuditLogEntry` audit trail;
`c03669c`/`c03fc9c` e2e negative-path hardening; `9caa85d` real k8s NetworkPolicy
application). Last Updated 2026-08-20 (same day, seventh pass).

## Seventh-pass update (this revision)

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

- **NEW this pass — real money-movement non-atomicity on 3 of the newest Ledger-writing
  changes** (`ApprovalSlaCreditApplyApprove`, `ApprovalPatchSlaCreditApplyApprove`,
  `SubscriptionProrateTierChange`, all wired via `after_transaction/2` instead of the
  atomic `after_action/2` their own sibling `ApprovalBackupRetentionChangeChargeOverage`
  correctly uses) — full evidence in "Seventh-pass update" above. Selected as this pass's
  CREATE item.
- **NEW this pass — `architecture-overview.md:27`'s "44 of the 69" real HTTP-route-block
  claim does not match current code** (`grep -rl "routes do" lib/xaas --include="*.ex" | wc
  -l` → 56); the "44" figure traces to `http-api-surface.md:75`'s own stale "44 of 49"
  count from before the domain surface grew to 69 resources. Both reference docs need a
  real re-count pass; not selected as this pass's CREATE item since it is a doc fix, not a
  feature — full evidence above.
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
12. **Real atomic (`after_action`, not `after_transaction`) Ledger writes on
    `ApprovalSlaCreditApplyApprove`/`ApprovalPatchSlaCreditApplyApprove`/
    `SubscriptionProrateTierChange`, plus real tests proving a Ledger failure rolls the
    parent approval/tier-change back instead of leaving it silently uncredited/uncharged** —
    the fresh, concrete, scoped CREATE item this pass selected; full spec in the structured
    output below.
13. **Re-count and fix the "44 of the 69"/"44 of 49" real HTTP-route-block claims in
    `architecture-overview.md:27` and `http-api-surface.md:75`** against the real current
    `grep -rl "routes do" lib/xaas --include="*.ex" | wc -l` → 56 — fresh this pass, a doc
    fix rather than a feature so not selected over item 12.
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
10. **Real `identities do` uniqueness constraints across the 49 resources are thin**: real-
    verified `grep -rl "identities do" lib/xaas | wc -l` → 8 of 49 resources.
    `Xaas.Marketplace.ApprovalProviderStatusChange` still has no `identities do` block
    guarding against a duplicate *pending* status-change request for the same
    `provider_id`. Carried forward, not selected this pass.
11. **A real `priv/repo/seeds.exs` populated with `Xaas.*` fixtures for local dev** —
    unchanged from the prior grid: still the unmodified 19-line book stub with zero
    `Xaas.*` calls. Carried forward, not selected this pass.

## See Also

- `docs/claude/diataxis/explanation/architecture-overview.md` — the sixth-pass Create item
  this grid identified: the whole-system onboarding map that previously did not exist; this
  pass found its own "44 of the 69" route-count claim (line 27) has drifted from current code
- `lib/xaas/governance/changes/approval_backup_retention_change_charge_overage.ex`,
  `lib/xaas/billing/changes/approval_sla_credit_apply_approve.ex`,
  `lib/xaas/billing/changes/approval_patch_sla_credit_apply_approve.ex`,
  `lib/xaas/billing/changes/subscription_prorate_tier_change.ex`,
  `lib/xaas/ledger/account.ex` — the real atomic-vs-non-atomic Ledger-write split and the
  real unique-constraint race this pass's selected CREATE item fixes
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
