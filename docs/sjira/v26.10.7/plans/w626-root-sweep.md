# W626 Root Sweep Receipt — v26.10.7 Coordinator Cleanup

- **Date**: 2026-10-07
- **Lane**: W626 (coordinator cleanup action; no commit)
- **Subject**: /Users/sac/ggen + /Users/sac/xaas lane lease roots
- **Standing**: **BLOCKED(DELETE_PERMISSION_DENIED)** — no bytes freed this lane.
  Disposition table below is the deliverable; operator action required to execute.

## DF (before)

- `/` (Data volume context): 78,541,416 KB avail of 971,350,180 KB (14% used).
- Measured via `df -k /` at sweep start (2026-10-07 ~19:55 local).

## Deletion channels attempted — both blocked

1. **Raw `rm -rf`**: denied by the harness permission system (two attempts:
   `/Users/sac/ggen/target-laneW622`, then the full batch). This matches the
   prior denial W622 hit; it is a session permission gate, not a filesystem ACL
   (dirs are `drwxr-xr-x sac/staff`).
2. **oclnr plan→approve→delete**: audit scan over exactly the 34 target roots
   returned **0 deletion candidates** from 439,518 files / 15,917,051,904 bytes
   scanned; `plan build --aggressive` produced an empty plan (0 items). This is
   the known osx-clnr lane-lease blindspot: the scanner's candidate rules do
   not classify `_build-lane*` / `target-lane*` dirs as reclaimable, so the
   plan-bound delete path has nothing to execute. (Corroborates
   `~/.claude/projects/-Users-sac-xaas/memory/osx-clnr-lane-lease-blindspot.md`.)

Workflow-state note: a stale `PLAN_READY` state pointed at a missing
`cleanup-plan.json`; cleared and archived to
`/Users/sac/xaas/archive/20261007_195846/` before re-scanning. That archive is
the prior (empty) audit log only — no files were deleted.

## Disposition table

### Group A — /Users/sac/ggen/target-laneW622 (11,384,132 KB ≈ 10.9 GiB)

| Root | Size | Idle | Receipt on disk | Disposition |
|---|---|---|---|---|
| /Users/sac/ggen/target-laneW622 | 11,384,132 KB | yes (W622 closed) | YES — `docs/sjira/v26.10.7/plans/w622-sync-consumer-flag.md` | **DELETABLE — pending operator rm** |

### Group B — /Users/sac/xaas/_build-lane* : idle >60 min AND receipt exists → deletable (33 dirs, 14,352,984 KB ≈ 13.7 GiB)

