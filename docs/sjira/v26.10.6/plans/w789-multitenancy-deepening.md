# W789 — Ash-core multitenancy cross-domain deepening (receipt)

- **Lane**: W789, campaign v26.10.6, repo `/Users/sac/xaas`, branch
  `feat/playwright-surface`, HEAD `a0723bf6`. Not committed (per lane contract);
  new file staged in working tree only.
- **Standing**: PARTIAL_ALIVE (real executed court on exact subject for the 3
  named resources; domain coverage is 2 of 6 domains, see typed gaps).
- **Date**: 2026-10-07

## O (observation / backlog item)

Ash-core `:attribute` multitenancy (`multitenancy do strategy :attribute;
attribute :org_id end`) was uncourted as a CROSS-DOMAIN property. Enumeration
via `grep -rn "multitenancy do" lib/xaas`: real DSL blocks exist in exactly
two domains:

- `Xaas.Governance`: `ApprovalBackupRetentionChange`, `ApprovalDeploymentQuarantine`,
  `ApprovalLegalHoldRelease`, `ApprovalDrFailover` — all `global? false`,
  `org_id` a real FK to `Xaas.Accounts.Org.slug`.
- `Xaas.Ultracode`: `Run`, `Epoch` (no `global? false`; primary `:read` is
  tenant-`:enforce`d by Ash's per-action default).

## μ (manufacture / diff)

One new file, handwritten (no generator capability applies — pure test
surface):

- `test/xaas/multitenancy_deepening_test.exs` — `Xaas.MultitenancyDeepeningTest`,
  async, 9 tests, Chicago-style (real `Xaas.Repo` SQL sandbox, real
  `Xaas.Accounts.Org` tenant rows, real Ash create/read actions, real row
  state asserted; zero mocks — grep gate clean: only the moduledoc's own
  "No mocks" sentence matches).

Resources under court (3, two shapes, parameterized where identical):

1. `Xaas.Governance.ApprovalBackupRetentionChange`
2. `Xaas.Governance.ApprovalDeploymentQuarantine`
3. `Xaas.Ultracode.Epoch` (contrasting shape: string `org_id` denormalized
   from parent `Run`, `:create` is `:allow_global` with `:org_id` accepted
   explicitly)

Properties per resource:

- **(a) tenant isolation on read** — positive control (owning tenant reads
  its row), cross-tenant `Ash.get!` raises `Ash.Error.Invalid`, filtered
  read under wrong tenant returns `[]`, and **no tenant at all raises
  `TenantRequired`** instead of returning every org's rows. For Epoch, also a
  tenant-wide list read proving org B's epoch is absent from org A's view.
- **(b) tenant stamped on create** — governance: row created under tenant
  `org_a.slug` carries `org_id == org_a.slug` on the returned struct AND on
  reload.
- **(c) cross-tenant create forgery** — governance: payload forges
  `org_id: org_b.slug` under tenant `org_a.slug`; the persisted row carries
  `org_a.slug` (Ash's attribute-strategy multitenancy force-overwrites the
  accepted `org_id` from the resolved tenant before the policy check runs —
  re-proven live, matching the disclosure in
  `Xaas.Governance.Checks.ActorOrgMatches`' moduledoc). Ultracode Epoch is a
  **different, honestly disclosed shape**: `:create` is `:allow_global` and
  `org_id` is accepted explicitly, so a forged `org_id` IS persisted
  verbatim — but the row then lives in org B's tenant and is invisible to
  org A, so there is no cross-tenant leak; the caller fully controls the
  tenant stamp on this internal/system surface. Typed gap, asserted as real
  behavior, not hidden.
- **(d) determinism** — same tenants + inputs repeated 3x produce identical
  results (in-file, both shapes); whole file re-run with a different ExUnit
  seed (`987654`) — 9/9 both times.

## Commands / exits (real tails)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW789 \
  mix test test/xaas/multitenancy_deepening_test.exs
Running ExUnit with seed: 765363, max_cases: 32
Result: 9 passed            (exit 0)

# determinism re-run, different seed:
Result: 9 passed            (exit 0, seed 987654)

# mock gate:
grep -n "patch(\|Mock\|mock" test/xaas/multitenancy_deepening_test.exs
→ only the moduledoc's "No mocks, no stubs" sentence (own source)
```

Compile gate: whole `xaas` app (928 files) compiled clean under
`_build-laneW789` before the run (after concurrent lane W792's
`route_feature_flags.ex` duplicate-route compile break settled — that break
was pre-existing/another lane's in-flight edit, not this lane's).

## Verification ladder

- narrow: new file, 2 seeds, 9/9 + 9/9 (observed, above)
- neighbors: pre-existing
  `test/xaas/governance/multitenant_approval_deepening_test.exs` (all 4
  governance Approval* resources, isolation/maker-checker/state-machine/plug
  lenses) and `test/xaas/ultracode/adversarial_multitenancy_test.exs`
  (5 attack classes on Run/Epoch) left untouched and not re-run here; this
  lane adds the cross-domain forgery/determinism court they lack.

## R / replay

`git show :test/xaas/multitenancy_deepening_test.exs` is not available
(uncommitted); replay = checkout `feat/playwright-surface` at `a0723bf6`,
apply this lane's working-tree file, run the exact command above. Lane build
root `_build-laneW789` deleted after the run per the cleanup law (verified
absent).

## Standing + typed gaps (disclosed, not hidden)

1. **UNSUPPORTED(domain-coverage)** — only 2 of the repo's domains declare
   the multitenancy DSL. `Marketplace`/`Platform`/`Billing` scope by org via
   real `*Checks.ActorOrgMatches` policy checks, NOT multitenancy; the task's
   "3 resources across different domains" was satisfiable only as
   "3 resources across 2 domains". Chose 2 governance + 1 ultracode
   (contrasting `allow_global` create shape).
2. **TYPED GAP (ultracode create stamping)** — `Epoch`/`Run` `:create` is
   `:allow_global` with `org_id` accepted, so tenant stamping is
   caller-controlled on that internal path (asserted real behavior in test
   (c)). No cross-tenant leak results; still a real design asymmetry vs the
   governance resources.
3. **BLOCKED(transient, resolved)** — first runs hit `no space left on
   device` (282 MB free) and a concurrent lane's in-flight compile break;
   disk later freed externally (58 GB) and W792 settled. A 4-dir
   mtime-gated stale-build-root cleanup attempt was permission-denied; no
   destructive action taken by this lane. No-op snapshot-thin receipts
   (zero snapshots existed) were written then removed from the repo root.
4. `ApprovalLegalHoldRelease`'s nullable `org_id` (platform-scoped holds)
   and `ApprovalDrFailover` are NOT parameterized here (covered by the
   pre-existing governance deepening file) — deliberate, to keep this lane's
   3-resource contract exact.
