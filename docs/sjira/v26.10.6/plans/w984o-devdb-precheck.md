# W984o — xaas_dev migrate pre-flight (read-only precheck receipt)

- Lane: W984o, campaign v26.10.6, repo `/Users/sac/xaas`
- Date: 2026-10-07
- Mode: READ-ONLY on `xaas_dev` (SELECT/information_schema only; zero mutations).
  Shared-DB authority stays with the operator.
- Sources: live psql against `xaas_dev` (all outputs below are actual query
  output), migration files under `priv/repo/migrations/`.

## 1. DB + connection/lock state (actual psql output)

`pg_stat_activity where datname='xaas_dev'`: 22 rows at query time.
- 1 row = this psql query itself.
- 19 rows, user `postgres`, **idle**, last queries `COMMIT` /
  `CREATE TABLE IF NOT EXISTS "schema_migrations"...` / `LISTEN "public.oban_insert"`
  → **the live native phx server IS running** (its Ecto pool, oban listeners
  pids 37839–37866).
- 2 rows, user `postgres`, idle, `COMMIT` (additional pool or test residue).

`pg_locks` (joined to xaas_dev): `relation | 1`; waiters:
`select count(*) from pg_locks where not granted` → **0**.
No migration locks held, no blocked sessions. No exclusive locks on any table.

## 2. Pending migrations (schema_migrations vs disk)

Applied head in DB: `20261007000000`. `comm -23` (disk minus DB):

```
20261007010000  add_orgless_run_cycle_partial_unique_index   (W737)
20261007111457  add_ash_onetime_logical_partitions
20261007120000  dedup_orgless_epochs_then_unique_index        (W804/W982c)
20261007210000  add_capability_class_to_graphlaw_capabilities
20261007220000  add_used_at_and_use_count_to_audit_export_tokens
20261007230000  add_reverses_transfer_id_to_ledger_transfers
20261007231000  add_previous_status_to_capability_liveness_receipts
20261007240000  add_castle_run_id_to_incidents
20261007250000  add_org_id_to_billing_approval_tables
```

9 pending versions.

## 3. Objects-present-versions-absent sweep (W971b hazard class)

All queries are `information_schema`/`pg_indexes` against xaas_dev; every
target returned **absent** — no objects-present drift anywhere:

```
idx ultracode_epochs_orgless_run_cycle_index: absent
col graphlaw_capabilities.capability_class: absent
col audit_export_tokens.used_at: absent
col audit_export_tokens.use_count: absent
col ledger_transfers.reverses_transfer_id: absent
idx ledger_transfers_reverses_transfer_id_index: absent
col capability_liveness_receipts.previous_status: absent
col incidents.castle_run_id: absent
idx incidents_castle_run_id_index: absent
approval_pricing_overrides.org_id: absent
approval_quota_overrides.org_id: absent
approval_tier_downgrades.org_id: absent
approval_invoice_reconciliation_approves.org_id: absent
col ash_onetime_idempotency_claims.logical_partition: absent
col ash_onetime_nonce_claims.logical_partition: absent
col ash_onetime_response_payloads.logical_partition: absent
constraint ash_onetime_idempotency_claims_logical_collision_key: absent
```

(Reproducible batch: `psql -d xaas_dev -f /tmp/w984o.sql`. Every check came
back `absent`.)

Conclusion: **zero objects-present-versions-absent drift** on xaas_dev.
Guarded migrations (`column_exists?`/`if_not_exists`) would have tolerated it
anyway; the two unguarded `change` migrations (20261007230000, 20261007240000,
20261007250000) run against genuinely absent objects → clean.

## 4. W982c FK hazard: org-less epoch duplicates (counts, no mutation)

Actual output:

```
fk ultracode_receipts_epoch_id_fkey: EXISTS
orgless dup groups: 90
orgless doomed rows: 109   (rn>1 under keep-earliest-inserted_at, tie-break smallest id)
receipts referencing doomed epochs: 42
```

