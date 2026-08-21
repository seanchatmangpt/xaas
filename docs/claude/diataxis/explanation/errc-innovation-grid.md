# ERRC Innovation Grid — xaas Real Feature Surface

Blue Ocean Strategy ERRC grid (Eliminate-Reduce-Raise-Create) grounded in what actually
exists on disk on 2026-08-20, not generic SaaS advice. Verified with real `find`/`wc -l`/
`grep` runs over `lib/xaas/` and `test/`, and by reading real resource source and moduledocs
cited below. Last Updated 2026-08-20.

## Eliminate

- **`lib/xaas/autofde/status_parser.ex`** (155 lines, the entire `autofde` domain's real code
  footprint — no `Xaas.Autofde` domain module exists in `lib/xaas.ex`'s domain list, and no
  other file lives under `lib/xaas/autofde/`). A single free-standing parser module with no
  Ash resource, no domain wiring, no HTTP route, and (per the earlier grep) zero
  `test/xaas/autofde/` directory. It is real code but currently unreachable from any real
  request path — a real candidate to either delete or actually wire into a domain; carrying
  it as dead weight adds a stale top-level directory to `lib/xaas/` for no current value.
- **`lib/kanban/aws_repo/fixture_adapter.ex`** — the one disclosed, permanent exception to
  this repo's no-mocking discipline (`docs/AWS-CHAPTERS-SUBSTITUTION.md`). It is explicitly
  legacy book scaffolding kept only because chapters were substituted with `colima`+`kind`;
  it is not a candidate for new investment and should not gain a second sibling (per
  `CLAUDE.md`'s explicit warning), but is flagged here because its continued presence is a
  real, standing maintenance liability every new contributor has to learn to route around.

## Reduce

- **The 31 top-level `Approval*` resources** (real count: `find lib/xaas -iname
  "approval*.ex" ! -path "*/changes/*" ! -path "*/validations/*"` → 31, spanning
  `lib/xaas/billing/` (6), `lib/xaas/governance/` (23), `lib/xaas/operations/` (2)) are a
  near-identical maker-checker shape copy-pasted 31 times: same `policies do bypass
  action_type(:read) ... bypass action(:create) ... bypass action(:approve) ...  policy
  always() do forbid_if always() end end` block, same `org_id`/`requested_by`/`approved_by`/
  `reason` attribute shape, same paired `Approval*RequiresApprover` validation module in
  `lib/xaas/{billing,governance}/validations/`, same paired `Approval*Approve` change module
  in `lib/xaas/{billing,governance}/changes/`. Compare
  `lib/xaas/governance/approval_freeze_override.ex` (119 lines) against
  `lib/xaas/billing/approval_pricing_override.ex` (99 lines): same policy block verbatim,
  same `approve` action shape, different field names only. This is real, over-built
  duplication relative to real value — 31 independent files (plus 31 paired validations +
  ~11 paired changes = 60+ files) hand-carrying one real pattern. A shared
  `Xaas.Resource.MakerChecker` extension/fragment (an Ash `Spark.Dsl.Fragment` or a
  `use`-able macro supplying the policy block + standard attributes) would cut duplication
  without changing behavior — a real reduce candidate, not a rewrite.
- **Per-resource `freeze_window_id`/similar foreign-key-shaped string attributes** — the
  freeze_override moduledoc itself documents the pattern repo-wide: "Kept as a plain string
  id (not a `belongs_to`) to match this domain's existing Governance resources, none of which
  cross-reference each other via Ash relationships" (`approval_freeze_override.ex:100-103`).
  31 resources independently re-implement loose string FKs instead of one real
  `belongs_to`/`has_many` pattern — real, already-built duplication of a integrity gap, not
  just style.

## Raise

- **Controller test coverage on 9 of 31 `Approval*` resources is real zero.** Verified: `comm
  -23` between the 31 real approval resource basenames and the real
  `test/kanban_web/controllers/*_controller_test.exs` basenames returns exactly 9 with no
  controller test: `approval_castle_verb_schedule`, `approval_freeze_override`,
  `approval_invoice_reconciliation_approve`, `approval_k8s_fault_remediate_suggest`,
  `approval_org_delete`, `approval_patch_sla_credit_apply`, `approval_quota_override`,
  `approval_sla_credit_apply`, `approval_tier_downgrade`. Real, already-present capability
  (the resource, its JSON:API route, its approve action) with no real HTTP-level test
  proving the route actually works — the exact class of gap `docs/ASH-MIGRATION-PLAN.md` and
  `security-and-testing-decisions.md` describe adversarial review catching before.
- **Per-org authentication on the multitenancy path is a real, repeatedly self-disclosed
  gap.** Four governance resources' moduledocs carry the identical disclosed sentence
  verbatim — `approval_backup_retention_change.ex:75`, `approval_dr_failover.ex:75`,
  `approval_legal_hold_release.ex:74`, `approval_deployment_quarantine.ex:91` — all saying
  `X-Org-Id` (resolved by `KanbanWeb.Plugs.ResolveOrgActor`) is "caller-asserted, not
  cryptographically authenticated." This is real, already-shipped multitenancy
  (`multitenancy do strategy :attribute; attribute :org_id; global? false end`) sitting on an
  unauthenticated header — a strengthen-not-rebuild target: the scoping mechanism exists, the
  authentication of the org claim does not.
- **`Xaas.Accounts.Org`'s create/update authorization is explicitly named as degraded.**
  `lib/xaas/accounts/org.ex:60-84`: `AshIam.Check` works on `:read` but real-tested Forbidden
  on `:create`/`:update` for reasons "not fully diagnosed within this session's time budget,"
  so create/update currently fall back to the weaker `actor_present()` condition instead of
  real per-org IAM authorization. A real, already-scoped root-cause task (single resource,
  documented repro) rather than new design work.

## Create

1. **`Xaas.Accounts.OrgMembership`** — the resource `org.ex`'s own moduledoc says doesn't
   exist yet: "Org has no membership/ownership relationship modeled yet (see moduledoc:
   multitenancy wiring is real, disclosed follow-up work)" (`org.ex:78-80`), and separately
   that the eventual mechanism should be Ash's built-in `multitenancy` DSL wired per resource
   "going forward," not yet done ( `org.ex:14-18`). Today every one of the 31+ `Approval*`
   and other domain resources carries a loose, unvalidated `org_id` string with zero real
   relationship or membership check — `actor_present()` is the strongest condition any policy
   can express because no fact like "this actor belongs to this org" exists anywhere in the
   schema. `OrgMembership` (user_id, org_id, role) closes exactly the gap both `org.ex` and
   the four `X-Org-Id`-disclosure resources independently point at, and unlocks a real
   `actor_belongs_to_org()` custom Ash check usable across the whole `Approval*` surface
   instead of the current `actor_present()`/global-bypass floor.
