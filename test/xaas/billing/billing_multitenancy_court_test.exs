defmodule Xaas.Billing.BillingMultitenancyCourtTest do
  @moduledoc """
  SPEC-07 court (W970a first half; W982p second half). Real Postgres, no mocks.

  Falsifier: delete any `multitenancy` block covered by @resources (test 1/2)
  or @resources_second_half (test 4/5) in lib/xaas/billing/ -- schema court
  fails (introspection nil), isolation court fails (cross-tenant row
  visible). Test 3 is the Chesterton fence (tenant-less callers unchanged;
  a required tenant fails it). Second-half blocks and extension: lane W982p,
  docs/sjira/v26.10.6/plans/w982p-spec07-completion.md.
  """

  use ExUnit.Case, async: true

  require Ash.Query

  alias Xaas.Billing.Subscription

  @resources [
    Xaas.Billing.ApprovalPricingOverride,
    Xaas.Billing.ApprovalQuotaOverride,
    Xaas.Billing.ApprovalInvoiceReconciliationApprove,
    Xaas.Billing.ApprovalTierDowngrade
  ]

  @resources_second_half [
    Xaas.Billing.Subscription,
    Xaas.Billing.ApprovalSlaCreditApply,
    Xaas.Billing.ApprovalPatchSlaCreditApply,
    Xaas.Billing.RevenueRecognition
  ]

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_org!(suffix) do
    slug = "w982p-court-#{suffix}-#{System.unique_integer()}"

    Xaas.Accounts.Org
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
      assert hd(rows_a).id == row_a.id
      assert hd(rows_a).org_id == org_a.id

      assert_raise Ash.Error.Invalid, fn ->
        Ash.get!(resource, row_b.id, tenant: org_a.id, authorize?: false)
      end

      assert Ash.get!(resource, row_b.id, tenant: org_b.id, authorize?: false).id == row_b.id
    end
  end

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

  # -- SPEC-07 second half (lane W982p) -------------------------------------

  defp mint_second_half!(Xaas.Billing.Subscription, tenant_id) do
    Subscription
    |> Ash.Changeset.for_create(:create, %{
        org_id: tenant_id,
        stripe_customer_id: "cus_#{System.unique_integer()}",
        stripe_subscription_id: "sub_#{System.unique_integer()}"
      }, tenant: tenant_id, authorize?: false)
    |> Ash.create!()
  end

  defp mint_second_half!(Xaas.Billing.RevenueRecognition, tenant_id) do
    # Real admitted path only (ReactorContext fence): Xaas.Actuation via
    # Revenue.recognize/3. No admission context hand-forged. Returns the
    # actuation envelope; use .result (the recognition record).
    key = "w982p-court-#{System.unique_integer([:positive])}"

    {:ok, envelope} =
      Xaas.Billing.Revenue.recognize(:service_fee, %{
        org_id: tenant_id,
        accounting_classification: "revenue",
        recognition_basis: "earned",
        amount: "10.00",
        currency: "USD",
        evidence: %{}
      },
      idempotency_key: key,
      authority: %{kind: "multitenancy_court", evidence_ref: key},
      tenant: tenant_id)

    envelope.result
  end

  defp mint_second_half!(resource, tenant_id) do
    resource
    |> Ash.Changeset.for_create(:create, %{
        requested_by: "req-#{tenant_id}",
        org_id: tenant_id,
        credit_amount_cents: 100
      }, tenant: tenant_id, authorize?: false)
    |> Ash.create!()
  end

  test "4. schema court (second half): each resource carries attribute-strategy multitenancy on :org_id" do
    for resource <- @resources_second_half do
      assert Ash.Resource.Info.multitenancy_strategy(resource) == :attribute
      assert Ash.Resource.Info.multitenancy_attribute(resource) == :org_id
      assert Ash.Resource.Info.multitenancy_global?(resource) == true
    end
  end

  test "5. cross-org isolation (second half): tenant-bound read is hard-filtered, never merged" do
    for resource <- @resources_second_half do
      org_a = create_org!("b-a")
      org_b = create_org!("b-b")

      row_a = mint_second_half!(resource, org_a.id)
      row_b = mint_second_half!(resource, org_b.id)

      assert row_a.org_id == org_a.id
      assert row_b.org_id == org_b.id

      rows_a = resource |> Ash.Query.new() |> Ash.read!(tenant: org_a.id, authorize?: false)
      assert length(rows_a) == 1
      assert hd(rows_a).id == row_a.id

      assert_raise Ash.Error.Invalid, fn ->
        Ash.get!(resource, row_b.id, tenant: org_a.id, authorize?: false)
      end

      assert Ash.get!(resource, row_b.id, tenant: org_b.id, authorize?: false).id == row_b.id
    end
  end
end
