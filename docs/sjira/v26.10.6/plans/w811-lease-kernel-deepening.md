# W811 — Lease Kernel Deepening (receipt)

- **Subject**: branch `feat/playwright-surface`, HEAD at lane start `a0723bf6`
  (uncommitted; coordinator owns commits — nothing committed by this lane).
- **Lane**: W811, xaas v26.10.6, canonical checkout /Users/sac/xaas.
- **Files written**:
  - `test/xaas/ultracode/lease_kernel_deepening_test.exs` (new; 21 tests, one file, no lib changes)
- **Standing**: PARTIAL_ALIVE (kernel deepening executed and green on the exact subject; drift findings recorded as gaps, not repaired — repair is not this lane's order).

## Command + real tails

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW811 \
  mix test test/xaas/ultracode/lease_kernel_deepening_test.exs
...
Result: 21 passed   (0 failed, 0 skipped)
```

Determinism re-run, different seed:

```
... mix test test/xaas/ultracode/lease_kernel_deepening_test.exs --seed 123456
Running ExUnit with seed: 123456, max_cases: 32
Result: 21 passed
```

## What is now courted (all asserted from the real code, no mocks, real sandbox rows)

- (a) **Expiry mechanics**: claim writes `lease_expires_at = clock + 30m` and
  `claimed_at = clock`, `last_heartbeat_at` nil at bind; strict `:lt`
  liveness comparison (live AT the boundary second, expired one second
  past); expired token is the typed `{:lease_expired, token}` for
  renew/admit_tool/close/refuse/cancel; expired epoch is re-claimable with
  a NEW token, `claimed_at` overwritten with the new claim moment, and the
  stale bearer resolves `{:no_lease, old}`; budget-exhausted run's epoch is
  not ready work (DB-enforced claim filter).
- (b) **Heartbeat**: `renew/1` stamps `last_heartbeat_at` and extends from
  the heartbeat moment; unknown token `{:no_lease, t}`; post-terminal
  `{:lease_not_live, :failed}`; heartbeat after TTL is refused
  `{:lease_expired}` even though renew stamps real wall clock.
- (c) **admit_tool court-before-registry**: an expired lease is
  `{:lease_expired, t}` even when the per-provider override would have
  allowed the tool; a terminal epoch's token is `{:lease_not_live, :failed}`
  — the live-lease court runs before `RuntimeSurface.admit_tool/2` and the
  registry, expiry/terminality is never demoted to a registry verdict.
- (d) **refuse/3**: `:failed` + `terminal_at`, `:refused` receipt with
  `refusal_reason`, semantic-work identity bound in evidence, exactly-once
  (second refuse typed loser, exactly one receipt), slot release
  (live_leases 0→1→0), close/refuse winner-take-all with one receipt,
  forged token `{:no_lease, t}`, bearer token never in durable evidence.
- (e) **Determinism**: oldest-inserted-first claims with distinct tokens;
  `pool_capacity/1` reads integer / per-provider map+`:default` / nil /
  unset default 5; `:pool_at_capacity` is terminal (not retried) and the
  slot recycles through refusal to the oldest still-ready epoch.

## Typed gaps / findings (asserted, not repaired)

1. **Meter/court clock drift**: `Lease.live_leases/1` (the capacity meter)
   and `Lease.renew/1` (extension base + `last_heartbeat_at`) read
   `DateTime.utc_now/0` directly, while the claim kernel's reclaim filter
   and the live-lease court use the `DurationBudget` clock seam
   (`:ultracode_clock`). With the seam fast-forwarded, a kernel-expired
   lease still occupies a capacity slot and a heartbeat keeps a lease
   alive only while the seam tracks real time. Asserted as real behavior
   in the two drift tests; a single-clock unification is a repair, not a
   court, so it is out of this lane's order.
2. **Real wall-clock TTL**: with the default `{DateTime, :utc_now}` clock,
   genuine TTL-passage expiry is observable only after the real 30 minutes;
   the courts approximate with the seam. No short-TTL claim option reaches
   the court (`claim_next` takes `:lease_ttl_minutes`, `renew/1` does not).
   UNSUPPORTED(test-scope) — not a defect claim.

## Not covered (uncourted residue)

- Concurrent (Task.async) heartbeat/expiry interleavings — sequential
  approximations on the steppable clock only; the concurrent-class courts
  already live in `LeaseConcurrencyStressTest` / `lease_cancel_test.exs`.
- `actuate/2` Path A, verifier-suite closure outcomes, worktree-safety
  validation, subject-drift git court: already courted elsewhere
  (`lease_test.exs`, `lease_verifier_test.exs`, `lease_surface_test.exs`).

## Replay

```
cd /Users/sac/xaas
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW811 \
  mix test test/xaas/ultracode/lease_kernel_deepening_test.exs
```

## Cleanup

`_build-laneW811` deletion was refused by the permission system (rm -rf
denied) — the lane build root is LEFT IN PLACE for the coordinator to
delete at integration, per the fanout cleanup law's coordinator-owned
deletion.
