# W258 Receipt — Migration Duplication Verification (v26.10.6 convergence)

Lane: W258, integration. Repo: /Users/sac/xaas. Date: 2026-10-06.

## Task superseded by W247

W254 flagged `priv/repo/migrations/20261006212508_add_w247_convergence_snapshots.exs` as
re-adding `spg_*` columns that `20260925061500_add_spg_identity_to_actuation_evidence.exs`
already added (predicted deterministic `duplicate_column` on fresh migrate). On inspection,
the migration at HEAD is W247's **no-op form** (`up/0` and `down/0` both `:ok`, moduledoc
documents the reconciliation; the 8 snapshot JSONs are the load-bearing output). Per
coordinator instruction the file was **not modified**; W258's scope became verification-only.

## Edit

None. File left byte-identical to W247's resolution.

## Fresh-chain verification (MIX_ENV=test, private partition DB `xaas_test_w258`)

Shared `xaas_test` was contended by ~84 concurrent sessions (drop/create raced twice);
verification was performed on an isolated `MIX_TEST_PARTITION=_w258` database to own the run.

- `mix ecto.create` → `The database for Xaas.Repo has been created` (fresh `xaas_test_w258`)
- `mix ecto.migrate` → full chain green, exit 0, **74 migrations applied**:
  - `20261006000000 RepairWitnessCertifiedReceipts` — conditional guards fired correctly
    ("already exists, skipping"; timestamptz DO-block executed)
  - `20261006212508 AddW247ConvergenceSnapshots` — migrated in 0.0s, no error
- Post-migrate psql on `xaas_test_w258`:
  - `schema_migrations` count = **74**
  - `spg_%` columns on `actuation_intents` / `actuation_receipts` = **4 + 4** (exactly once
    each, from `20260925061500`; zero `duplicate_column` anywhere in the chain)

## ash.codegen --check

`MIX_ENV=test mix ash.codegen --check` → **exit 0**.

## Suites

`MIX_ENV=test mix test test/xaas_web/live/witness_live_test.exs test/xaas/actuation_refusal_negative_test.exs`
→ **8 passed, 0 failures** (Reactor.Audit log noise in output is expected test-path behavior,
not a failure).

## Standing

ALIVE — fresh `ecto.create && ecto.migrate` chain is deterministic-green on a clean database,
including the no-op convergence migration. W254's `duplicate_column` finding is refuted at
current HEAD (it described the pre-W247 form of the file). No git operations performed.
