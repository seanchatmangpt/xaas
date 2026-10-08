defmodule Xaas.Platform.RouteApproveCourtW984fmTest do
  @moduledoc """
  W984fm probe court for the remaining state-bearing uncovered entries from
  W984fh's sixth re-census map. Per-module dispositions:

  - `Xaas.Platform.Changes.RouteFeatureFlagsApprove` and
    `Xaas.Platform.Changes.RouteProjectsApprove`: COVERED (typed
    disposition, no new test needed) -- both are real identity changes on
    the approve action-seam, and both are already exercised end-to-end
    through their resources' real `:approve` actions by
    `test/xaas/platform/platform_route_deepening_test.exs` tests (6a) and
    (6c) (maker-checker refusals + distinct-approver happy paths that
    really persist).

  - `Xaas.Billing.Validations.ApprovalTierDowngradeTargetsLowerTier`:
    three genuinely unexercised branches, courts below:

    1. the `{:error, _}` branch of the `Ash.get` on a nonexistent
       subscription ("does not reference a real subscription");
    2. the `:enterprise` rank entries of `@tier_rank` on the CURRENT side
       (a real downgrade FROM enterprise);
    3. the `:enterprise` rank entry on the REQUESTED side (requested tier
       above current, refused via the enterprise rank).

  Real sandboxed Postgres via `Xaas.Repo` + `Ecto.Adapters.SQL.Sandbox`,
  real Ash actions (`for_create` on `Xaas.Billing.ApprovalTierDowngrade`
  and `Subscription`), zero mocks. Mutation rationale per test inline.
  """

  use ExUnit.Case, async: false

  alias Xaas.Billing.ApprovalTierDowngrade
  alias Xaas.Billing.Subscription

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_subscription!(org_id, tier) do
    Subscription
    |> Ash.Changeset.for_create(:create, %{
      org_id: org_id,
      stripe_customer_id: "cus_#{System.unique_integer([:positive])}",
      tier: tier,
      status: :incomplete
    })
    |> Ash.create!(authorize?: false)
  end

  defp create_downgrade!(attrs) do
    ApprovalTierDowngrade
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create(authorize?: false)
  end

  @tag :w984fm
  test "create with a nonexistent subscription_id hits the 'does not reference a real subscription' branch" do
    # Mutation rationale: kills deletion/corruption of the `{:error, _}` ->
    # `{:error, field: :subscription_id, message: "does not reference a
    # real subscription"}` branch, and kills mutating the guard into
    # passing the Ash.get error through as :ok (silent acceptance of a
    # dangling FK-shaped request).
    org_id = "org-w984fm-ghost-#{System.unique_integer([:positive])}"
    ghost_id = Ash.UUID.generate()

    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             create_downgrade!(%{
               requested_by: "requester-w984fm-ghost",
               org_id: org_id,
               subscription_id: ghost_id,
               requested_tier: :standard
             })

    assert Enum.any?(errors, fn e ->
             to_string(e.message) =~ "does not reference a real subscription"
           end),
           "expected the real missing-subscription branch message, got: #{inspect(errors)}"
  end

  @tag :w984fm
  @tag :w984fm_enterprise_current
  test "real downgrade FROM enterprise TO pro is accepted (enterprise rank on the current side)" do
    # Mutation rationale: kills deletion of the :enterprise => 2 entry from
    # @tier_rank (Map.fetch! would raise, converting a legitimate
    # enterprise downgrade into a crash) and kills inverting the strict
    # `<` comparison on the enterprise side (2 < 1 must hold).
    org_id = "org-w984fm-ent-cur-#{System.unique_integer([:positive])}"
    subscription = create_subscription!(org_id, :enterprise)

    assert {:ok, %ApprovalTierDowngrade{} = pending} =
             create_downgrade!(%{
               requested_by: "requester-w984fm-ent",
               org_id: org_id,
               subscription_id: subscription.id,
               requested_tier: :pro
             })

    assert pending.requested_tier == :pro
    assert pending.approved_by == nil
  end

  @tag :w984fm
  @tag :w984fm_enterprise_requested
  test "requesting :enterprise over a :pro subscription is refused (enterprise rank on the requested side)" do
    # Mutation rationale: kills swapping `Map.fetch!(@tier_rank,
    # requested_tier) < Map.fetch!(@tier_rank, current_tier)` into `<=`
    # (which would also accept equal tiers) specifically on the
    # enterprise branch, and kills dropping :enterprise from the
    # requested-side rank lookup (crash-instead-of-refusal mutation).
    org_id = "org-w984fm-ent-req-#{System.unique_integer([:positive])}"
    subscription = create_subscription!(org_id, :pro)

    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             create_downgrade!(%{
               requested_by: "requester-w984fm-ent-req",
               org_id: org_id,
               subscription_id: subscription.id,
               requested_tier: :enterprise
             })

    assert Enum.any?(errors, fn e ->
             to_string(e.message) =~ "not enterprise"
           end),
           "expected the real lower-tier refusal naming enterprise, got: #{inspect(errors)}"
  end
end
