# W151 — dev DB migration convergence receipt

- Subject: /Users/sac/xaas @ feat/playwright-surface (d1db2b03 working tree, uncommitted)
- Task: bring xaas_dev current after W113 `Phoenix.Ecto.PendingMigrationError`
- Date: 2026-10-06

## Actions (migrate only; no rollback/drop; no git)

1. `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=dev mix ecto.migrate`
   - Result: `13:18:41.469 [info] Migrations already up` (both repos)
   - Re-run to converge: same result (`Migrations already up` x2)
2. `MIX_ENV=dev mix ecto.migrations`
   - Repos: Xaas.LegacyRepo, Xaas.Repo
   - Pending (down) migrations: **0** for Xaas.Repo
   - Tail confirmed up: 20261005000000 add_witness_tables,
     20261005235901 add_graphlaw_engine_registry,
     20261006000000 repair_witness_certified_receipts (W97 corrective, applied 2026-10-06 20:01:03)
   - Note: an intermediate `grep -c "down"` returned 1 — false positive from the
     substring in migration name `...approval_tier_downgrade`; actual status lines
     show all up.
3. Smoke: `Xaas.Repo.query!("SELECT count(*) FROM witness_certified_receipts")`
   - `num_rows=1 row=[[2]]` — table exists and is queryable post-repair.
   - `schema_migrations` direct check: versions 20260821082318 and 20261006000000
     both recorded (2026-09-09 / 2026-10-06 20:01:03 respectively).

## Standing

- xaas_dev is current: zero pending migrations on both repos; W97's corrective
  migration 20261006000000 applied. W113's PendingMigrationError precondition cleared.
- Non-goals held: no rollback, no drop, no git operations. Grafana/PromEx and
  AshA2A receipt-store warnings in app startup output are pre-existing, unrelated
  to migration state.
