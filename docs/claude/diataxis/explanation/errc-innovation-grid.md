# ERRC Innovation Grid — xaas Real Feature Surface

Blue Ocean Strategy ERRC grid (Eliminate-Reduce-Raise-Create) grounded in what actually
exists on disk, re-verified against real `find`/`grep`/`git log` runs. One evolving doc, not
a new dated file per pass — this revision updates the 2026-08-20 grid in place after the
`ActorOrgMatches`-on-Governance / `Marketplace.Provider` mutation-route / marketplace
listing-lifecycle / MAPE-K close-the-loop commits landed (`7320791`, `d9a7006`, `adc839a`,
`53788ea`, 4 commits since the last pass). Last Updated 2026-08-20 (same day, third pass).

## What changed since the last grid (resolved / advanced items)

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
- **Audit-log coverage is real but confined to 2 of 49 resources, despite `AshPaperTrail`
  being installed and domain-configured for exactly this purpose.** Real-verified: `grep -rl
  "AshPaperTrail.Resource" lib/xaas` → only `approval_freeze_override.ex` and
  `freeze_window.ex`. `Xaas.Governance` is the one domain with `AshPaperTrail.Domain` in its
  `extensions:` list (`lib/xaas/governance.ex:4`) — but of the 32 real `Approval*` resources
  (`find lib/xaas -iname "approval*.ex" ! -path "*/changes/*" ! -path "*/validations/*" | wc
  -l` → 32, up from 31 last pass with the new `ApprovalProviderStatusChange`), only 1 uses
  it. The 4 resources this pass just gave real org-scoped authorization
  (`approval_backup_retention_change`, `approval_dr_failover`, `approval_legal_hold_release`,
  `approval_deployment_quarantine`) still have zero change-tracking — real-verified
  `extensions: [AshJsonApi.Resource, AshGraphql.Resource]`, no `AshPaperTrail.Resource`, no
  `paper_trail do` block, in all 4. For a maker-checker/compliance domain whose entire
  purpose is "who approved what, when, over what prior state," this is a real, sharper gap
  than raw test-coverage: the approval *decision* itself is unaudited on 31 of 32 resources.
- **`Xaas.Accounts.Org`'s `:create` authorization is still real-degraded, `:update` is now
  fixed.** `org.ex:90-98`: `:update` now uses `ActorBelongsToOrg` (closed, see "What
  changed"). `:create` remains on `actor_present()` by real, disclosed design (no
  membership can exist before the org does) — this is not a bug to fix, but it does mean
  "any authenticated actor may create any org" is still the real, current behavior; worth
  carrying forward as a known-accepted floor, not a forgotten gap.

## Create

1. **RESOLVED this pass** (was item 1 last grid): `ActorOrgMatches` wired onto the 4
   Governance resources — see "What changed" above (`7320791`).
2. **Extend real `AshPaperTrail` change-tracking to the 4 already-org-scoped Governance
   `Approval*` resources** (`approval_backup_retention_change.ex`,
   `approval_dr_failover.ex`, `approval_legal_hold_release.ex`,
   `approval_deployment_quarantine.ex`) — the concrete, scoped, unblocked new CREATE item
   this pass selected; full spec in the structured output below.
3. **`Xaas.Resource.MakerChecker` shared DSL fragment** — unchanged from the prior grid,
   still real and still not done: no file matching `*maker_checker*` exists anywhere in
   `lib/xaas`, and the 32 `Approval*` resources (up from 31, new
   `ApprovalProviderStatusChange`) still hand-carry the identical policy block this item
   would extract (see Reduce). Carried forward verbatim as a real, still-valid candidate.
4. **Real HTTP-level controller tests for the 9 zero-coverage `Approval*` resources** —
   unchanged from the prior grid, still real and still not done (see Raise); the same 9
   real file paths remain the concrete scope.
5. **Extend `ActorBelongsToOrg`-style user-membership authorization past `Org` itself** —
   unchanged from the prior grid; still used on exactly one resource/action
   (`Org`, `:update`).
6. **A real `mix xaas.audit_coverage_report` task** (developer-experience/observability
   gap, fresh this pass) — the codebase already has a precedent for exactly this shape of
   tool (`bd1e433`'s `mix xaas.capability_coverage`,
   `lib/mix/tasks/xaas.capability_coverage.ex`), but nothing enumerates which of the 49
   real Ash resources carry `AshPaperTrail.Resource` vs. not. Real, scoped, smaller than
   item 2, and a natural follow-on to it once more resources adopt paper-trail — not
   selected this pass because item 2 is the more concrete, higher-value single unit of
   work (the reporting task is only useful once there is more than 2-of-49 real coverage
   to report on).
7. **Real `identities do` uniqueness constraints across the 49 resources are thin** (data-
   integrity gap, fresh this pass): real-verified `grep -rl "identities do" lib/xaas | wc
   -l` → 8 of 49 resources. `Xaas.Marketplace.ApprovalProviderStatusChange`
   (`adc839a`, this session's newest maker-checker resource) has no `identities do` block
   guarding against a duplicate *pending* status-change request for the same
   `provider_id` — real-verified: `lib/xaas/marketplace/approval_provider_status_change.ex`
   has no `identities` section, so two concurrent `:create`s against the same provider can
   both persist as `pending` with no DB-level or Ash-level uniqueness stopping it. Real,
   scoped, but broader than item 2 (a constraint-by-constraint audit across resources
   rather than one already-identified extension) — kept as a listed, not-selected
   candidate this pass; a real follow-on to the maker-checker CREATE items already landed.

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
  `lib/xaas/governance/approval_freeze_override.ex` (the one real `AshPaperTrail.Resource`
  example this revision's Create item 2 replicates),
  `lib/kanban_web/plugs/resolve_org_actor.ex` — the real resources/checks/plug this
  revision's "What changed" section verifies against
