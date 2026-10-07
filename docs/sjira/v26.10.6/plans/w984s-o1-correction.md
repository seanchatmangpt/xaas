# W984s — Runbook O1 correction note (lane receipt)

- Lane: W984s, campaign v26.10.6, repo `/Users/sac/xaas`, branch
  `feat/playwright-surface`. No commits made. No mix commands run (read-only
  documentation lane).
- Files touched (both uncommitted, per lane contract):
  - `docs/sjira/v26.10.6/_INTEGRATION_RUNBOOK.md` — dated correction note
    appended to step (O1).
  - this receipt.

## Basis

W984o's read-only live-DB precheck
(`docs/sjira/v26.10.6/plans/w984o-devdb-precheck.md`) REFUTED the runbook O1
operator step (plain `mix ecto.migrate` on xaas_dev, W982y verdict):

- 20261007010000 (dup-sensitive partial unique index) sorts BEFORE its own
  dedup repair 20261007120000.
- Live xaas_dev holds 90 org-less dup groups / 109 doomed epochs /
  42 receipts referencing doomed epochs.
- Plain migrate therefore aborts at 010000 with a unique-violation; the
  109 doomed rows are never removed, so the failure self-repeats.
- W982y's fresh-empty-DB ALIVE verdict does not transfer to the dirty dataset.

## Note text appended to O1 (verbatim)

**CORRECTION (2026-10-07, lane W984s)** — the plain `mix ecto.migrate`
operator step above is REFUTED by W984o's read-only precheck on live
xaas_dev (`plans/w984o-devdb-precheck.md`): the dup-sensitive partial
unique index migration (20261007010000) sorts BEFORE its own dedup repair
(20261007120000), so plain migrate aborts at 010000 with a unique-violation
(90 org-less dup groups / 109 doomed rows present), later migrations never
run, and the failure self-repeats on every re-run. W982y's fresh-DB ALIVE
verdict does not transfer to the current dirty dataset. Working handoff
(idempotent, no code edits; per w984o + w982c):

1. Stop the native phx server first — oban (19 idle LISTEN conns) could
   insert new org-less epochs between pre-pass and the 010000 index build,
   re-introducing a dup.
2. psql pre-pass executing 20261007120000's reparent_sql / delete_sql
   verbatim (idempotent; expected per live counts: 42 receipts reparented,
   109 doomed epochs deleted).
3. `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=dev mix ecto.migrate` — applies all
   9 pending; 20261007120000's dedup is then a no-op.

Then resume step (O2) server restart.

## Standing

- Correction note: landed (Edit verified by tool success; text on disk).
- W984o precheck standing: precheck complete, migration un-executed
  (read-only lane) — carried over unchanged.
- Shared-DB authority remains with the operator; O1 stays
  BLOCKED(shared-db-authority) with the corrected three-step handoff.
- Falsifier for this note: if plain `mix ecto.migrate` on the current
  xaas_dev succeeds in order at 010000 without the pre-pass, the correction
  is refuted and W984o §6 overturned.
