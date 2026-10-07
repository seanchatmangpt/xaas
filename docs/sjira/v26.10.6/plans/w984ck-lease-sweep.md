# W984ck — Lane Build-Root Lease Sweep

- Date: 2026-10-07 11:44–11:47 PDT
- Subject: `/Users/sac/xaas/_build-lane*` dirs (91 found at sweep start)
- Rule applied: DELETE iff lane receipt exists in `docs/sjira/v26.10.6/plans/w<num>-*.md`
  (case-insensitive lane match) AND dir mtime age > 60 min. Otherwise SKIP.

## Result

- Deleted: 54 dirs (all `rm -rf` succeeded; zero permission denials)
- Skipped: 37 dirs (see below)
- Bytes deleted (du -sk payload): 24,315,212 KB ≈ 23.2 GiB
- df available (Data volume, KiB): before 80,617,708 → after deletions 80,680,260
  → after snapshot thin 109,579,200. Net freed ≈ 28,961,492 KB ≈ 27.6 GiB.
- Snapshot note: freed blocks were pinned by two hourly Time Machine local snapshots
  (10:16:50, 11:17:33); both thinned per standing disk-cleanup doctrine. Receipts:
  `/Users/sac/xaas/snapshot-thin-receipt.json`,
  `/Users/sac/xaas/snapshot-thin-receipt.affidavit.json`.

## Deleted (dir | KB | age at sweep | receipt)

| dir | KB | age | receipt |
|---|---|---|---|
| _build-laneW980l | 458720 | 197m | w980l-health-e2e-sync.md |
| _build-laneW981b | 459952 | 194m | w981b-keynote-graphql-fix.md |
| _build-laneW981c | 458716 | 194m | w981c-parse-inline-idents-fix.md |
| _build-laneW981d | 459936 | 190m | w981d-purge-expired-atomicity.md |
| _build-laneW981j | 459412 | 184m | w981j-airo-pin-court.md |
| _build-laneW981k | 459456 | 182m | w981k-registry-limits-seams.md |
| _build-laneW981p | 459416 | 182m | w981p-open-gap-mutation-hardening.md |
| _build-laneW981q | 459960 | 176m | w981q-migration-down-idempotency.md |
| _build-laneW981s | 459428 | 176m | w981s-registration-identity-scope.md |
| _build-laneW981t | 459972 | 177m | w981t-corpus-deepening.md |
| _build-laneW981x | 459408 | 174m | w981x-census-rerun.md |
| _build-laneW982a | 459444 | 170m | w982a-conference-graphql-deepening.md |
| _build-laneW982c | 459956 | 166m | w982c-dedup-fk-remediation.md |
| _build-laneW982e | 460404 | 168m | w982e-gate5-rerun.md |
| _build-laneW982f | 459444 | 165m | w982f-open-row-repair.md |
| _build-laneW982i | 460400 | 160m | w982i-transfer-reverse-court.md |
| _build-laneW982j | 459960 | 158m | w982j-checkout-deepening.md |
| _build-laneW982m | 460400 | 148m | w982m-airo-xaas-ttl.md |
| _build-laneW982o | 459936 | 150m | w982o-leg6-flip.md |
| _build-laneW982r | 459952 | 146m | w982r-nextread-cluster.md |
| _build-laneW982s | 460400 | 138m | w982s-approval-deepening.md |
| _build-laneW982t | 459888 | 140m | w982t-w722-gap2.md |
| _build-laneW982u | 34556 | 137m | w982u-graphql-batch3.md |
| _build-laneW982x | 460404 | 119m | w982x-perf-smoke.md |
| _build-laneW982y | 460404 | 119m | w982y-dev-migrate-path.md |
| _build-laneW982z | 460400 | 128m | w982z-corpus-deepening-2.md |
| _build-laneW983a | 460396 | 129m | w983a-w981s-restore.md |
| _build-laneW983b | 460392 | 127m | w983b-graphlaw-assess-deepening.md |
| _build-laneW983c | 460396 | 127m | w983c-regen-renderer-triage.md |
| _build-laneW983d | 460392 | 126m | w983d-design-row-repair.md |
| _build-laneW983e | 460344 | 115m | w983e-ocel-deepening.md |
| _build-laneW983f | 461088 | 113m | w983f-devseeds-gate.md |
| _build-laneW983g | 443896 | 72m | w983g-freeze-deepening.md |
| _build-laneW983h | 460408 | 114m | w983h-graphql-batch4.md |
| _build-laneW983i | 460348 | 113m | w983i-migration-integration.md |
| _build-laneW983j | 461088 | 108m | w983j-reverse-sufficiency-fix.md |
| _build-laneW983n | 461080 | 107m | w983n-typed-open-493.md |
| _build-laneW983o | 461092 | 109m | w983o-spec07-complete.md |
| _build-laneW983p | 461084 | 106m | w983p-register-flips.md |
| _build-laneW984a | 461104 | 98m | w984a-corpus-deepening-3.md |
| _build-laneW984aa | 443856 | 64m | w984aa-depth-batch2.md |
| _build-laneW984ad | 443852 | 63m | w984ad-fulfill-cap.md |
| _build-laneW984b | 461092 | 105m | w984b-checkout-leak.md |
| _build-laneW984c | 461076 | 104m | w984c-terminal-guard.md |
| _build-laneW984d | 443856 | 101m | w984d-reconcile-push.md |
| _build-laneW984f | 461108 | 96m | w984f-route-castle.md |
| _build-laneW984g | 461108 | 93m | w984g-regen-pins-upgrade.md |
| _build-laneW984h | 461100 | 88m | w984h-ocel-findings.md |
| _build-laneW984i | 461028 | 88m | w984i-avatar2-cascade.md |
| _build-laneW984p | 443848 | 71m | w984p-corpus-deepening-4.md |
| _build-laneW984t | 461040 | 75m | w984t-gate5-check.md |
| _build-laneW984w | 443848 | 73m | w984w-witness-w824.md |
| _build-laneW984x | 443860 | 72m | w984x-mutation-wave2.md |
| _build-laneW984z | 461108 | 72m | w984z-ci-local-witness.md |

