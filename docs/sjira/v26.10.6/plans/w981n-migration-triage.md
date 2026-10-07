# W981n — Migration Triage (untracked migrations vs W971b)

Lane: W981n · Campaign: xaas v26.10.6 · Date: 2026-10-07
Branch: `feat/playwright-surface` (read-only triage; nothing modified except this receipt + a triage appendix in `w971b-migration-replay.md`). No commits.

## 1. Untracked files under priv/repo/migrations/ (exact names/mtimes)

`git status --porcelain priv/repo/migrations/` → 3 untracked:

| file | mtime | bytes |
|---|---|---|
| `20261007111457_add_ash_onetime_logical_partitions.exs` | Oct 7 07:56 | 4976 |
| `20261007120000_dedup_orgless_epochs_then_unique_index.exs` | Oct 7 04:36 | 3205 |
| `20261007250000_add_org_id_to_billing_approval_tables.exs` | Oct 7 08:16 | 1396 |

All other `20261007*` migrations are tracked at HEAD (000000, 010000, 210000,
220000, 230000, 231000, 240000).

## 2. Authorship / completeness / down idempotency

### 20261007111457_add_ash_onetime_logical_partitions.exs — W971b, complete, ALIVE

Self-annotated in-file: "Replay-safe (W971b)" comments on `add_partition_column`
(`column_exists?` guard via `information_schema`) and
`replace_collision_constraint` (`constraint_exists?` guard). Matches W971b's
receipt description exactly. Complete and compile-shaped.

down: **NOT idempotent on the objects-absent state** — `restore_global_collision`
issues unguarded `DROP CONSTRAINT` / `DROP COLUMN` without `IF EXISTS`, so a
rollback on a DB that never had the objects errors. W971b's falsifier only
exercised up-direction replay and the objects-present/versions-absent up
round-trip; down-on-absent is untested/unhandled. Not a defect for the stated
hazard (versions-absent → up), but the down path is one-directional. Also note:
`column_exists?`/`constraint_exists?` query `table_name` without schema
qualification, fine for the default `public` schema only.

### 20261007120000_dedup_orgless_epochs_then_unique_index.exs — W804, complete, ALIVE

Not W971b-authored: moduledoc attributes it to "Lane W804 — repair step for
W752 blocker F2" (dedup org-less `(run_id, cycle)` duplicates in
`ultracode_epochs` before re-attempting W737's 20261007010000 partial unique
index). Complete, self-contained; deterministic keep-rule documented. Idempotent
by construction (`create_if_not_exists` + DELETE affecting 0 rows when clean).

down: idempotent (`drop_if_exists`); deleted duplicate rows deliberately not
resurrected. ALIVE.

### 20261007250000_add_org_id_to_billing_approval_tables.exs — W970a (claimed), complete, down NOT idempotent

Moduledoc self-attributes: "SPEC-07 (W729-GAP-3, lane W970a design-wave 6)". Discrepancy: `w905-design-gap-specs.md` row SPEC-07 attributes SPEC-07 to
**W975b (design-wave 4)**, and the SPEC-07 body says "Migration: likely none
(org_id column exists as loose string)". Neither `w970a-*.md` nor `w975b-*.md`
receipt exists on disk (ls 2026-10-07). Attribution rests solely on the file's
moduledoc — **ownership UNVERIFIED (PARTIAL_ALIVE)**. The nullable-org_id +
per-table index is consistent with the SPEC-07 design intent and the W969f
`global?(true)` deviation acceptance, but no receipt names 20261007250000. The
only other reference to the version number in docs/ is W981h's integration
receipt (this triage's own prompt source).

Content: adds nullable `org_id :text` + btree index to the four billing
approval tables lacking any org column
(pricing_overrides / quota_overrides / tier_downgrades /
invoice_reconciliation_approves). Deliberately nullable per Ash
attribute-strategy global-row semantics.

down: **NOT idempotent on the objects-absent state** — unguarded
`alter/add :org_id` + `create index` (no `add_if_not_exists`/`if not exists`),
so replay of up is not guarded either (would raise duplicate_column /
duplicate index on objects-present/versions-absent DBs — exactly the W971b
hazard class, unguarded). If W971b's replay-safety standard applies to
direct-DDL-hazard migrations, 250000 is **unguarded on replay**.

### Cross-check: W971b's four versions vs disk

| W971b version | on disk | tracked? | mapping |
|---|---|---|---|
| 111457 | yes | untracked (working-tree only) | same file, same timestamp W971b claims |
| 120000 | yes | untracked; W971b receipt has a path typo (`priv/repo/20261007120000...` — actual path is `priv/repo/migrations/...`) | same file |
| 210000 | yes | tracked at HEAD | same file |
| 220000 | yes | tracked at HEAD | same file |
| 250000 | yes | untracked | NOT W971b's — W970a-claimed (SPEC-07) |

W971b's migrations are NOT missing on disk — no BLOCKED(artifact-missing).
The "does not match W981h's stated versions" framing in the task was an
artifact of (a) W971b's path typo on 120000 and (b) 250000 belonging to
another lane. Mapping resolves cleanly for 111457/120000.

## 3. schema_migrations / version conflicts

No version duplicates: 111457, 120000, 250000 each appear exactly once in
`priv/repo/migrations/`; no committed migration shares any of the three
versions. No refuse condition.

## 4. Disposition

| file | author | complete | up replay-safe | down idempotent | standing |
|---|---|---|---|---|---|
| 111457 | W971b | yes | yes (guarded) | NO (unguarded DROP CONSTRAINT/COLUMN in down) | ALIVE (up hazard only) |
| 120000 | W804 | yes | yes (create_if_not_exists + idempotent DELETE) | yes (drop_if_exists) | ALIVE |
| 250000 | W970a (claimed, unverified — no receipt; w905 attributes SPEC-07 to W975b) | yes | NO (unguarded alter/create index — the exact W971b hazard class) | NO | PARTIAL_ALIVE (ownership UNVERIFIED) |

## Falsifiers

- F1: `git status --porcelain priv/repo/migrations/` — if untracked set ≠ the
  3 listed, this triage is stale.
- F2: `grep -c "Replay-safe (W971b)" priv/repo/migrations/20261007111457_add_ash_onetime_logical_partitions.exs`
  → ≥2 confirms W971b authorship of 111457.
- F3: `ls docs/sjira/v26.10.6/plans/w970a-*.md w975b-*.md` — any present file
  would supersede the "no receipt names 250000" claim.
- F4: grep 250000's moduledoc line for W970a vs w905's SPEC-07 row (W975b) —
  the discrepancy stands unless a W970a/W975b receipt lands naming it.
