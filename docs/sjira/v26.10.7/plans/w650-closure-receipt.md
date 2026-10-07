# W650 — Fleet Closure Receipt Draft (checklist item 5)

- Date: 2026-10-07. Lane W650, v26.10.7 fleet seal. Repo `/Users/sac/xaas`,
  branch `feat/playwright-surface`. No commits, no mix commands, writes
  limited to `docs/sjira/v26.10.7/_CLOSURE_RECEIPT.md` (DRAFT) + this
  receipt.
- Subject: draft assembled from landed receipts only; every claim cites its
  receipt path (see the draft's per-section citations and its open-items
  register).

## What was done

1. Read the source receipts for all 8 checklist sections: `w601`, `w601b`,
   `w616`, `w616b`, `w611`, `w633`, `w635`, `w636b`, `w637`, `w637b`,
   `w638`, `w641`, `w641a`, `w641b`, `w641c`, `w643`, `w648`, `w649`,
   plus v26.10.6 witnesses `w984ax`, `w984am`, `w984n`.
2. Authored `docs/sjira/v26.10.7/_CLOSURE_RECEIPT.md`, header
   **DRAFT-pending-final-runs**, with per-claim receipt citations,
   DRAFT flags, and a 10-row honest open-items register.

## Open-items checklist (as registered in the draft)

1. W984dj census re-witness — running at draft time; DRAFT until receipt lands.
2. W638 Wasmex host commit — landed-uncommitted.
3. W640 differential court — no landed receipt.
4. ash_surface version-commit + tag — BLOCKED(version-commit-pending).
5. ggen-marketplace version-commit + tag — BLOCKED(version-commit-pending).
6. ash_surface `priv/ash_surface/` projection byte-staleness vs fresh regen — OPEN.
7. ash_graphlaw ggen re-render follow-up — OPEN.
8. affidavit pack migration — BLOCKED(pack-contract-divergence).
9. ferroplan pack migration — BLOCKED(pack-capability-missing), unblock falsifier written.
10. xaas_dev migration-ordering defect — OPEN (typed, pre-existing).

## DRAFT-flag discipline

- Census witness "at cf228da6 (W633 window)" is attributed by dispatch; the
  on-disk w633 receipt witnesses 371/371 + 6/6, not a 1352 census line —
  flagged in-draft as needing a confirming citation rather than restated as
  witnessed.
- No pending item is restated as closed; each carries its typed
  DRAFT/BLOCKED/OPEN state.

## Standing

PARTIAL_ALIVE: the draft is written and grounded in 21 source receipts, but
it is DRAFT by design — final standing transfers only when open items 1–3
close, the draft's claims are re-read against the landed receipts, and the
file is committed in the seal-corpus commit.