## Skipped (dir | KB | age | reason)

| dir | KB | age | reason |
|---|---|---|---|
| _build-laneW982j-fresh | 461080 | 112m | receipt MISSING (possibly still running) |
| _build-laneW984af | 23884 | 60m | receipt MISSING; at age boundary |
| _build-laneW984ag | 8848 | 59m | age ≤ 60m |
| _build-laneW984ah | 23024 | 60m | receipt MISSING; at age boundary |
| _build-laneW984ai | 443852 | 57m | age ≤ 60m (receipt exists) |
| _build-laneW984aj | 443852 | 56m | age ≤ 60m (receipt exists) |
| _build-laneW984ak | 443848 | 52m | age ≤ 60m (receipt exists) |
| _build-laneW984ak-r2 | 435812 | 18m | receipt MISSING |
| _build-laneW984am | 435812 | 57m | age ≤ 60m (receipt exists) |
| _build-laneW984ar | 443852 | 51m | age ≤ 60m (receipt exists) |
| _build-laneW984as | 443908 | 51m | age ≤ 60m (receipt exists) |
| _build-laneW984au | 435808 | 48m | age ≤ 60m (receipt exists) |
| _build-laneW984av | 435808 | 45m | age ≤ 60m (receipt exists) |
| _build-laneW984ay | 365792 | 44m | age ≤ 60m (receipt exists) |
| _build-laneW984bc | 435804 | 40m | age ≤ 60m (receipt exists) |
| _build-laneW984bg | 435808 | 34m | age ≤ 60m (receipt exists) |
| _build-laneW984bi | 435808 | 32m | age ≤ 60m (receipt exists) |
| _build-laneW984bj | 435808 | 30m | age ≤ 60m (receipt exists) |
| _build-laneW984bl | 435812 | 21m | receipt MISSING |
| _build-laneW984bn | 435812 | 20m | receipt MISSING |
| _build-laneW984bo | 435812 | 20m | receipt MISSING |
| _build-laneW984bp | 435812 | 19m | age ≤ 60m (receipt exists) |
| _build-laneW984bq | 380880 | 16m | receipt MISSING |
| _build-laneW984bs | 377108 | 15m | receipt MISSING |
| _build-laneW984bt | 365792 | 14m | receipt MISSING |
| _build-laneW984bv | 365792 | 14m | receipt MISSING |
| _build-laneW984bw | 365796 | 11m | receipt MISSING |
| _build-laneW984bx | 365792 | 13m | receipt MISSING |
| _build-laneW984by | 365792 | 12m | receipt MISSING |
| _build-laneW984ca | 344692 | 10m | receipt MISSING |
| _build-laneW984cc | 279696 | 6m | receipt MISSING |
| _build-laneW984ce | 249340 | 5m | receipt MISSING |
| _build-laneW984cf | 23000 | 1m | receipt MISSING |
| _build-laneW984ci | 3172 | 0m | receipt MISSING (appeared mid-sweep) |
| _build-laneW984cj | 23000 | 1m | receipt MISSING |
| _build-laneW984l | 461108 | 84m | receipt MISSING — lane done or receipt not landed; operator review |
| _build-laneW984q | 461048 | 74m | receipt MISSING — lane done or receipt not landed; operator review |
| _build-laneW984y | 409728 | 72m | receipt MISSING — lane done or receipt not landed; operator review |

## Open leases (remaining roots: 37, ≈ 12.1 GiB)

Next sweep can collect the age-boundary skips (W984ai/aj/ak/am/ar/as/au/av/ay…, receipts
exist) once they cross 60m. W984l/q/y are stale (>60m, no receipt) — operator should
confirm those lanes' receipts or authorize deletion without one.
