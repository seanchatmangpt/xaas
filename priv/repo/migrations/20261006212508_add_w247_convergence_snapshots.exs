defmodule Xaas.Repo.Migrations.AddW247ConvergenceSnapshots do
  @moduledoc """
  Snapshot reconciliation only — intentional no-op on schema.

  `mix ash.codegen` regenerated DDL that already exists via earlier
  handwritten migrations (those runs predated codegen snapshots, so the
  generator saw the resources as new):

  - `20260925061500_add_spg_identity_to_actuation_evidence` — spg_* columns
    on actuation_intents / actuation_receipts
  - `20260823004500_add_fibo_revenue_recognitions` (+ revision pin) —
    billing_revenue_recognitions
  - `20260927214500_add_ultracode_frontier_closure` — ultracode_runs
    frontier/suspended_at columns
  - `20261005235901_add_graphlaw_engine_registry` — graphlaw_engine_limits,
    graphlaw_capabilities
  - `20261005000000_add_witness_tables` (+ `20261006000000_repair_witness_certified_receipts`)
    — witness_verification_keys, witness_certified_receipts

  Applying the regenerated DDL verbatim fails on databases already at the
  current shape (`duplicate_column` / `duplicate_table`). The DDL content
  was verified identical to the earlier migrations (column-for-column),
  so this migration exists to stamp the reconciled codegen snapshots
  without altering schema.
  """

  use Ecto.Migration

  def up do
    :ok
  end

  def down do
    :ok
  end
end
