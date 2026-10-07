# W970a — DESIGN wave 6 receipt

Lane W970a, xaas v26.10.6, repo `/Users/sac/xaas`, branch `feat/playwright-surface`
(HEAD moved during the lane: started near `fc14f10b`, integration commits landed
mid-lane, ended at `6f235905`). No commit made, per lane contract; the diff is
left in the working tree for the coordinator. Standing: PARTIAL_ALIVE.

## Spec selection history (stop-and-disclose on collision)

1. Only ONE disjoint M spec was available, not two. Every other M spec in
   `docs/sjira/v26.10.6/plans/w905-design-gap-specs.md` was claimed, landed, or
   collision-banned at lane start (verified on disk 07:55-08:05):
   - SPEC-04/18: lane W969b (in flight), surfaces on the banned list.
   - SPEC-14/27: W968c, landed (migrations on disk 07:34).
   - SPEC-16/17: landed pre-lane (w935/w940b receipts).
   - SPEC-21/24/26: landed (w969c + W970b commit `b2758300`).
   - SPEC-20: route_projects_backups.ex mtime was <60s old at 07:56 — a lane
     was actively editing it. Excluded.
   - SPEC-10/30: untracked in-flight files (limit_gate.ex,
     graphql_http_surface_test.exs). Excluded.
   - SPEC-07: chosen (billing tree untouched at HEAD, mtimes >1h old).
2. Mid-lane collision: while I was implementing SPEC-07, lane W975b landed
   multitenancy blocks on 4 of the same 8 billing resources
   (subscription.ex, approval_sla_credit_apply.ex, approval_patch_sla_credit_apply.ex,
   revenue_recognition.ex). One transient duplicate-block state existed; I backed
   my edits out of the three files they claimed first (sla_credit_apply,
   patch_sla_credit_apply, subscription); revenue_recognition they completed
   after claiming. No duplicate blocks remain: each of the 8 billing resources
   carries exactly one lane marker (verified by grep).
3. Second M spec REFUSED(disjointness) per the W969c precedent: no remaining
   unclaimed M exists in the W905 backlog.

## What landed (SPEC-07, W729-GAP-3) — my half of the 8-resource sweep

My four resources (all of the form: `multitenancy do strategy(:attribute)
attribute(:org_id) global?(true) end` + `:org_id` added to the `:create` accept
list where the attribute is new):

- `lib/xaas/billing/approval_pricing_override.ex` (new org_id attr + column)
- `lib/xaas/billing/approval_quota_override.ex` (new org_id attr + column)
- `lib/xaas/billing/approval_invoice_reconciliation_approve.ex` (new org_id attr + column)
- `lib/xaas/billing/approval_tier_downgrade.ex` (new org_id attr + column)
- `priv/repo/migrations/20261007250000_add_org_id_to_billing_approval_tables.exs`
  — adds nullable `org_id` + btree index to the four tables that lacked it
  (approval_pricing_overrides, approval_quota_overrides,
  approval_tier_downgrades, approval_invoice_reconciliation_approves).
  Deliberately nullable: rows minted without a tenant stay global rows
  (nil org_id matches global reads), so no existing fixture or caller breaks.
  Forcing NOT NULL would break every existing create without a tenant and is
  the coordinator's call, not this lane's.

## Design note for the coordinator (one convention now, both halves)

Both halves converged on the SAME convention (W975b's): resource-level
`global?(true)`. I initially shipped per-action `multitenancy :allow_global`
with `global?` unset; a real test failure (tenant-less `:approve` refused with
"changesets require a tenant") traced to Ash 3.34's update path
(`Ash.Actions.Update.set_tenant/1`, deps/ash/lib/ash/actions/update/update.ex:530)
which consults ONLY the resource-level global? flag — per-action allow_global
is not consulted there. The per-action variant was removed; the four files now
match W975b's exactly. Only my 4 resources + migration + court + one fixture
line + one flipped pin are mine in this tree.

## Court

`test/xaas/billing/billing_multitenancy_court_test.exs` (3 tests, mutation
rationale in moduledoc): (1) schema court — strategy :attribute on :org_id,
global? == true, for all four resources; (2) tenant-bound read hard-filters —
org A sees exactly its own row, wrong-tenant get is typed NotFound (assert
Ash.Error.Invalid), org B sees its own; (3) tenant-less regression fence —
create/read without tenant unchanged, org_id nil = global row.

Flipped pins (visible diffs in existing courts, both disclosed in-file):
- `test/xaas_web/controllers/approval_tier_downgrade_controller_test.exs`:
  fixture `create_pending!` now stamps `org_id` (the row was previously
  org-invisible by construction — the new tenant filter caught it); and the
  cross-org PATCH pin flipped 403 -> 404: with query-layer isolation the
  attacker's tenant no longer sees the row, the Ash-idiomatic stronger shape.
  Security property unchanged and still asserted (no approval, no tier change,
  no Ledger credit).
- No other existing test changed.

## Verification (green x2)

Both runs under `PATH=$HOME/.asdf/shims:$PATH`, `MIX_ENV=test`,
`MIX_BUILD_ROOT=_build-laneW970a`:

- `mix ecto.migrate` on the test DB: exit 0.
- `mix compile`: exit 0 (warnings only; several reference other lanes' in-flight files).
- Run 1: `mix test <7 suites>` — **44 passed** (court 3/3 + regression suites).
- Run 2: same command — **44 passed**.
- Negative control: stash of my four resource files -> tier controller suite
  9/9 passes at HEAD, proving the 4 controller failures were mine and now fixed.

## Standing

PARTIAL_ALIVE: real compiled code, real migration applied to the test DB, real
court green x2 on real Postgres; SPEC-07 covers only MY four of the eight
billing resources (W975b owns the other four, their receipt:
docs/sjira/v26.10.6/pdf; actual: docs/sjira/v26.10.6/plans/w975b-design-wave4.md).
Cross-lane hazards disclosed: (a) at least three transient cross-lane compile
breaks (bridges/graphlaw.ex TokenMissingError, ocel/event.ex, security/finding.ex,
generated/regen_check.ex) seen mid-lane — all from other lanes' concurrent
edits, all self-healed; (b) second-M-spec REFUSED(disjointness).

## Lane lease

`_build-laneW970a` LEFT IN PLACE: the sandbox denied `rm -rf` at lane close. Coordinator must delete it at integration (per the cleanup law).