2. **A shared maker-checker DSL fragment** (`Xaas.Resource.MakerChecker`, a Spark DSL
   fragment or macro) extracted from the 31 real, near-identical `Approval*` policy blocks
   (see Reduce above) — not a generic "add an abstraction" gesture but a concrete extraction
   of the exact repeated block in `approval_freeze_override.ex:29-45` /
   `approval_pricing_override.ex`'s equivalent, parameterized on the resource's attribute
   names. This is CREATE (new shared infrastructure), not REDUCE, because it is net-new code
   that doesn't exist today, even though its purpose is to reduce the 31-way duplication.
3. **Real HTTP-level controller tests for the 9 zero-coverage `Approval*` resources named in
   Raise** — not "add more tests" as a generic gesture, but a concrete, enumerated,
   already-scoped list of 9 real files to add (`test/kanban_web/controllers/
   approval_castle_verb_schedule_controller_test.exs` and the other 8 named above), each
   following the exact `Xaas.Governance.Validations.Approval*RequiresApprover` /
   `ConnCase` pattern the other 22 already use as real precedent in the same directory.

## See Also

- `docs/ASH-MIGRATION-PLAN.md` — the real 7-phase migration history and standing deferred
  decisions this grid builds on
- `docs/claude/diataxis/reference/http-api-surface.md` — the real, current HTTP route
  enumeration referenced above
- `docs/AWS-CHAPTERS-SUBSTITUTION.md` — the disclosed `FixtureAdapter` exception cited in
  Eliminate
- `lib/xaas/accounts/org.ex` — the tenant-root resource whose own moduledoc names most of the
  gaps this grid cites