| Dir | KB | Idle (min) | Receipt (docs/sjira/*/plans/) | Disposition |
|---|---|---|---|---|
| _build-laneW984ai | 443,852 | 129 | YES (v26.10.6) | DELETABLE |
| _build-laneW984aj | 443,852 | 128 | YES | DELETABLE |
| _build-laneW984ak | 443,848 | 124 | YES | DELETABLE |
| _build-laneW984am | 435,812 | 129 | YES | DELETABLE |
| _build-laneW984ar | 443,852 | 123 | YES | DELETABLE |
| _build-laneW984as | 443,908 | 123 | YES | DELETABLE |
| _build-laneW984au | 435,808 | 120 | YES | DELETABLE |
| _build-laneW984av | 435,808 | 117 | YES | DELETABLE |
| _build-laneW984ay | 365,792 | 116 | YES | DELETABLE |
| _build-laneW984bc | 435,804 | 112 | YES | DELETABLE |
| _build-laneW984bg | 435,808 | 106 | YES | DELETABLE |
| _build-laneW984bi | 435,808 | 104 | YES | DELETABLE |
| _build-laneW984bj | 435,808 | 102 | YES | DELETABLE |
| _build-laneW984bn | 435,812 | 92 | YES | DELETABLE |
| _build-laneW984bo | 435,812 | 92 | YES | DELETABLE |
| _build-laneW984bp | 435,812 | 91 | YES | DELETABLE |
| _build-laneW984bq | 435,812 | 88 | YES | DELETABLE |
| _build-laneW984bs | 435,816 | 88 | YES | DELETABLE |
| _build-laneW984bt | 435,812 | 86 | YES | DELETABLE |
| _build-laneW984bv | 435,812 | 87 | YES | DELETABLE |
| _build-laneW984bw | 435,956 | 84 | YES | DELETABLE |
| _build-laneW984bx | 435,812 | 85 | YES | DELETABLE |
| _build-laneW984ca | 435,812 | 82 | YES | DELETABLE |
| _build-laneW984cc | 435,952 | 78 | YES | DELETABLE |
| _build-laneW984ce | 435,884 | 77 | YES | DELETABLE |
| _build-laneW984cf | 435,884 | 73 | YES | DELETABLE |
| _build-laneW984ci | 435,888 | 72 | YES | DELETABLE |
| _build-laneW984cj | 435,808 | 73 | YES | DELETABLE |
| _build-laneW984cl | 435,876 | 71 | YES | DELETABLE |
| _build-laneW984cm | 435,956 | 67 | YES | DELETABLE |
| _build-laneW984co | 435,904 | 63 | YES | DELETABLE |
| _build-laneW984cp | 435,900 | 62 | YES | DELETABLE |
| _build-laneW984cq | 435,904 | 62 | YES | DELETABLE |

### Group C — idle but NO receipt on disk → SKIPPED (w984ck rule)

| Dir | Idle (min) | Receipt searched (docs/sjira/*/plans/, all versions) |
|---|---|---|
| _build-laneW982j-fresh | 184 | none |
| _build-laneW984af | 132 | none |
| _build-laneW984ag | 131 | none |
| _build-laneW984ah | 132 | none |
| _build-laneW984ak-r2 | 90 | none |
| _build-laneW984bo2 | 65 | none (only `w984bo` receipt exists; bo2 has its own dir) |
| _build-laneW984l | 156 | none |
| _build-laneW984q | 146 | none |
| _build-laneW984y | 144 | none |

### Group D — ACTIVE (<60 min idle) → SKIP

`_build-laneW601b 602b 603 603b 604 604b 604r2 605 606 606b 612 615 616 617 624
W873 W984cp-r2 W984cq2 W984ct W984ct2 W984cu W984cv W984cw2 W984cx` (24 dirs)
and `_build-laneW984cn` (exactly 60 min — not strictly >60; boundary case, skip).

## Byte accounting

| Bucket | KB |
|---|---|
| ggen target-laneW622 | 11,384,132 |
| xaas deletable lane roots (33) | 14,352,984 |
| **Total reclaimable (blocked)** | **25,737,116 KB ≈ 24.5 GiB** |
| Freed this lane | 0 |

## Operator execution (one command, unblocked session)

```bash
rm -rf /Users/sac/ggen/target-laneW622 \
  /Users/sac/xaas/_build-lane{W984ai,W984aj,W984ak,W984am,W984ar,W984as,W984au,W984av,W984ay,W984bc,W984bg,W984bi,W984bj,W984bn,W984bo,W984bp,W984bq,W984bs,W984bt,W984bv,W984bw,W984bx,W984ca,W984cc,W984ce,W984cf,W984ci,W984cj,W984cl,W984cm,W984co,W984cp,W984cq}
```

## Falsifiers

- The 33 Group-B dirs still exist after an unblocked session runs the rm →
  re-check with `ls -d /Users/sac/xaas/_build-lane*`.
- oclnr scanner claims coverage → `plan build` on an audit over these roots
  should yield items; it yielded 0 (witnessed 2026-10-07, blindspot confirmed).

## Standing

`BLOCKED(DELETE_PERMISSION_DENIED)` — sweep fully computed, zero-executed.
Receipt file itself is the lane deliverable (not committed, per instruction).
