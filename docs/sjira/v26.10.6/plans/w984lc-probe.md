# W984lc — Mutation Non-Vacuity Audit #7 over W984jx Subscription Court + W984kg Lease Fix

Lane: W984lc · Date: 2026-10-08 · Branch `feat/playwright-surface` (no branch switch,
no commits, no stash). Method held exactly per `w984ek-probe.md` / `w984ha-probe.md` /
`w984iy-probe.md` / `w984jp-probe.md` (FILE-SWAP baseline: disk snapshots kept in
`/tmp/w984lc/` via `cp`, one surgical lib mutation at a time, targeted court run,
`cmp`-verified byte-identical restore, post-restore green confirmation). Compound-mutation
leg convention per W984ha/jp included (M3c below).

Subjects (disjoint from W984kp's running audit):
- W984jx's subscription Stripe-identity court
  `test/xaas/billing/subscription_resource_court_w984jx_test.exs` over
  `lib/xaas/billing/subscription.ex`.
- W984kg's lease `no_lease` fix: `lib/xaas/ultracode/lease.ex` +
  `test/xaas/ultracode/lease_court_w984kg_test.exs`.

Gates: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984lc`.
Fresh lane-root compile: EXIT=0. Baselines (before any mutation): subscription court
4 passed, lease court 4 passed — both EXIT=0.

## Mutation Matrix

| # | Court (subject lane) | Test file | Mutated lib file | Mutation | During | Verdict |
|---|---|---|---|---|---|---|
| M1 | subscription (W984jx) | test/xaas/billing/subscription_resource_court_w984jx_test.exs | lib/xaas/billing/subscription.ex | dropped `:stripe_subscription_id` from `:create`'s accept list | EXIT=1 (failures), court RED | **KILLED** (full-Stripe-identity round-trip test fails) |
| M2 | subscription (W984jx) | same court | lib/xaas/billing/subscription.ex | `:sync_from_stripe` accept `[:stripe_subscription_id, :status, :current_period_end]` → `[:status]` | EXIT=2, 3/4 passed | **KILLED** (sync non-status-fields test fails: typed UnknownInput on `:current_period_end`) |
| M3a | subscription (W984jx) | same court | lib/xaas/billing/subscription.ex | widened `:change_tier` ARGUMENT `one_of` to include `:free` | EXIT=0, 4 passed | **SURVIVED** (single) |
| M3c | subscription (W984jx), compound leg | same court | lib/xaas/billing/subscription.ex | widened the argument `one_of` AND the `tier` ATTRIBUTE `one_of` simultaneously | EXIT=2, 3/4 passed | **KILLED** (out-of-family tier lands as `{:ok, ...}`; refusal pin fails) |
| M4 | lease (W984kg) | test/xaas/ultracode/lease_court_w984kg_test.exs | lib/xaas/ultracode/lease.ex | dropped W984kg's `{:ok, nil} -> {:error, {:no_lease, _}}` arm in `record_provider_event/2` (reverted to the HEAD `{:ok, epoch} ->` shape) | EXIT=2, 3/4 passed | **KILLED** — exact **BadMapError** (`epoch.id` on nil), the precise defect W984kg found |
| M5 | lease (W984kg) | same court | lib/xaas/ultracode/lease.ex | deleted `def lease_context(other), do: {:error, {:no_lease, other}}` head clause | EXIT=2, 3/4 passed | **KILLED** (FunctionClauseError instead of typed `{:no_lease, _}`) |
| M6 | lease (W984kg) | same court | lib/xaas/ultracode/lease.ex | removed the `if is_map(request["input"])` coercion in `actuate/2` (`input = request["input"]` raw) | EXIT=2, 3/4 named test fails | **KILLED** (FunctionClauseError in `Xaas.Actuation.run/4` instead of the typed `%{}` fallback) |

## Standing Verdicts

- M1 `:create` Stripe identity accept set: **NON-VACUOUS**
- M2 `:sync_from_stripe` non-status accepted fields: **NON-VACUOUS** — the kill is a
  typed `UnknownInput` on `:current_period_end`, i.e. the accepted-set branch the
  W984jx court claims to pin is genuinely load-bearing.
- M3a `:change_tier` argument `one_of` widening: **SURVIVED single, KILLED as compound
  (M3c)** — the argument-level constraint is individually unobservable because the
  `tier` ATTRIBUTE carries the same `one_of` (`[:standard, :pro, :enterprise]`), which
  independently refuses `:free` with the same `Invalid` error class the pin asserts.
  Third instance of the W984ha/jp redundant-pair finding: the argument `one_of` alone
  is a green lie under widening; only the pair is load-bearing against an out-of-family
  tier.
- M4 W984kg `no_lease` arm: **NON-VACUOUS** — the court genuinely pins the repair, not
  just its test names: reverting the disclosed fix reproduces the exact BadMapError the
  fix eliminated, and the court goes RED.
- M5 `lease_context/1` non-binary head: **NON-VACUOUS**
- M6 `actuate/2` non-map input coercion: **NON-VACUOUS**

5/6 single mutants killed; the 1 survivor (M3a) killed by its compound leg (M3c).
Every kill was an exact typed/value assertion (BadMapError, FunctionClauseError x2,
UnknownInput accepted-set, `{:ok, ...}` vs typed refusal, round-trip equality) — no
crash-only kills: M4/M5/M6's crash class IS the pinned typed-refusal divergence.

## Tree Cleanliness

Every restore `cmp`-verified byte-identical to the pre-mutation working-tree snapshot
(`/tmp/w984lc/`). `lib/xaas/billing/subscription.ex` is clean vs HEAD. `lib/xaas/ultracode/lease.ex`
remains `M` exactly as at lane start — that delta is W984kg's own uncommitted `no_lease`
fix (8 insertions), which my snapshots and every restore preserve byte-identically
(`SNAPSHOT_MATCHES_DISK` verified before first mutation). The two court test files are
untracked (`??`) exactly as at lane start (their lanes' uncommitted work). No commit made.
Final green sweep: subscription 4 / lease 4, both EXIT=0.

Standing: **ALIVE** — non-vacuity observed on exact subjects (W984jx subscription court,
W984kg lease court) on branch feat/playwright-surface, this lane.

## Replay

```bash
cd /Users/sac/xaas
export PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984lc
# baseline both courts (4/4 each, exit 0)
# apply one mutation from the matrix, run the paired court, expect RED
# restore from snapshot (cp), cmp-verify byte-identical, court returns EXIT=0
```

## Cleanup

`rm -rf _build-laneW984lc` SUCCEEDED (exit 0, directory confirmed absent; shutil
fallback confirmed `exists: False`). No lane lease remains.
