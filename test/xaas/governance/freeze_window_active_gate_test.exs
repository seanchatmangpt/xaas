defmodule Xaas.Governance.FreezeWindowActiveGateTest do
  @moduledoc false

  use XaasWeb.ConnCase, async: false
  require Ash.Query
  import Ecto.Query

  alias Xaas.Accounts.Org
  alias Xaas.Governance.ApprovalDeploymentQuarantine
  alias Xaas.Governance.ApprovalEnvironmentPromote
  alias Xaas.Governance.ApprovalFreezeOverride
  alias Xaas.Governance.FreezeWindow

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

  defp freeze_window!(org, allow_emergency_override) do
    org_id = org.slug

    FreezeWindow
    |> Ash.Changeset.for_create(:create, %{
      org_id: org_id,
      starts_at: DateTime.utc_now() |> DateTime.add(-60) |> DateTime.truncate(:second),
      ends_at: DateTime.utc_now() |> DateTime.add(3600) |> DateTime.truncate(:second),
      reason: "w969b court freeze",
      created_by: "w969b",
      allow_emergency_override: allow_emergency_override
    })
    |> Ash.create!(authorize?: false)
  end

  defp approved_override!(org, window) do
    org_id = org.slug
    window_id = window.id

    override =
      ApprovalFreezeOverride
      |> Ash.Changeset.for_create(:create, %{
        org_id: org_id,
        requested_by: "w969b-requester",
        freeze_window_id: window_id,
        reason: "w969b court override"
      })
      |> Ash.create!(authorize?: false)

    override
    |> Ash.Changeset.for_update(:approve, %{approved_by: "w969b-approver"})
    |> Ash.update!(authorize?: false)
  end

  defp pending_quarantine!(org_slug) do
    unique = System.unique_integer([:positive])

    ApprovalDeploymentQuarantine
    |> Ash.Changeset.for_create(
      :create,
      %{
        org_id: org_slug,
        requested_by: "w969b-requester",
        deployment_name: "deploy-#{unique}",
        environment: :prod,
        reason: :security_finding
      },
      tenant: org_slug
    )
    |> Ash.create!(authorize?: false)
  end

  defp pending_promote!(org_slug) do
    unique = System.unique_integer([:positive])

    ApprovalEnvironmentPromote
    |> Ash.Changeset.for_create(
      :create,
      %{
        org_id: org_slug,
        requested_by: "w969b-requester",
        project_name: "proj-#{unique}",
        from_environment: :staging,
        to_environment: :prod
      },
      tenant: org_slug
    )
    |> Ash.create!(authorize?: false)
  end

  defp window_active?(org_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    FreezeWindow
    |> Ash.Query.filter(org_id == ^org_id and starts_at <= ^now and ends_at >= ^now)
    |> Ash.exists?(authorize?: false)
  end

  describe "SPEC-18 freeze gate on :approve" do
    @tag :w969b
    test "1: in-window :approve refused typed, naming the freeze" do
      org = real_org!("w969b-freeze")
      window = freeze_window!(org, false)
      row = pending_quarantine!(org.slug)
      assert window_active?(org.slug)

      assert {:error, %Ash.Error.Forbidden{} = error} =
               row
               |> Ash.Changeset.for_update(:approve, %{approved_by: "w969b-approver"},
                 actor: %{org_id: org.slug},
                 tenant: org.slug
               )
               |> Ash.update(authorize?: true)

      text = Exception.message(error)
      assert text =~ "freeze", "refusal must name the freeze (window #{window.id}): #{text}"
    end

    @tag :w969b
    test "2: same refusal + time-bounded lift on ApprovalEnvironmentPromote :approve" do
      org = real_org!("w969b-freeze2")
      window = freeze_window!(org, false)
      row = pending_promote!(org.slug)
      assert window_active?(org.slug)

      assert {:error, %Ash.Error.Forbidden{} = error} =
               row
               |> Ash.Changeset.for_update(:approve, %{approved_by: "w969b-approver"},
                 actor: %Xaas.SystemAuthority{service: :internal_api}
               )
               |> Ash.update(authorize?: true)

      assert Exception.message(error) =~ "freeze"

      # The gate is time-bounded: once the window ends, the same actor
      # approves normally.
      {1, _} =
        from(f in FreezeWindow, where: f.id == ^window.id)
        |> Xaas.Repo.update_all(set: [ends_at: DateTime.utc_now() |> DateTime.add(-10) |> DateTime.truncate(:second)])

      assert {:ok, %ApprovalEnvironmentPromote{approved_by: "w969b-approver"}} =
               row
               |> Ash.Changeset.for_update(:approve, %{approved_by: "w969b-approver"},
                 actor: %Xaas.SystemAuthority{service: :internal_api}
               )
               |> Ash.update(authorize?: true)
    end

    @tag :w969b
    test "3: an UNapproved override does not lift the freeze" do
      org = real_org!("w969b-freeze3")
      window = freeze_window!(org, true)
      window_id = window.id

      _filed =
        ApprovalFreezeOverride
        |> Ash.Changeset.for_create(:create, %{
          org_id: org.slug,
          requested_by: "w969b-requester",
          freeze_window_id: window_id,
          reason: "filed, never approved"
        })
        |> Ash.create!(authorize?: false)

      row = pending_quarantine!(org.slug)

      assert {:error, %Ash.Error.Forbidden{}} =
               row
               |> Ash.Changeset.for_update(:approve, %{approved_by: "w969b-approver"},
                 actor: %{org_id: org.slug},
                 tenant: org.slug
               )
               |> Ash.update(authorize?: true)
    end

    @tag :w969b
    test "4: approved override lifts the freeze on an overrideable window (control)" do
      org = real_org!("w969b-freeze4")
      window = freeze_window!(org, true)
      approved_override!(org, window)
      row = pending_quarantine!(org.slug)

      assert {:ok, %ApprovalDeploymentQuarantine{approved_by: "w969b-approver"}} =
               row
               |> Ash.Changeset.for_update(:approve, %{approved_by: "w969b-approver"},
                 actor: %{org_id: org.slug},
                 tenant: org.slug
               )
               |> Ash.update(authorize?: true)
    end

    @tag :w969b
    test "5: control — outside any freeze window both surfaces approve normally" do
      org = real_org!("w969b-control")
      row_q = pending_quarantine!(org.slug)
      row_p = pending_promote!(org.slug)

      assert {:ok, %ApprovalDeploymentQuarantine{}} =
               row_q
               |> Ash.Changeset.for_update(:approve, %{approved_by: "w969b-approver"},
                 actor: %{org_id: org.slug},
                 tenant: org.slug
               )
               |> Ash.update(authorize?: true)

      assert {:ok, %ApprovalEnvironmentPromote{}} =
               row_p
               |> Ash.Changeset.for_update(:approve, %{approved_by: "w969b-approver"},
                 actor: %Xaas.SystemAuthority{service: :internal_api}
               )
               |> Ash.update(authorize?: true)
    end
  end
end
