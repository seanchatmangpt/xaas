# W971c — w891 gap-triage progress fold (receipt)

- **Lane**: W971c, v26.10.6 campaign, repo `/Users/sac/xaas`, branch
  `feat/playwright-surface`. No commit (coordinator owns transitions); no build
  root (doc-only lane).
- **Task**: fold the top-10 execution progress into `w891-gap-triage.md` —
  supersede W914's "0 repaired / all in flight" footer with the landed reality.

## Subject

- `docs/sjira/v26.10.6/plans/w891-gap-triage.md` — two edits:
  1. W914 progress section heading marked
     `— SUPERSEDED by W971c footer below`, with a supersede note pointing to
     the W971c footer (the stale "0 repaired / all in flight" body kept for
     history, not deleted).
  2. New section `## Top-10 execution disposition (W971c progress fold,
     2026-10-07)` appended after the W967 reconciliation footer: a 10-row
     disposition table (top-10 item → triage # → register row → disposition →
     receipts), plus a standing note. Every disposition was read from the
     register's own current per-row statuses (grepped live from
     `w859-typed-gap-register.md`), not asserted from the repair receipts
     alone.

## Bottom line

**9 of 10 REPAIRED, 1 OPEN.** Sole residual: top-10 item 1 (triage row 29,
W804 dev `mix ecto.migrate`, OPERATOR) — register-annotated as now hazardous
(index exists via direct DDL; schema_migrations unstamped; replay hazard),
coordinator-owned.

## Receipts cited (per-row closers)

- w897-cheap-repairs.md (rows 1/5/11 + W729 approve-idempotency drift)
- w900-batch2-repairs.md (W765 GAP-A, W770 verify-first, W674-GAP-2 staging)
- w902-batch3-repairs.md (W793 remaining 2, W796-G1, W849-1/W674 verify-first)
- w852-provenance-pins.md (W849 backlog-1 owner)
- w928-gymact-hygiene.md (W674-GAP-1/2 hygiene courts 11/11 ×2)
- w935-spec16-impl.md + w940b-spec16-commit.md (W765 GAP-B/C, commit `fab56ae1`)
- w945b-batch4-repairs.md / w945c-batch5-repairs.md (W745, W750-G1, W722 gap-1,
  W849 backlog-3 witnesses; register flips)
- w804-epoch-dedup.md (W804 register annotation source)

## Concurrency note

Mid-edit, the file changed on disk: W971b appended its own `## Triage-close
footer (W971b, 2026-10-07)` after the W967 footer. My edit applied cleanly and
both footers coexist (W971c disposition at ~L187, W971b triage-close at ~L213);
no structure clobbered. W971b's receipt is `w971b-migration-replay.md` — a
different surface; no coordination conflict.

## Standing

PARTIAL_ALIVE — doc-only fold on the exact subject
(`w891-gap-triage.md` as edited on `feat/playwright-surface`, uncommitted).
Dispositions are read-from-register (observation), not new flips; this lane
changed no register row. Falsifier for the fold: any top-10 row's disposition
in the table disagreeing with `w859-typed-gap-register.md` at read time — none
did (all 10 cross-checked against register lines 20/21/32/35/36/37/39/43/45/50/54).
