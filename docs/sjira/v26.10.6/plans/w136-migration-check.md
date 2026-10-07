# W136 — Migration safety check: 20261006000000_repair_witness_certified_receipts

Lane W136, v26.10.6 convergence, repo /Users/sac/xaas. Verification executed 2026-10-06.

## 1. Static read (fresh-DB no-op confirmation)

`priv/repo/migrations/20261006000000_repair_witness_certified_receipts.exs` is conditional-by-construction:

- `add_if_not_exists(:inserted_at, :utc_datetime_usec, ...)` and `add_if_not_exists(:updated_at, :utc_datetime_usec, ...)` — Postgres skips existing columns.
- `verified_at` naive→timestamptz retype is guarded by an `information_schema.columns` DO block that only fires when the column is `timestamp without time zone`.
- `down/0` is `:ok` (corrective, non-reversible by design).

## 2. Fresh-DB path (real execution)

Isolated lane run: `MIX_BUILD_ROOT=_build-w136`, `MIX_TEST_PARTITION=_w136` → DB `xaas_test_w136`. Full drop→verify→create→migrate→verify cycle, exit 0.

### Raw log A — atomic drop/create/migrate (verbatim)

```
The database for Xaas.LegacyRepo has already been dropped
The database for Xaas.Repo has already been dropped
0
XAAS_TEST_W136_GONE
=== CREATE ===
The database for Xaas.LegacyRepo has been created
The database for Xaas.Repo has already been created
=== MIGRATE ===
13:39:02.688 [info] == Migrated 20260927214500 in 0.0s
13:39:02.689 [info] == Running 20261005000000 Xaas.Repo.Migrations.AddWitnessTables.up/0
13:39:02.700 [info] == Migrated 20261005000000 in 0.0s
13:39:02.702 [info] == Running 20261005235901 Xaas.Repo.Migrations.AddGraphlawEngineRegistry.up/0
13:39:02.713 [info] == Migrated 20261005235901 in 0.0s
13:39:02.715 [info] == Running 20261006000000 Xaas.Repo.Migrations.RepairWitnessCertifiedReceipts.up/0
13:39:02.715 [info] column "updated_at" of relation "witness_certified_receipts" already exists, skipping
13:39:02.727 [info] == Migrated 20261006000000 in 0.0s
    version
----------------
 20261006000000
 20261005235901
 20261005000000
(3 rows)
```

`20261006000000` ran on a verified-fresh database and completed as a no-op (`already exists, skipping`), exit 0.

## 3. DB-backed suite on the fresh schema (verbatim)

`PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-w136 MIX_TEST_PARTITION=_w136 mix test test/xaas_web/live/witness_live_test.exs test/xaas/actuation_refusal_negative_test.exs`

```
........
Finished in 1.8 seconds (0.9s async, 0.8s sync)

Result: 8 passed
[os_mon] memory supervisor port (memsup): Erlang has closed
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed

[exited with code 0]
```

## 4. Standing

ALIVE (fresh-DB path, exact subject 20261006000000). The migration is safe on fresh DBs — it runs as the designed no-op with `already exists, skipping`.

## Environment notes

- Ran in isolated build root `_build-w136` under asdf elixir 1.20.2-otp-28 because the shared `_build/test` had a failing ash_surface path-dep compile (pre-existing, unrelated to this migration; `deps.compile ash_surface --force` failed the same way in the shared root while a fresh build root compiled it clean).
- The default `xaas_test` DB was busy with another lane's connections (`ERROR 55006 object_in_use` on drop), so the built-in `MIX_TEST_PARTITION` isolation was used instead.
- `_build-w136` deletion was attempted but denied by the permission system; the directory remains at /Users/sac/xaas/_build-w136 (lane lease cleanup owed at integration).
