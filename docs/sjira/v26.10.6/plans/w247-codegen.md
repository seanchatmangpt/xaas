# W247 Codegen Closure — v26.10.6 Convergence

Lane: Integration W247, repo `/Users/sac/xaas`, branch `feat/playwright-surface`, 2026-10-06.

## Finding

`mix ash.codegen add_w247_convergence_snapshots` regenerated a migration
(`20261006212508_add_w247_convergence_snapshots.exs`) whose DDL duplicated, column-for-column,
DDL already applied by earlier handwritten migrations that predated codegen snapshots:

| Generated element | Already covered by |
|---|---|
| `actuation_intents` / `actuation_receipts` spg_* columns | `20260925061500_add_spg_identity_to_actuation_evidence` |
| `billing_revenue_recognitions` table | `20260823004500_add_fibo_revenue_recognitions` (+ revision pin migration) |
| `ultracode_runs` frontier/suspended_at columns | `20260927214500_add_ultracode_frontier_closure` |
| `graphlaw_engine_limits`, `graphlaw_capabilities` | `20261005235901_add_graphlaw_engine_registry` |
| `witness_verification_keys`, `witness_certified_receipts` | `20261005000000_add_witness_tables` + `20261006000000_repair_witness_certified_receipts` |

Initial `mix ecto.migrate` failed with `duplicate_column` on
`actuation_intents.spg_graph_id` — proof the DB was already at target shape and the
generated DDL was a redundant duplicate, **not destructive** (pure additive duplication,
no drops of populated data anywhere in `up`; `down` only removes what `up` added).

## Resolution

The migration was rewritten to a documented snapshot-reconciliation **no-op**
(`up`/`down` both `:ok`): the schema is fully covered by the earlier handwritten
migrations (which run before it on fresh databases too), so the migration's only
lawful job is stamping the reconciled codegen snapshots. The 8 snapshot JSONs
(`priv/resource_snapshots/repo/{actuation_intents,actuation_receipts,ultracode_runs,graphlaw_engine_limits,billing_revenue_recognitions,graphlaw_capabilities,witness_verification_keys,witness_certified_receipts}/20261006*.json`)
are the load-bearing output.

## Gates (real output)

| Gate | Result |
|---|---|
| `MIX_ENV=test mix ash.codegen add_w247_convergence_snapshots` | generated 1 migration + 8 snapshots |
| `MIX_ENV=test mix ecto.migrate` | first run `duplicate_column` (pre-rewrite); post-rewrite: `== Migrated 20261006212508 in 0.0s` (fresh `xaas_test` create) |
| `MIX_ENV=test mix ash.codegen --check` | exit 0, clean (only pre-existing `EctoMigrationDefault` warning) |
| `mix test witness_live + actuation_refusal_negative + health_controller` | **15 passed**, 0 failed, exit 0 |

## Standing

ALIVE for the v26.10.6 codegen surface. W223 pending-codegen finding closed.

## Supersession note (coordinator, 2026-10-06)
A concurrent lane (W258) was dispatched to deduplicate this migration before W247's no-op resolution landed; it was stood down and re-tasked to verification-only (fresh-chain + codegen --check + recording the supersession). The no-op body is authoritative.
