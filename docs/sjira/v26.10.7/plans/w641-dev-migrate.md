# W641 — Shared xaas_dev DB transition (W984s three-step handoff executed)

- Date: 2026-10-07, lane W641, repo `/Users/sac/xaas`, branch
  `feat/playwright-surface`. No code edits, no commits. Operator-delegated
  authority to execute `MIX_ENV=dev mix ecto.migrate` against the shared
  `xaas_dev` per the W984s three-step handoff
  (`docs/sjira/v26.10.6/plans/w984s-o1-correction.md`), with W633's
  refined blocker picture (`plans/w633-playwright-live.md`).
- `PATH=$HOME/.asdf/shims:$PATH` throughout (asdf elixir 1.20.2-otp-28,
  per CLAUDE.md toolchain pin).

## Step 1 — quiescence check

No listening phx server: `lsof -iTCP:4000/:4033 -sTCP:LISTEN` → empty.
BUT 21 idle connections to xaas_dev existed, ALL held by one foreign beam:
PID 37453, `mix run -e Application.put_env(:xaas, :marketplace_catalog_source, ...) --no-halt`
(up since 07:00, includes one `LISTEN "public.oban_insert"` conn). Not
killed (foreign lane's process, fanout law). Quiescence verified instead:

- oban_jobs: 0 running/available (26887 completed, 2674 discarded, 2 cancelled)
- latest `ultracode_epochs.inserted_at` = 2026-10-01 10:36 (no writes since)

Safe window declared on those two observations.

## Step 2 — psql pre-pass (verbatim 20261007120000 reparent_sql + delete_sql)

Single transaction, verbatim SQL read from
`priv/repo/migrations/20261007120000_dedup_orgless_epochs_then_unique_index.exs`
(reparent_sql/0 then delete_sql/0, same order). Script: `/tmp/w641_prepass.sql`.

```
BEGIN
 dup_groups_before           = 90
 receipts_on_doomed_before   = 1157
UPDATE 1157      (reparent_sql)
DELETE 109       (delete_sql)
 dup_groups_after            = 0
 orgless_total_after         = 1261  (was 1370)
COMMIT
```

Count reconciliation vs w984o: dup groups 90 = match. Doomed epochs 109 =
match exactly (my pre-count query reported 199 rows-in-dup-groups;
199 − 90 groups = 109 doomed). Receipts on doomed epochs: 1157 vs w984o's
42 — the receipts table grew between w984o's snapshot and now; the
reparent count reflects the live value, the doomed-epoch count is
w984o-exact. 1370 orgless − 109 deleted = 1261 (consistent).

## Step 3 — first migrate

`PATH=$HOME/.asdf/shims:$PATH MIX_ENV=dev mix ecto.migrate`:

- First attempt hit a compile-freeze violation: untracked
  `lib/xaas/semantics/graphlaw_wasm.ex` mid-write by another lane
  (`defp outside module` at :507, then `instantiation_imports/2` and
  `&&&`/`>>>` undefined). Watched mtime per the compile-freeze SLA; owner
  fixed their file at ~14:12-14:14 without my intervention. No unblock fix
  applied by this lane. Second attempt: compiled clean.
- Migrate ran all 9 pending. Captured tail (last migration):

```
14:14:55.764 [info] == Running 20261007250000 AddOrgIdToBillingApprovalTables.change/0 forward
14:14:55.764 [info] alter table approval_pricing_overrides
14:14:55.765 [info] create index approval_pricing_overrides_org_id_index
... (approval_quota_overrides / approval_tier_downgrades / approval_invoice_reconciliation_approves, each + org_id_index)
14:14:55.770 [info] == Migrated 20261007250000 in 0.0s
```

- 20261007120000 ran as a no-op by construction (dups already removed in
  step 2; post-migrate dup-group count re-verified 0).

## Step 4 — rerun

```
14:15:12.393 [info] Migrations already up
14:15:12.424 [info] Migrations already up
```

(both repos — Xaas.Repo and LegacyRepo).

## Step 5 — verification (real psql against xaas_dev)

- All 9 pending versions recorded in `schema_migrations`:
  20261007010000, 111457, 120000, 210000, 220000, 230000, 231000, 240000,
  250000.
- Head: `SELECT max(version) FROM schema_migrations` → **20261007250000**
  (84 versions total).
- `ultracode_epochs_orgless_run_cycle_index` EXISTS.
- `org_id` present on all four billing approval tables
  (approval_pricing_overrides, approval_quota_overrides,
  approval_tier_downgrades, approval_invoice_reconciliation_approves).
- Dup groups after migrate: 0.

## Standing

- **ALIVE** — shared xaas_dev migrated clean to head 20261007250000 via
  the documented three-step handoff; O1's BLOCKED(shared-db-authority) is
  lifted for this dataset state. Every future plain
  `MIX_ENV=dev mix ecto.migrate` on xaas_dev now succeeds in order.
- Disclosure: (a) a foreign beam (PID 37453) remains connected to xaas_dev
  holding an oban LISTEN conn — quiescent at execution time, not killed;
  (b) first migrate attempt was blocked by a concurrent lane's mid-write
  compile break in `lib/xaas/semantics/graphlaw_wasm.ex`, resolved by that
  lane within the SLA window, zero action by this lane.
- Falsifier: a fresh `MIX_ENV=dev mix ecto.migrate` on xaas_dev reporting
  anything other than "Migrations already up", or `max(version)` ≠
  20261007250000, refutes this receipt.
