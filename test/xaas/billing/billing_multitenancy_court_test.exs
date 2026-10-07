defmodule Xaas.Billing.BillingMultitenancyCourtTest do
  @moduledoc """
  SPEC-07 (W905 W729-GAP-3, lane W970a) court. Real Postgres, no mocks.

  Falsifier: delete any of the four W970a-marked `multitenancy do
  strategy(:attribute) attribute(:org_id) end` blocks (pricing_override,
  quota_override, invoice_reconciliation_approve, tier_downgrade in
  lib/xaas/billing/) -- then test 1 fails (introspection nil) and test 2
  fails (cross-tenant row visible). Test 3 is the Chesterton fence:
  tenant-less callers unchanged; flipping `global?(true)` off fails it
  (tenant would become mandatory for every existing tenant-less caller).

  SPEC-07 second half (W975b half: subscription, approval_sla_credit_apply,
  approval_patch_sla_credit_apply, revenue_recognition) is NOT landed in
  this commit -- see w982l-spec-flip-pass.md and the w982k receipt. Its
  court extension belongs to the completing lane's receipt once its
  multitenancy blocks land in lib/xaas/billing/.
  """

  use ExUnit.Case, async: true

  require Ash.Query

  alias Xaas.Accounts.Org
  alias Xaas.Billing.Subscription

  @resources [
    Xaas.Billing.ApprovalPricingOverride,
    Xaas.Billing.ApprovalQuotaOverride,
    Xaas.Billing.ApprovalInvoiceReconciliationApprove,
    Xaas.Billing.ApprovalTierDowngrade
  ]

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_org!(suffix) do
    slug = "w970a-court-#{suffix}-#{System.unique_integer()}"

    Org
    |> Ash.Changeset.for_create(:create, %{name: slug, slug: slug}, authorize?: false)
    |> Ash.create!()
  end

  defp mint_request!(resource, tenant_id, requested_by, extra \\ %{}) do
    resource
    |> Ash.Changeset.for_create(:create, Map.merge(%{requested_by: requested_by}, extra),
      tenant: tenant_id,
      authorize?: false
    )
    |> Ash.create!()
  end

  defp mint_global!(resource, requested_by, extra \\ %{}) do
    resource
    |> Ash.Changeset.for_create(:create, Map.merge(%{requested_by: requested_by}, extra),
      authorize?: false
    )
    |> Ash.create!()
  end

  # W975b's landed Subscription block is `global?(true)`, so the tenant is
  # NOT auto-stamped on create -- org_id must be set explicitly.
  defp mint_subscription!(org_id) do
    Subscription
    |> Ash.Changeset.for_create(:create, %{
        org_id: org_id,
        tier: :pro,
        stripe_customer_id: "cus_#{System.unique_integer()}",
        stripe_subscription_id: "sub_#{System.unique_integer()}"
      }, authorize?: false)
    |> Ash.create!()
  end

  # ApprovalTierDowngrade :create requires a real subscription FK and a
  # strictly-lower requested_tier (TargetsLowerTier validation), so the
  # generic single-attribute fixture is not enough for that one resource.
  defp mint_fixture!(Xaas.Billing.ApprovalTierDowngrade, tenant_id, requested_by) do
    sub = mint_subscription!(tenant_id)
    mint_request!(Xaas.Billing.ApprovalTierDowngrade, tenant_id, requested_by, %{
      subscription_id: sub.id,
      requested_tier: :standard
    })
  end

  defp mint_fixture!(resource, tenant_id, requested_by),
    do: mint_request!(resource, tenant_id, requested_by)

  test "1. schema court: each resource carries attribute-strategy multitenancy on :org_id" do
    for resource <- @resources do
      assert Ash.Resource.Info.multitenancy_strategy(resource) == :attribute
      assert Ash.Resource.Info.multitenancy_attribute(resource) == :org_id
      assert Ash.Resource.Info.multitenancy_global?(resource) == true
    end
  end

  test "2. tenant-bound read is hard-filtered: cross-tenant row is invisible, never merged" do
    for resource <- @resources do
      org_a = create_org!("a")
      org_b = create_org!("b")

      row_a = mint_fixture!(resource, org_a.id, "req-a")
      row_b = mint_fixture!(resource, org_b.id, "req-b")

      rows_a = resource |> Ash.Query.new() |> Ash.read!(tenant: org_a.id, authorize?: false)
      assert length(rows_a) == 1
      row = hd(rows_a)
      assert row.id == row_a.id
      assert row.org_id == org_a.id

      assert_raise Ash.Error.Invalid, fn ->
        Ash.get!(resource, row_b.id, tenant: org_a.id, authorize?: false)
      end

      fetched_b = Ash.get!(resource, row_b.id, tenant: org_b.id, authorize?: false)
      assert fetched_b.id == row_b.id
    end
  end

  # Same shape as mint_fixture!/3 but the TARGET resource is created
  # tenant-less (the regression guard under test); the tier_downgrade
  # fixture still needs its real subscription FK, which itself mints
  # tenant-bound (org_id is allow_nil? false on Subscription).
  defp mint_tenantless_fixture!(Xaas.Billing.ApprovalTierDowngrade, requested_by) do
    org = create_org!("sub")
    sub = mint_subscription!(org.id)

    mint_global!(Xaas.Billing.ApprovalTierDowngrade, requested_by, %{
      subscription_id: sub.id,
      requested_tier: :standard
    })
  end

  defp mint_tenantless_fixture!(resource, requested_by),
    do: mint_global!(resource, requested_by)

  test "3. tenant-less callers unchanged (regression guard): create/read without a tenant still work" do
    for resource <- @resources do
      row = mint_tenantless_fixture!(resource, "req-global")
      assert is_nil(row.org_id)

      rows = resource |> Ash.Query.new() |> Ash.read!(authorize?: false)
      assert Enum.any?(rows, &(&1.id == row.id))
    end
  end
end