Prediction if/when 20261007120000 (or the identical SQL) runs:
**reparent will move 42 `ultracode_receipts` rows to survivors and DELETE
109 duplicate `ultracode_epochs` rows.** Org-scoped rows untouched.

## 5. Per-migration risk table

| version | migration | risk |
|---|---|---|
| 20261007010000 | org-less partial unique index (unguarded-ish `create_if_not_exists`) | **WILL FAIL on xaas_dev as ordered** — 90 dup groups / 109 doomed rows present; unique index build raises unique-violation. It runs FIRST among pending. |
| 20261007111457 | ash_onetime logical partitions | clean (all objects absent; migration is guard-wrapped; fresh first run) |
| 20261007120000 | dedup + index | clean as SQL, but **unreachable via plain `mix ecto.migrate`** (see verdict) |
| 20261007210000 | capability_class + backfill | clean (column absent; guarded anyway) |
| 20261007220000 | used_at/use_count | clean (guarded `add_if_not_exists`; cols absent) |
| 20261007230000 | reverses_transfer_id + partial unique index | clean (both objects absent) |
| 20261007231000 | previous_status | clean |
| 20261007240000 | castle_run_id + index | clean |
| 20261007250000 | org_id on 4 billing tables + indexes | clean (all 4 cols absent) |

## 6. Operator verdict

**Plain `mix ecto.migrate` is NOT a working one-command handoff on the
current data.** Ordering defect: the dup-sensitive index migration
(20261007010000) sorts BEFORE its own dedup repair (20261007120000), so
`mix ecto.migrate` aborts at 20261007010000 with a unique-violation
(predicted from counts in §4), later migrations never execute, and the
failure self-repeats on every re-run (109 doomed rows never removed).

Working handoff (still one command each, no code edits, idempotent):

```bash
# 1. Pre-pass: run W982c's exact reparent+delete SQL (identical to 20261007120000; idempotent)
psql -d xaas_dev -c "UPDATE ultracode_receipts r SET epoch_id = survivor.survivor_id FROM (SELECT e.id AS doomed_id, first_value(e.id) OVER (PARTITION BY e.run_id, e.cycle ORDER BY e.inserted_at ASC, e.id ASC) AS survivor_id FROM ultracode_epochs e WHERE e.org_id IS NULL AND EXISTS (SELECT 1 FROM ultracode_epochs e2 WHERE e2.org_id IS NULL AND e2.run_id = e.run_id AND e2.cycle = e.cycle AND e2.id <> e.id)) survivor WHERE r.epoch_id = survivor.doomed_id"
psql -d xaas_dev -c "DELETE FROM ultracode_epochs e USING (SELECT id, row_number() OVER (PARTITION BY run_id, cycle ORDER BY inserted_at ASC, id ASC) AS rn FROM ultracode_epochs WHERE org_id IS NULL) ranked WHERE e.id = ranked.id AND ranked.rn > 1"
# 2. Then the single command:
mix ecto.migrate
```

Expected migrate outcome after the pre-pass: 9 versions applied
(20261007010000 … 20261007250000); 20261007120000's dedup becomes a no-op
(0 reparented / 0 deleted — already done by the pre-pass) and its
`create_if_not_exists` is a no-op after 010000. Data consequence: 42
receipt rows reparented, 109 duplicate epochs deleted (once, by whichever
path runs first).

Precondition (server coexistence): the live phx server holds 19 idle
connections with oban `LISTEN`; no locks held, 0 waiters. Migrations here are
fast small-table DDL plus one unique-index build on `ultracode_epochs` —
running with the server up risks oban inserting new org-less epochs mid-index
build (re-introducing a dup between pre-pass and 010000). **Recommendation:
stop the phx server first, run the pre-pass + `mix ecto.migrate`, restart.**
Not a hard blocker; a risk gate against the exact hazard class being repaired.

Standing: precheck complete; migration itself un-executed (read-only lane).
Remaining UNKNOWN: none blocking; the only conditional is the ordering defect
in §6, fully mitigated by the two-command sequence.
