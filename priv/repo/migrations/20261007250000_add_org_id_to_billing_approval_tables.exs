defmodule Xaas.Repo.Migrations.AddOrgIdToBillingApprovalTables do
  @moduledoc """
  SPEC-07 (W905 W729-GAP-3, lane W970a design-wave 6): back the new
  `multitenancy strategy :attribute :org_id` blocks on the eight
  `Xaas.Billing` Ash resources.

  Four tables already carry an `org_id` column (billing_subscriptions,
  billing_revenue_recognitions, approval_sla_credit_applies,
  approval_patch_sla_credit_applies). The other four approval tables had
  no org column at all; this adds a nullable `org_id` (matching the
  repo-wide "loose string org_id" convention, deliberately NOT a
  belongs_to FK) plus a btree index per table so tenant-filtered reads
  are index-backed.

  Columns are deliberately nullable: rows created without a tenant stay
  global rows (Ash attribute-strategy semantics: `nil` org_id matches
  global reads), so no existing fixture or caller breaks. Forcing
  NOT NULL here would break every existing create without a tenant and
  is the coordinator's call, not this lane's.
  """

  use Ecto.Migration

  @tables_with_column [
    "approval_pricing_overrides",
    "approval_quota_overrides",
    "approval_tier_downgrades",
    "approval_invoice_reconciliation_approves"
  ]

  def change do
    for table <- @tables_with_column do
      alter table(table) do
        add :org_id, :text, null: true
      end

      create index(table, [:org_id])
    end
  end
end
