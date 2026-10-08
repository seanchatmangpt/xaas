# W650h32 — One-Pass Staging Map (receipt)

Lane W650h32, v26.10.7 fleet seal. Repo: `/Users/sac/xaas`. Read-only sweep + this receipt.
Observed: 2026-10-07, on working tree (no commits made by this lane).

Task origin: W650h30's exclusion note — three owner-returned groups (w984dg marketplace,
self_digest, w984de vkg) needed current-state verification and a staging map.

## Commands run (real output)

- `ls` on all receipt paths below (exit codes observed).
- `git status --porcelain` on the six target paths.
- `git diff --cached --name-only | grep -Ei 'vkg|w984dg|self_digest|w984de|w650h20'` → **empty**
  (nothing from these groups is currently staged).
- `grep` of `w650h11-stragglers.md` and `w650h14b-blocked-check.md` (both untracked) annotations.

## Findings

### Receipts (docs/sjira/…)

| path | on disk? | notes |
|---|---|---|
| `docs/sjira/v26.10.6/plans/w984dg-*.md` | **N** | no file matches w984dg in any plans dir (confirmed by W650h11 + W650h14b, re-witnessed this pass) |
| `docs/sjira/v26.10.6/plans/w984bo-marketplace-depth.md` | **Y** | exists — but covers the *tracked* `pack_catalog_depth_test.exs`, NOT `catalog_consumption_depth_w984dg_test.exs` (receipt↔file mismatch, per W650h11 line 15) |
| `docs/sjira/v26.10.7/plans/w650h20-self-digest.md` | **N** | W650h20 still running — noted as such, no receipt yet |
| `docs/sjira/v26.10.6/plans/w984de-*.md` | **N** | W984de killed mid-flight, no receipt exists (confirmed by W650h11) |

### Tests

| path | on disk | last known color | git state |
|---|---|---|---|
| `test/xaas/marketplace/catalog_consumption_depth_w984dg_test.exs` | **Y** | RED 4/22 (W650h14b; owner repair pending) | untracked |
| `test/xaas/self_digest/` (gap_depth, promotion_pipeline_depth, work_depth) | **Y** | promotion_pipeline GREEN 5/5 (W650w probe, per W650h11); other two UNKNOWN | untracked (whole dir) |
| `test/xaas/semantics/vkg/query_depth_test.exs` | **Y** | GREEN 5/5 after W650h11 repair (batch 20/20) | untracked |

## The map

| file | receipt Y/N | test green Y/N | git state | next action |
|---|---|---|---|---|
| `test/xaas/marketplace/catalog_consumption_depth_w984dg_test.exs` | N — W984bo's receipt does NOT cover this file | N — RED 4/22, owner repair pending | untracked | **repair-first** (owner W984dg: fix to green, then mint w984dg receipt citing W650h11/W650h14b) |
| `test/xaas/self_digest/gap_depth_test.exs` | N (no self_digest receipt; W650h20 running) | UNKNOWN (not run this pass) | untracked | **wait-owner** (W650h20's receipt should cover the dir) |
| `test/xaas/self_digest/promotion_pipeline_depth_test.exs` | N (same — W650h20 running) | Y — GREEN 5/5 (W650w probe ×2 fresh roots) | untracked | **wait-owner** (W650h20) |
| `test/xaas/self_digest/work_depth_test.exs` | N (same — W650h20 running) | UNKNOWN | untracked | **wait-owner** (W650h20) |
| `test/xaas/semantics/vkg/query_depth_test.exs` | N dedicated (W984de killed) — repair provenance in W650h11 | Y — GREEN 5/5 (W650h11 repair, batch 20/20) | untracked (W650h11 staged it, but the stage was since unstaged — nothing in `git diff --cached`) | **stage-now** (green + provenance in w650h11-stragglers.md; minting a dedicated w984de receipt is the flagged follow-up, not a blocker) |
| `w650h20-self-digest.md` (receipt) | N — W650h20 running | — | — | **wait-owner** |
| w984de receipt | N — W984de killed | — | — | **mint later** (next receipts sweep) |
| w984dg receipt | N | — | — | **mint later** (after repair) |

Note: W650h11's receipt says "STAGED"; re-witnessed this pass: the stage has been undone —
all three groups are back to untracked on the current index. Annotate W650h11 accordingly
at next touch.

## Standing

- Map: ALIVE (witnessed on-disk + git state this pass).
- W650h11 "STAGED" claim: STALE as of this pass — re-witnessed untracked.
- w984dg test: BLOCKED(repair) — RED 4/22 per W650h14b; owner action.
- w650h20-self-digest receipt: UNKNOWN (W650h20 in flight).
- w984de/w984dg receipts: UNSUPPORTED (owner never produced; flag for next receipts sweep).

## Falsifier for this map

Re-run the two commands in "Commands run" against the working tree; if the staging map's
staged/untracked column disagrees with `git status --porcelain` output, the map is dead.

## See Also

`docs/sjira/v26.10.6/plans/w650h11-stragglers.md` ·
`docs/sjira/v26.10.6/plans/w650h14b-blocked-check.md` ·
`docs/sjira/v26.10.6/plans/w984bo-marketplace-depth.md`
