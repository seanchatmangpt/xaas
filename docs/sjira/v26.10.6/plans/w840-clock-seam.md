# W840 — Lease kernel clock-seam alignment (live_leases/1, renew/1)

Lane: W840, v26.10.6 campaign. Follows W811's findings 1-2
(`w811-lease-kernel-lease-kernel-deepening` receipt). Subject: branch
`feat/playwright-surface`, HEAD `a0723bf6` + this lane's working-tree diff
(uncommitted, per lane contract). Written under `MIX_ENV=test`,
`MIX_BUILD_ROOT=_build-laneW840` (deleted after integration).

## μ / diff

`lib/xaas/ultracode/lease.ex` — two seam routings, generated-vs-handwritten:
handwritten, minimal (the file already aliases `DurationBudget`):

1. `live_leases/1` — `now = DateTime.utc_now()` -> `now = DurationBudget.now()`
   (with a comment naming the law: the capacity meter and the claim kernel
   must judge expiry on ONE clock).
2. `renew/1` — `now = DateTime.utc_now()` -> `now = DurationBudget.now()`
   (extension base and `last_heartbeat_at` both move on the seam).

No other clock sites touched. `atomic_row_update/2`'s `updated_at` stamp and
the receipt `sealed_at` stamps remain real wall clock — out of W811's finding
scope, and semantically wall-clock facts.

## Before / after

Before (W811, asserted in its courts):

* fast-forwarded seam -> kernel-expired lease still counted by
  `live_leases/1` (slot held under a fast-forwarded seam);
* `renew/1`'s extension unobservable against the seam (base = real wall
  clock): renewed expiry could sit BEHIND the seam the court judges with.

After (asserted in the new W840 courts):

* fast-forwarded seam -> `live_leases/1` excludes the expired lease (slot
  freed; a capacity-fenced claim then binds the pool);
* `renew/1` at advanced-now T writes `lease_expires_at = T + 30m` and
  `last_heartbeat_at = T`; the renewal survives a further +29m fast-forward
  and expires on schedule at +31m.

## Regression courts

`test/xaas/ultracode/lease_kernel_deepening_test.exs`:

* amended 3 W811 courts that had asserted the drift as a documented gap
  (expiry-meter test, renew wall-clock arithmetic test,
  heartbeat-during-expiry meter assert) to the fixed semantics;
* added describe block `"W840 clock-seam regression courts"` (2 tests):
  (1) fast-forwarded seam excludes the kernel-expired lease from
  `live_leases/1` and frees the capacity-fenced slot (stale bearer then
  resolves `{:no_lease, token}` after the re-claim overwrites the token —
  same typed shape as W811's re-claim court); (2) `renew/1` extension
  observable against the advanced seam (exact `advanced now + TTL`, heartbeat
  stamp = advanced now, renewed lease survives +29m, expires at +31m).

### Mutation rationale

If the seam routing reverts in `live_leases/1` (back to `DateTime.utc_now/0`),
court (1)'s `assert Lease.live_leases("zcode-deepen") == 0` fails (the row's
expiry is ~30m ahead of real wall clock, so the meter counts it), and the
capacity-fenced claim in the same court returns `:pool_at_capacity` — the
phantom-slot symptom W811 documented.

If the seam routing reverts in `renew/1`, court (2)'s
`assert DateTime.diff(row.lease_expires_at, now_advanced, :second) == 30 * 60`
fails (a reverted renew writes real-now + 30m, ~10 minutes BEHIND the advanced
seam — the diff reads ~-600), and the post-renewal `+29m` admit_tool court
fails as `{:lease_expired}` instead of `:allow` — the unobservable-renewal
symptom.

## Verification (real output)

```
MIX_ENV=test MIX_BUILD_ROOT=_build-laneW840 mix test test/xaas/ultracode/lease_kernel_deepening_test.exs
  -> 23 passed (0 failed)   # W811's 21 + clock-seam court + 2 new W840 courts
MIX_ENV=test MIX_BUILD_ROOT=_build-laneW840 mix test test/xaas/ultracode/lease_test.exs \
  test/xaas/ultracode/lease_cancel_test.exs test/xaas/ultracode/lease_reclaim_test.exs \
  test/xaas/ultracode/lease_surface_test.exs test/xaas/ultracode/lease_verifier_test.exs \
  test/xaas/ultracode/duration_budget_test.exs
  -> 84 passed (0 failed)
MIX_ENV=test MIX_BUILD_ROOT=_build-laneW840 mix test test/xaas/ultracode/lease_concurrency_stress_test.exs
  -> 0 tests, 10 excluded   # stress-tagged, pre-existing exclusion; unchanged by this lane
```

## Standing

ALIVE (exact subject: working tree at a0723bf6 + this diff; replay: the two
mix test commands above under the pinned asdf toolchain, MIX_BUILD_ROOT
isolated). Falsifiers exercised: both new W840 courts; W811's 21 courts stay
green with their finding-assertions updated to the fixed semantics. No
BLOCKED/UNSUPPORTED/REFUSED conditions. Not committed (lane contract:
coordinator owns integration commits). `_build-laneW840` deleted at lane end.
