# ERRC Innovation Grid — xaas Real Feature Surface

Blue Ocean Strategy ERRC grid (Eliminate-Reduce-Raise-Create) grounded in what actually
exists on disk, re-verified against real `find`/`grep`/`git log` runs. One evolving doc, not
a new dated file per pass — this revision updates the 2026-08-20 grid in place after the
`OrgMembership` / per-org tenant-actor / `AshIam` root-cause commits landed (`d2f2ad6`
through `7bea457`, 15 commits). Last Updated 2026-08-20 (same day, later pass).

## What changed since the last grid (resolved / advanced items)

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
- **The 4 `X-Org-Id`-disclosure Governance resources now have a real per-org actor
  (`ResolveOrgActor`) AND real strict multitenancy — but their `:create`/`:approve` policies
  still authorize on bare `always()`, not the new actor.** Real-verified in
  `approval_dr_failover.ex:26-30` (and byte-identical in the other 3): `bypass
  action(:create) do authorize_if always() end` / `bypass action(:approve) do authorize_if
  always() end` — unconditional, ignoring the real `%{org_id: ...}` actor
  `ResolveOrgActor` now attaches to every request on these exact 4 paths. This is a materially
  *sharper* raise item than the prior grid's version: the plumbing prerequisite the prior
  grid said didn't exist ("no single authenticated current actor struct... matching
  `OrgMembership`'s `user_id`") is now real for the org-level case — `ActorOrgMatches`
  already proves the pattern works end-to-end on `Provider`. These 4 resources are the
  real, scoped, unblocked next step, not a rebuild.
- **`Xaas.Accounts.Org`'s `:create` authorization is still real-degraded, `:update` is now
  fixed.** `org.ex:90-98`: `:update` now uses `ActorBelongsToOrg` (closed, see "What
  changed"). `:create` remains on `actor_present()` by real, disclosed design (no
  membership can exist before the org does) — this is not a bug to fix, but it does mean
  "any authenticated actor may create any org" is still the real, current behavior; worth
  carrying forward as a known-accepted floor, not a forgotten gap.

## Create

1. **Wire `Xaas.Marketplace.Checks.ActorOrgMatches` (or an equivalent Governance-domain
   check reusing its exact `%{org_id: actor_org_id}` real changeset/record-comparison logic)
   onto the 4 Governance resources' `:create` and `:approve` policies** —
   `approval_backup_retention_change.ex:27-33`, `approval_dr_failover.ex:26-32`,
   `approval_legal_hold_release.ex:25-31`, `approval_deployment_quarantine.ex:42-48` —
   replacing each resource's current `authorize_if always()` on those two actions. This is
   the concrete, unblocked follow-through the prior grid's Raise item pointed at but called
   "not done": the actor (`ResolveOrgActor`), the multitenancy wiring (`global? false`,
   strictly enforced this pass), and the real, already-proven check pattern
   (`ActorOrgMatches`, live on `Provider`) all now exist independently — only the wiring
   across the two remaining places is net-new. Full spec in the structured output below.
2. **`Xaas.Resource.MakerChecker` shared DSL fragment** — unchanged from the prior grid,
   still real and still not done: no file matching `*maker_checker*` exists anywhere in
   `lib/xaas`, and the 31 `Approval*` resources still hand-carry the identical policy block
   this item would extract (see Reduce). Carried forward verbatim as a real, still-valid
   CREATE candidate.
3. **Real HTTP-level controller tests for the 9 zero-coverage `Approval*` resources** —
   unchanged from the prior grid, still real and still not done (see Raise); the same 9
   real file paths remain the concrete scope.
4. **Extend `ActorBelongsToOrg`-style user-membership authorization past `Org` itself** — the
   check is real and landed but is used on exactly one resource (`Org`, `:update` only).
   None of the 31 `Approval*` resources or `OrgMembership` itself (whose own moduledoc
   explicitly defers create/update/destroy authorization: `org_membership.ex:14-18`, "no
   bypass exists yet for create/update/destroy on membership rows themselves") use a real
   membership check yet. Real, scoped, but larger than item 1 above (touches many
   resources' actor-resolution story, not 4 already-plumbed ones) — kept as a listed but
   not-selected candidate this pass.

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
  `lib/kanban_web/plugs/resolve_org_actor.ex` — the real resources/checks/plug this
  revision's "What changed" section verifies against
