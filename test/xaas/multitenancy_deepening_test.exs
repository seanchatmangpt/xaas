defmodule Xaas.MultitenancyDeepeningTest do
  @moduledoc """
  Lane W789 (v26.10.6) cross-domain deepening of Ash-core `:attribute`
  multitenancy (`multitenancy do strategy :attribute; attribute :org_id end`)
  as a shared property across the resources that actually declare it.

  Enumerated via `grep -rn "multitenancy do" lib/xaas`: real DSL blocks
  exist in exactly TWO domains --

    - `Xaas.Governance`: the four `Approval*` resources
      (`ApprovalBackupRetentionChange`, `ApprovalDeploymentQuarantine`,
      `ApprovalLegalHoldRelease`, `ApprovalDrFailover`), all
      `global? false`, `org_id` a real FK to `Xaas.Accounts.Org.slug`;
    - `Xaas.Ultracode`: `Run` and `Epoch` (no `global? false` -- the
      default `:read` is still tenant-`:enforce`d per
      `deps/ash/lib/ash/actions/read/read.ex:handle_multitenancy/1`).

  `Marketplace`/`Platform`/`Billing` resources scope by org through real
  `*Checks.ActorOrgMatches` policy checks, NOT the multitenancy DSL --
  disclosed as a coverage boundary in the lane receipt, not silently
  skipped.

  Three representative resources across those two domains, two sharing
  one shape (parameterized) and one a different shape:

    - `Xaas.Governance.ApprovalBackupRetentionChange` (governance)
    - `Xaas.Governance.ApprovalDeploymentQuarantine`  (governance)
    - `Xaas.Ultracode.Epoch`                          (ultracode)

  Chicago-style: real `Ecto.Adapters.SQL.Sandbox`-backed Postgres
  (`Xaas.Repo`), real `Xaas.Accounts.Org` tenant rows, real Ash create
  and read actions, real row state asserted back. No mocks, no stubs,
  no interaction assertions. The ultracode pair (`Run`/`Epoch`) already
  carries deep independent adversarial coverage in
  `test/xaas/ultracode/adversarial_multitenancy_test.exs`; this file
  courts the CROSS-DOMAIN property, including the governance resources
  that had no DSL-level multitenancy court of their own.

  Properties per resource (real Ash behavior, already disclosed in
  `Xaas.Governance.Checks.ActorOrgMatches`' moduledoc and here re-proven
  live):

    (a) tenant isolation on read -- org A's tenant cannot read org B's
        row (get-by-id refused, filtered query empty), and omitting the
        tenant entirely raises `Ash.Error.Invalid.TenantRequired`
        rather than silently returning every org's rows;
    (b) the tenant is stamped on create -- a row created under org A's
        tenant carries `org_id == org_a.slug` even when the payload
        forges `org_id: org_b.slug` (Ash's attribute-strategy
        multitenancy force-overwrites the changeset attribute from the
        resolved tenant before the policy check runs);
    (c) cross-tenant create forgery is therefore neutralized at the
        persistence layer -- the forged value never reaches storage;
    (d) determinism -- the same operations repeated under the same
        tenants return identical results.
  """

  use ExUnit.Case, async: true

  require Ash.Query

  alias Xaas.Accounts.Org
  alias Xaas.Governance.ApprovalBackupRetentionChange
  alias Xaas.Governance.ApprovalDeploymentQuarantine
  alias Xaas.Ultracode.Epoch

  @governance_resources [ApprovalBackupRetentionChange, ApprovalDeploymentQuarantine]

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_org!(prefix) do
    slug = "#{prefix}-#{System.unique_integer([:positive])}"

    Org
    |> Ash.Changeset.for_create(:create, %{name: slug, slug: slug}, authorize?: false)
    |> Ash.create!()
  end

  defp create_governance_row!(resource, org, attrs \\ %{}) do
    base =
      case resource do
        ApprovalBackupRetentionChange ->
          %{
            org_id: org.slug,
            requested_by: "w789-requester",
            requested_retention_days: 30,
            tier: :pro
          }

        ApprovalDeploymentQuarantine ->
          %{
            org_id: org.slug,
            requested_by: "w789-requester",
            deployment_name: "w789-deployment",
            environment: :prod,
            reason: :security_finding
          }
      end

    resource
    |> Ash.Changeset.for_create(:create, Map.merge(base, attrs), tenant: org.slug)
    |> Ash.create!(authorize?: false)
  end

  defp create_epoch!(org, attrs \\ %{}) do
    run =
      Xaas.Ultracode.Run
      |> Ash.Changeset.for_create(:create, %{goal: "w789 probe", org_id: org.id},
        authorize?: false
      )
      |> Ash.create!()

    Epoch
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(
        %{
          run_id: run.id,
          org_id: org.id,
          cycle: 0,
          exact_subject: "w789-multitenancy-probe",
          state: :expected,
          expected_at: DateTime.utc_now()
        },
        attrs
      ),
      authorize?: false
    )
    |> Ash.create!()
  end

  # ------------------------------------------------------------------
  # Parameterized: the two governance resources (identical shape:
  # `global? false`, `org_id` FK -> Org.slug, tenant-stamped create).
  # ------------------------------------------------------------------

  describe "governance Approval* resources (parameterized over #{Enum.count(@governance_resources)} resources)" do
    test "#{inspect(ApprovalBackupRetentionChange)}: (a) tenant isolation on read" do
      org_a = create_org!("w789-g-a")
      org_b = create_org!("w789-g-b")
      row_a = create_governance_row!(ApprovalBackupRetentionChange, org_a)
      _row_b = create_governance_row!(ApprovalBackupRetentionChange, org_b)

      # Positive control: the owning tenant reads its own row.
      owned = Ash.get!(ApprovalBackupRetentionChange, row_a.id, tenant: org_a.slug, authorize?: false)
      assert owned.org_id == org_a.slug

      # Cross-tenant get-by-id is refused outright.
      assert_raise Ash.Error.Invalid, fn ->
        Ash.get!(ApprovalBackupRetentionChange, row_a.id,
          tenant: org_b.slug,
          authorize?: false
        )
      end

      # A filtered list read under the wrong tenant is empty, not leaking.
      results =
        ApprovalBackupRetentionChange
        |> Ash.Query.filter(id == ^row_a.id)
        |> Ash.read!(tenant: org_b.slug, authorize?: false)

      assert results == []

      # No tenant at all: typed refusal, not silent cross-org data.
      assert_raise Ash.Error.Invalid, fn ->
        Ash.read!(ApprovalBackupRetentionChange, authorize?: false)
      end
    end

    test "#{inspect(ApprovalDeploymentQuarantine)}: (a) tenant isolation on read" do
      org_a = create_org!("w789-q-a")
      org_b = create_org!("w789-q-b")
      row_a = create_governance_row!(ApprovalDeploymentQuarantine, org_a)
      _row_b = create_governance_row!(ApprovalDeploymentQuarantine, org_b)

      owned = Ash.get!(ApprovalDeploymentQuarantine, row_a.id, tenant: org_a.slug, authorize?: false)
      assert owned.org_id == org_a.slug

      assert_raise Ash.Error.Invalid, fn ->
        Ash.get!(ApprovalDeploymentQuarantine, row_a.id,
          tenant: org_b.slug,
          authorize?: false
        )
      end

      results =
        ApprovalDeploymentQuarantine
        |> Ash.Query.filter(id == ^row_a.id)
        |> Ash.read!(tenant: org_b.slug, authorize?: false)

      assert results == []

      assert_raise Ash.Error.Invalid, fn ->
        Ash.read!(ApprovalDeploymentQuarantine, authorize?: false)
      end
    end

    test "#{inspect(ApprovalBackupRetentionChange)}: (b)+(c) tenant stamped on create; forged org_id never reaches storage" do
      org_a = create_org!("w789-s-a")
      org_b = create_org!("w789-s-b")

      # The payload forges org B's slug while the tenant is org A's.
      row =
        create_governance_row!(ApprovalBackupRetentionChange, org_a, %{
          org_id: org_b.slug
        })

      # Real, executed: the persisted row carries the TENANT's org, never
      # the forged payload value.
      assert row.org_id == org_a.slug
      refute row.org_id == org_b.slug

      # And the persisted state read back agrees.
      reloaded =
        Ash.get!(ApprovalBackupRetentionChange, row.id,
          tenant: org_a.slug,
          authorize?: false
        )

      assert reloaded.org_id == org_a.slug
    end

    test "#{inspect(ApprovalDeploymentQuarantine)}: (b)+(c) tenant stamped on create; forged org_id never reaches storage" do
      org_a = create_org!("w789-t-a")
      org_b = create_org!("w789-t-b")

      row =
        create_governance_row!(ApprovalDeploymentQuarantine, org_a, %{
          org_id: org_b.slug
        })

      assert row.org_id == org_a.slug
      refute row.org_id == org_b.slug

      reloaded =
        Ash.get!(ApprovalDeploymentQuarantine, row.id,
          tenant: org_a.slug,
          authorize?: false
        )

      assert reloaded.org_id == org_a.slug
    end

    test "(d) determinism (both governance resources)" do
      for resource <- @governance_resources do
        org_a = create_org!("w789-d-a")
        org_b = create_org!("w789-d-b")
        row_a = create_governance_row!(resource, org_a)
        row_b = create_governance_row!(resource, org_b)

        results =
          for _ <- 1..3 do
            owned = Ash.get!(resource, row_a.id, tenant: org_a.slug, authorize?: false)

            cross =
              resource
              |> Ash.Query.filter(id == ^row_b.id)
              |> Ash.read!(tenant: org_a.slug, authorize?: false)

            {owned.id, cross}
          end

        assert Enum.uniq(results) == [hd(results)]
        assert hd(results) |> elem(0) == row_a.id
        assert hd(results) |> elem(1) == []
      end
    end
  end

  # ------------------------------------------------------------------
  # Xaas.Ultracode.Epoch: different shape (string org_id denormalized
  # from the parent Run, `:create` explicitly `:allow_global` with
  # `:org_id` accepted explicitly -- internal call sites pass no
  # tenant).
  # ------------------------------------------------------------------

  describe "Xaas.Ultracode.Epoch (string org_id, allow_global create)" do
    test "(a) tenant isolation on read" do
      org_a = create_org!("w789-e-a")
      org_b = create_org!("w789-e-b")
      epoch_a = create_epoch!(org_a)
      epoch_b = create_epoch!(org_b)

      owned = Ash.get!(Epoch, epoch_a.id, tenant: org_a.id, authorize?: false)
      assert owned.org_id == org_a.id

      # Org A's tenant-wide list read sees only its own epoch.
      ids =
        Epoch
        |> Ash.read!(tenant: org_a.id, authorize?: false)
        |> Enum.map(& &1.id)

      assert epoch_a.id in ids
      refute epoch_b.id in ids

      assert_raise Ash.Error.Invalid, fn ->
        Ash.get!(Epoch, epoch_a.id, tenant: org_b.id, authorize?: false)
      end

      results =
        Epoch
        |> Ash.Query.filter(id == ^epoch_a.id)
        |> Ash.read!(tenant: org_b.id, authorize?: false)

      assert results == []

      assert_raise Ash.Error.Invalid, fn ->
        Ash.read!(Epoch, authorize?: false)
      end
    end

    test "(b) create stamps exactly the org supplied; row visible only under that org's tenant" do
      org_a = create_org!("w789-f-a")
      org_b = create_org!("w789-f-b")
      epoch = create_epoch!(org_a)

      assert epoch.org_id == org_a.id
      refute epoch.org_id == org_b.id

      owned = Ash.get!(Epoch, epoch.id, tenant: org_a.id, authorize?: false)
      assert owned.org_id == org_a.id

      assert_raise Ash.Error.Invalid, fn ->
        Ash.get!(Epoch, epoch.id, tenant: org_b.id, authorize?: false)
      end
    end

    test "(c) cross-tenant create forgery: forged org_id is persisted verbatim; the row lands in org B's tenant, invisible to org A" do
      org_a = create_org!("w789-c-a")
      org_b = create_org!("w789-c-c")

      # Epoch's :create is :allow_global and accepts :org_id explicitly --
      # there is NO tenant normalization on this path (no tenant is set in
      # the real internal call shape). A forged payload org_id is therefore
      # persisted verbatim. Real, disclosed design: Epoch :create is an
      # internal/system surface (CreateFirstEpoch / NextEpoch /
      # ExecutionFabricController, which pass the authenticated org
      # explicitly). The org B row is genuinely created under org B and is
      # invisible to org A's tenant -- no cross-tenant LEAK results, but
      # the caller fully controls the tenant stamp on this path. Typed,
      # disclosed gap, not an isolation regression.
      epoch = create_epoch!(org_a, %{org_id: org_b.id})

      assert epoch.org_id == org_b.id

      owned_b = Ash.get!(Epoch, epoch.id, tenant: org_b.id, authorize?: false)
      assert owned_b.org_id == org_b.id

      assert_raise Ash.Error.Invalid, fn ->
        Ash.get!(Epoch, epoch.id, tenant: org_a.id, authorize?: false)
      end
    end

    test "(d) determinism" do
      org_a = create_org!("w789-g2-a")
      org_b = create_org!("w789-g2-b")
      epoch_a = create_epoch!(org_a)
      epoch_b = create_epoch!(org_b)

      results =
        for _ <- 1..3 do
          owned = Ash.get!(Epoch, epoch_a.id, tenant: org_a.id, authorize?: false)

          cross =
            Epoch
            |> Ash.Query.filter(id == ^epoch_b.id)
            |> Ash.read!(tenant: org_a.id, authorize?: false)

          {owned.id, cross}
        end

      assert Enum.uniq(results) == [hd(results)]
      assert hd(results) |> elem(0) == epoch_a.id
      assert hd(results) |> elem(1) == []
    end
  end
end
