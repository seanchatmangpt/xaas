# W887 — Disk Audit Note (lease-cleanup gate input, v26.10.6)

**Lane**: W887. **Subject**: `feat/playwright-surface` @ a0723bf6. **Date**: 2026-10-07.
**Mode**: census/read-only. No deletion executed. No build root minted.

## Method

Primary: `mcp oclnr audit scan` (roots `["/Users/sac/xaas"]`, `tool_roots: true`,
`min_mb: 100`) — **REFUSED by the tool's state machine**:
`Cannot transition from AUDIT_COMPLETE to AUDIT_NEEDED`. Per task instruction, fell back
to a plain `du` census of `/Users/sac/xaas/_build*/` + `/tmp/w*` + sibling-repo leases.

## Totals (measured, `du -sk`)

| class | entries | size |
|---|---|---|
| `/Users/sac/xaas/_build-lane*` leases | 68 | 28.84 GB |
| `/tmp/w*` (logs + lease dirs) | ~700 files/dirs | 0.57 GB |
| `/Users/sac/xaas/_build` (main tree, NOT a lease) | 1 | 1.5 GB |
| `/Users/sac/xaas/deps` | 1 | 1.4 GB |
| `/Users/sac/xaas/node_modules` | 1 | 101 MB |
| **Lease residue (lanes + tmp w\*)** | — | **~29.4 GB** |

## Top 20 entries

| path | size |
|---|---|
| `/Users/sac/xaas/deps` | 1.4 GB |
| `/Users/sac/xaas/_build` | 1.5 GB |
| `_build-laneW842` | 676 MB |
| `_build-laneW803-dev` | 532 MB |
| `_build-laneW791` | 438 MB |
| `_build-laneW778` | 438 MB |
| `_build-laneW779` | 438 MB |
| `_build-laneW786` | 438 MB |
| `_build-laneW787` | 438 MB |
| `_build-laneW799` | 438 MB |
| `_build-laneW801` | 438 MB |
| `_build-laneW803` | 437 MB |
| `_build-laneW804` | 438 MB |
| `_build-laneW805` | 438 MB |
| `_build-laneW808` | 438 MB |
| `_build-laneW812` | 438 MB |
| `_build-laneW813` | 438 MB |
| `_build-laneW814` | 438 MB |
| `_build-laneW821` | 438 MB |
| `_build-laneW823` | 438 MB |

(68 lane dirs at ~437-438 MB each except W788 48M, W873/W880 356M, W866 437M,
W869/W872 437M; the ~437 MB tier is homogeneous and interchangeable — top-20 ordering
within it is arbitrary. Largest non-lane `/tmp/w*` item: `/tmp/w746-scratch` 476 MB.)

## Cross-reference to W878

W878's census **has landed**: `docs/sjira/v26.10.6/plans/w878-lease-census.md`
(same subject a0723bf6, same day). Its counts reconcile with this re-census:
both observe 68 xaas `_build-lane*` dirs. Delta: W878 reported 28.21 GB; this census
measures 28.84 GB (~0.6 GB drift = lane growth + W880/W873 maturation since W878 ran;
no new lane dirs appeared). W878 classifies 58 dirs DELETABLE (~24.87 GB), 9 CHECK
(incl. W816-by-exclusion), 1 KEEP (W880), plus 9 sibling-repo lanes (~3.19 GB in
`ash_pplan`/`beam4pm`/`ggen_igniter`) and 6 `/tmp` lease dirs (~0.51 GB incl.
`w746-scratch`, still present here at 476 MB). W878's explicit per-path `rm` list is
the authoritative cleanup input; this lane executed none of it — coordinator owns the
deletion transition per the fanout cleanup law.
