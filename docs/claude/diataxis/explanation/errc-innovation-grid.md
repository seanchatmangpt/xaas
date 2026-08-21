# ERRC Innovation Grid — xaas Real Feature Surface

Blue Ocean Strategy ERRC grid (Eliminate-Reduce-Raise-Create) grounded in what actually
exists on disk, re-verified against real `find`/`grep`/`git log` runs. One evolving doc, not
a new dated file per pass — this revision updates the 2026-08-20 grid in place after this
pass's own real-verified commits and the concurrently-running 25-prompt sequence's real
landings since the fourth pass (`97768fb` health-check aggregation endpoint — closes this
grid's own prior #3 CREATE item; `c5fe889` real cross-resource `AuditLogEntry` audit trail;
`c03669c`/`c03fc9c` e2e negative-path hardening; `9caa85d` real k8s NetworkPolicy
application). Last Updated 2026-08-20 (same day, fifth pass).

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
- **NEW this pass — 7 of 32 `Approval*` resources are not real maker-checker resources at
  all, just read-only skeletons.** Real-verified by reading all 7 files this pass's own
  `comm -23` diff identified (the same 9 resources the prior grid flagged as zero
  controller-test-coverage, minus the 2 — `approval_freeze_override`, `approval_org_delete`
  — that do carry a real `*RequiresApprover` self-approval-rejection validation):
  `approval_castle_verb_schedule.ex`, `approval_invoice_reconciliation_approve.ex`,
  `approval_k8s_fault_remediate_suggest.ex`, `approval_patch_sla_credit_apply.ex`,
  `approval_quota_override.ex`, `approval_sla_credit_apply.ex`,
  `approval_tier_downgrade.ex` — every one of the 7 has `actions do defaults [:read] end`
  (line 43-45 in each, byte-identical) and nothing else: no `:create`, no `:approve`, no
  `validations do` block, only the deny-by-default `policies do bypass action_type(:read)
  ... policy always() do forbid_if always() end end` floor. This is the real root cause the
  prior grid's "9 resources, zero controller tests" finding was pointing at without naming
  it: there is no maker-checker action to test or to self-approval-guard on these 7, because
  the mutation actions were never written. `approval_org_delete.ex` and
  `approval_freeze_override.ex` (the other 2 of the original 9) are real, full maker-checker
  resources with `:create`/`:approve` actions and a wired `*RequiresApprover` validation —
  they just lack HTTP-level controller tests, a narrower, already-flagged gap.
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
4. **Wire real `:create`/`:approve` maker-checker actions onto the 7 `Approval*` resources
   that are currently read-only skeletons** — the concrete, scoped, fresh CREATE item this
   pass selected; full spec in the structured output below.
5. **`Xaas.Resource.MakerChecker` shared DSL fragment** — unchanged from the prior grid,
   still real and still not done: no file matching `*maker_checker*` exists anywhere in
   `lib/xaas`, and the 32 `Approval*` resources still hand-carry the identical policy block
   this item would extract (see Reduce). Carried forward verbatim as a real, still-valid
   candidate; item 4 above will hand-write 7 more instances of that same duplicated shape
   before this item is picked, which strengthens rather than weakens the case for it next.
6. **Real HTTP-level controller tests for the (now real) `:approve` action on the 7
   resources item 4 wires up, plus the 2 already-complete-but-untested resources
   (`approval_freeze_override`, `approval_org_delete`)** — narrowed from the prior grid's
   9-resource framing now that the root cause (item 4) is understood; carried forward, not
   selected this pass because it depends on item 4 landing first.
7. **Extend `ActorBelongsToOrg`-style user-membership authorization past `Org` itself** —
   unchanged from the prior grid; still used on exactly one resource/action
   (`Org`, `:update`).
8. **Real `AshPaperTrail.Resource` (or equivalent second-order audit) on
   `Xaas.Operations.AuditLogEntry` itself** — fresh this pass (see Raise): the audit trail
   that 3 Governance `:approve` actions write to is not itself audited. Real, scoped,
   genuinely new — not proposed by any prior grid pass or by the concurrent sequence (whose
   own `AuditLogEntry` commit, `c5fe889`, did not add this). A close second to item 4 this
   pass: item 4 is the sharper gap because it is a real, exploitable maker-checker floor
   (no self-approval guard is possible when there's no `:approve` action at all yet), while
   this item is a defense-in-depth gap on an already-real, already-working feature.
9. **Real `identities do` uniqueness constraints across the 49 resources are thin**: real-
   verified `grep -rl "identities do" lib/xaas | wc -l` → 8 of 49 resources.
   `Xaas.Marketplace.ApprovalProviderStatusChange` still has no `identities do` block
   guarding against a duplicate *pending* status-change request for the same
   `provider_id`. Carried forward, not selected this pass.
10. **A real `priv/repo/seeds.exs` populated with `Xaas.*` fixtures for local dev** —
    unchanged from the prior grid: still the unmodified 19-line book stub with zero
    `Xaas.*` calls. Carried forward, not selected this pass.

## See Also

- `docs/ASH-MIGRATION-PLAN.md` — the real 7-phase migration history and standing deferred
  decisions this grid builds on
- `docs/claude/diataxis/reference/http-api-surface.md` — the real, current HTTP route
  enumeration referenced above
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
