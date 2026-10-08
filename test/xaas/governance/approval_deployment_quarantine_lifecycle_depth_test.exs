defmodule Xaas.Governance.ApprovalDeploymentQuarantineLifecycleDepthTest do
  @moduledoc """
  Lane W984ci governance depth court: the deployment-quarantine surface
  MINUS the already-courted slices (freeze gate on `:approve` — W969b/c +
  W983g; tenant isolation, maker-checker, state machine on `:approve` —
  multitenant_approval_deepening; HTTP happy path + self-approve refusal —
  approval_deployment_quarantine_controller_test; paper trail on :approve —
  controller test).

  The uncourted remainder is the `:create`-side payload contract and the
  cross-tenant `:create` normalization behavior on
  `Xaas.Governance.ApprovalDeploymentQuarantine`:

  1. `reason` is a real closed enum
     (`Xaas.Governance.Types.DeploymentQuarantineReason`: failed_healthcheck
     | security_finding | manual_hold | rollback_candidate) — a payload
     with an out-of-enum value is a real typed `Ash.Error.Invalid` refusal
     and no row lands.
  2. `environment` is a real closed enum
     (`Xaas.Governance.Types.Environment`) — same negative contract.
  3. Cross-tenant `:create`: per `ActorOrgMatches`' moduledoc, Ash
     attribute-multitenancy normalizes the payload's `org_id` to the
     resolved tenant BEFORE policy, so the real invariant is "the row
     always lands under the resolved tenant's org, never under the
     payload-asserted foreign org" — asserted against the real persisted
     row.
  4. `:approve` cannot mutate the quarantine payload: `deployment_name`,
     `environment`, and `reason` are not in `:approve`'s accept list, so a
     PATCH-style approve carrying extra attributes leaves them untouched
     (real persisted state).

  Chicago discipline: real Ash actions against real sandboxed Postgres
  (`Xaas.Repo`), no mocks, asserts on persisted state.
  """

  use XaasWeb.ConnCase, async: false
  require Ash.Query

  alias Xaas.Accounts.Org
  alias Xaas.Governance.ApprovalDeploymentQuarantine

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp real_org!(prefix) do
    unique = System.unique_integer([:positive])

    Org
    |> Ash.Changeset.for_create(:create, %{
      name: "#{prefix} #{unique}",
      slug: "#{prefix}-#{unique}"
    })
    |> Ash.create!(authorize?: false)
  end

  defp base_attrs(org_slug) do
    %{
      org_id: org_slug,
      requested_by: "w984ci-requester",
      deployment_name: "deploy-#{System.unique_integer([:positive])}",
      environment: :prod,
      reason: :security_finding
    }
  end

  defp create_quarantine(attrs, org_slug, opts \\ []) do
    ApprovalDeploymentQuarantine
    |> Ash.Changeset.for_create(
      :create,
      attrs,
      tenant: org_slug,
      actor: %{org_id: org_slug}
    )
    |> Ash.create(%{}, authorize?: Keyword.get(opts, :authorize?, true))
  end

  defp pending_quarantine!(org_slug, attrs_override \\ %{}) do
    ApprovalDeploymentQuarantine
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(base_attrs(org_slug), attrs_override),
      tenant: org_slug,
      actor: %{org_id: org_slug}
    )
    |> Ash.create!(authorize?: false)
  end

  # ---------- (1) reason enum is a real closed set ----------

  test "create with an out-of-enum reason is a typed Invalid refusal and no row lands" do
    org = real_org!("w984ci-reason")
    attrs = base_attrs(org.slug) |> Map.put(:reason, "unauthorized_topology_change")

    assert {:error, %Ash.Error.Invalid{} = error} =
             create_quarantine(attrs, org.slug, authorize?: true)

    message = Exception.message(error)
    assert message =~ "reason"

    # Real state: no quarantine row exists for this org's deployment payload.
    rows =
      ApprovalDeploymentQuarantine
      |> Ash.Query.filter(deployment_name: attrs.deployment_name)
      |> Ash.Query.for_read(:read, %{}, tenant: org.slug, authorize?: false)
      |> Ash.read!()

    assert rows == []
  end

  # ---------- (2) environment enum is a real closed set ----------

  test "create with an out-of-enum environment is a typed Invalid refusal and no row lands" do
    org = real_org!("w984ci-env")
    attrs = base_attrs(org.slug) |> Map.put(:environment, "disaster-recovery")

    assert {:error, %Ash.Error.Invalid{} = error} =
             create_quarantine(attrs, org.slug, authorize?: true)

    message = Exception.message(error)
    assert message =~ "environment"

    rows =
      ApprovalDeploymentQuarantine
      |> Ash.Query.filter(deployment_name: attrs.deployment_name)
      |> Ash.Query.for_read(:read, %{}, tenant: org.slug, authorize?: false)
      |> Ash.read!()

    assert rows == []
  end

  # ---------- (3) cross-tenant create normalizes, never misfiles ----------

  test "cross-tenant create under tenant org A with org B's org_id in the payload lands the row in org A, never org B" do
    org_a = real_org!("w984ci-xa")
    org_b = real_org!("w984ci-xb")

    # Real actor asserting org A, tenant org A, but the payload body claims
    # org B's slug. Per ActorOrgMatches' moduledoc (its :create half is
    # documented vacuous — multitenancy normalizes before policy), the real
    # invariant is normalization: the row lands under the tenant.
    attrs = base_attrs(org_b.slug)

    assert {:ok, row} =
             ApprovalDeploymentQuarantine
             |> Ash.Changeset.for_create(:create, attrs,
               tenant: org_a.slug,
               actor: %{org_id: org_a.slug}
             )
             |> Ash.create(%{}, authorize?: true)

    assert %ApprovalDeploymentQuarantine{} = row
    assert row.org_id == org_a.slug

    # Real state: org B never gained a row for this deployment.
    org_b_rows =
      ApprovalDeploymentQuarantine
      |> Ash.Query.filter(deployment_name: attrs.deployment_name)
      |> Ash.Query.for_read(:read, %{}, tenant: org_b.slug, authorize?: false)
      |> Ash.read!()

    assert org_b_rows == []
  end

  # ---------- (4) same-org authorized full lifecycle (control) ----------

  test "same-org authorized create then approve admits and persists the full lifecycle (control)" do
    org = real_org!("w984ci-ctrl")
    attrs = base_attrs(org.slug)

    assert {:ok, created} = create_quarantine(attrs, org.slug, authorize?: true)

    assert {:ok, approved} =
             created
             |> Ash.Changeset.for_update(:approve, %{approved_by: "w984ci-approver"},
               tenant: org.slug,
               actor: %{org_id: org.slug}
             )
             |> Ash.update(authorize?: true)

    assert approved.approved_by == "w984ci-approver"
    assert approved.requested_by == "w984ci-requester"

    persisted = Ash.get!(ApprovalDeploymentQuarantine, created.id, tenant: org.slug, authorize?: false)
    assert persisted.approved_by == "w984ci-approver"
  end

  # ---------- (5) :approve cannot mutate the quarantine payload ----------

  test "approve with tampered payload attributes is a typed NoSuchInput refusal and the row stays pending (real contract, not silent ignore)" do
    org = real_org!("w984ci-immutable")
    row = pending_quarantine!(org.slug)

    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             row
             |> Ash.Changeset.for_update(
               :approve,
               %{
                 approved_by: "w984ci-approver",
                 deployment_name: "tampered-name",
                 environment: "dev",
                 reason: "failed_healthcheck"
               },
               tenant: org.slug,
               actor: %{org_id: org.slug}
             )
             |> Ash.update(authorize?: true)

    # The real typed refusal: Ash rejects each non-accepted input explicitly.
    tampered = errors |> Enum.filter(&match?(%Ash.Error.Invalid.NoSuchInput{}, &1))
    tampered_inputs = Enum.map(tampered, & &1.input) |> Enum.sort()
    assert tampered_inputs == [:deployment_name, :environment, :reason]

    # Real state: the row is untouched — still pending, payload intact.
    persisted = Ash.get!(ApprovalDeploymentQuarantine, row.id, tenant: org.slug, authorize?: false)

    assert persisted.approved_by == nil
    assert persisted.deployment_name == row.deployment_name
    assert persisted.environment == row.environment
    assert persisted.reason == row.reason
  end
end
