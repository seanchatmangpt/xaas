# W440 — Final Operator Cleanup Manifest (v26.10.6 campaign)

Generated 2026-10-06, epoch 1791334696. ACTIVE cutoff = mtime within 30 min
(> 1791332896). Nothing was deleted by this lane (repo fleet read-only; this
file is the only write).

## ACTIVE (do not delete until their lanes land)

| path | size | mtime epoch |
|---|---|---|
| /Users/sac/xaas/_build-laneW394 | 832M | 1791333610 |
| /Users/sac/xaas/_build-laneW408 | 436M | 1791333282 |
| /Users/sac/xaas/_build-laneW412 | 437M | 1791333157 |
| /Users/sac/xaas/_build-laneW416 | 437M | 1791333199 |
| /Users/sac/xaas/_build-laneW418 | 437M | 1791334573 |
| /Users/sac/xaas/_build-laneW425 | 437M | 1791333430 |
| /Users/sac/xaas/erl_crash.dump | 49M | written 17:55 Oct 6 (recent crash; classify before delete) |
| /Users/sac/xaas/_build-laneW427 | 437M | 1791333492 |
| /Users/sac/xaas/_build-laneW429 | 437M | 1791333506 |
| /Users/sac/xaas/_build-laneW432 | 363M | 1791333591 |
| /Users/sac/xaas/_build-laneW433 | 363M | 1791333608 |
| /Users/sac/xaas/_build-laneW434 | 356M | 1791333703 |
| /Users/sac/xaas/_build-laneW435 | 356M | 1791333752 |
| /Users/sac/xaas/_build-laneW436 | 356M | 1791333826 |
| /Users/sac/xaas/_build-laneW437 | 356M | 1791334019 |
| /tmp/xaas-e2e-server.log | 548K | 1791334688 (live e2e server log — seconds old) |

ACTIVE subtotal: ~5.17 GiB lane roots + 49M crash dump + 548K log ≈ 5.2 GiB.

Note: `_build-laneW380b` (308M, 1791332648) and `_build-laneW398` (437M,
1791332726) missed the 30-min cutoff by ~4 min; classed READY (borderline —
re-check mtime at execution time).

## READY-TO-DELETE

### Lane build roots — /Users/sac/xaas (12.7 GiB, 28 roots)
`_build-lane295` 435M · `_build-laneW125` 1.0G · `_build-laneW141` 438M ·
`_build-laneW177` 398M · `_build-laneW212` 437M · `_build-laneW248` 437M ·
`_build-laneW316` 437M · `_build-laneW316b` 356M · `_build-laneW318` 437M ·
`_build-laneW320` 437M · `_build-laneW329` 437M · `_build-laneW335` 437M ·
`_build-laneW347` 437M · `_build-laneW349` 437M · `_build-laneW350` 437M ·
`_build-laneW358` 436M · `_build-laneW359` 437M · `_build-laneW363` 437M ·
`_build-laneW367` 437M · `_build-laneW369` 437M · `_build-laneW372` 437M ·
`_build-laneW378` 437M · `_build-laneW379` 437M · `_build-laneW380` 437M ·
`_build-laneW380b` 308M · `_build-laneW386` 437M · `_build-laneW387` 437M ·
`_build-laneW388` 437M · `_build-laneW398` 437M

### Lane build roots — sibling repos (3.5 GiB, 11 roots)
- /Users/sac/ash_surface/_build-laneW326 161M
- /Users/sac/ash_surface/_build-laneW335 161M
- /Users/sac/ash_surface/_build-laneW348 161M
- /Users/sac/ash_surface/_build-laneW371 161M
- /Users/sac/ggen_igniter/_build-laneW343 583M
- /Users/sac/beam4pm/_build-laneW332 583M
- /Users/sac/beam4pm/_build-laneW364 583M
- /Users/sac/ex4pm/_build-laneW332 270M
- /Users/sac/ash_r2rml/_build-laneW332 81M
- /Users/sac/ash_a2a/_build-laneW366 423M
- /Users/sac/ash_a2a/_build-laneW385 423M

### /tmp residue (2.7 GiB)
- /tmp/w392-build 438M
- /tmp/w392-build-old 403M
- /tmp/w392-scratch 1.9G
- /tmp/w392-gen.exs 4K
- /tmp/w392-out 4K
- /tmp/os13-quarantine-20261006-165326 68K
- /tmp/w385-v1-conformance.json 8K
- /tmp/w344-server.log 24K
- /tmp/w325_pytest_full.log 12K

(/tmp/xaas-e2e-server.log excluded — ACTIVE, live server.)

### Repo-root delete-list files (/Users/sac/xaas)
- erl_crash.dump 49M — ACTIVE-classed (written 17:55 today); delete only after
  the crash it records is classified.
- GGEN-SH-AFTER-MIX-COMPILE.log 10.9K — delete.
- GGEN-SH-AFTER-PROOF.txt 112B — delete.
- ggen.lock 4K — runbook G4-adjacent decision note: KEEP (not delete-list;
  lockfile surface, hand-editing prohibited, regenerable via `ggen sync`).

## Totals

- READY-TO-DELETE count: 28 + 11 + 9 + 2 = **50 items**
- READY-TO-DELETE size: 12.7 GiB (xaas roots) + 3.5 GiB (siblings) + 2.7 GiB (/tmp) + ~11 KB = **≈ 18.9–19.0 GB**
- ACTIVE (hold): ≈ 5.2 GB (14 lane roots + erl_crash.dump + live e2e log)
- Campaign lane-root total observed: ≈ 24.1 GB

Deletion itself is NOT performed by W440 — this manifest is the delete-list
input for the operator cleanup transition (plan→approve→delete with APFS
snapshot thinning per cleanup law).

- `_buildW514/` (repo root, w514 lane MIX_BUILD_ROOT typo, ~deps size) — READY-TO-DELETE post-lane (w514).
