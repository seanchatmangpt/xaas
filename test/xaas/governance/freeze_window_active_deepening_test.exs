defmodule Xaas.Governance.FreezeWindowActiveDeepeningTest do
  @moduledoc """
  Lane W984dx Chicago court on `Xaas.Governance.Checks.FreezeWindowActive`'s
  `match?/3` unit contract — branches the W969b gate court
  (`test/xaas/governance/freeze_window_active_gate_test.exs`) does not
  reach:

  - subject/context shapes that fall through to the catch-all `false`
    clause (no `:subject` key, subject with nil org_id, changeset whose
    data carries no org_id),
  - the `%Ash.Changeset{action_type: :update}` org_id extraction clause,
  - exact boundary inclusivity: `starts_at == now` and `ends_at == now`
    are both IN the window (`<=` / `>=` filters, second-truncated),
  - unit-level `allow_emergency_override` true/false branching against
    real rows (no mocks, no clock patching — boundaries are real
    datetimes written into real `FreezeWindow` rows).
  """

  use XaasWeb.ConnCase, async: false

  alias Xaas.Accounts.Org
  alias Xaas.Governance.Checks.FreezeWindowActive
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

  defp window!(org_id, opts) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    starts_at = Keyword.get(opts, :starts_at, DateTime.add(now, -60, :second))
    ends_at = Keyword.get(opts, :ends_at, DateTime.add(now, 3600, :second))

    FreezeWindow
    |> Ash.Changeset.for_create(:create, %{
      org_id: org_id,
      starts_at: starts_at,
      ends_at: ends_at,
      reason: "w984dx boundary court",
      created_by: "w984dx",
      allow_emergency_override: Keyword.get(opts, :allow_emergency_override, false)
    })
    |> Ash.create!(authorize?: false)
  end

  defp active!(org_id) do
    window!(org_id, allow_emergency_override: false)
  end

  defp approved_override!(org_id, window) do
    override =
      ApprovalFreezeOverride
      |> Ash.Changeset.for_create(:create, %{
        org_id: org_id,
        requested_by: "w984dx-requester",
        freeze_window_id: window.id,
        reason: "w984dx override"
      })
      |> Ash.create!(authorize?: false)

    override
    |> Ash.Changeset.for_update(:approve, %{approved_by: "w984dx-approver"})
    |> Ash.update!(authorize?: false)
  end

  defp approve_changeset!(row, org_id) do
    Ash.Changeset.for_update(row, :approve, %{approved_by: "w984dx-approver"},
      actor: %{org_id: org_id},
      tenant: org_id
    )
  end

  describe "match?/3 fall-through clauses" do
    @tag :w984dx
    test "context without a :subject key is not a freeze subject (false)" do
      org = real_org!("w984dx-nosub")
      active!(org.slug)

      refute FreezeWindowActive.match?(%{org_id: org.slug}, %{no_subject: true}, [])
    end

    @tag :w984dx
    test "subject with nil org_id is not a freeze subject (false)" do
      active!(real_org!("w984dx-nilorg").slug)

      refute FreezeWindowActive.match?(%{}, %{subject: %{org_id: nil}}, [])
    end

    @tag :w984dx
    test "subject shape unrecognized entirely (no org_id key) is false" do
      active!(real_org!("w984dx-odd").slug)

      refute FreezeWindowActive.match?(%{}, %{subject: %{something_else: 1}}, [])
    end
  end

  describe "Ash.Changeset org_id extraction clause" do
    @tag :w984dx
    test "update changeset whose data.org_id names an active window forbids" do
      org = real_org!("w984dx-cs")
      active!(org.slug)
      row =
        Xaas.Governance.ApprovalDeploymentQuarantine
        |> Ash.Changeset.for_create(
          :create,
          %{
            org_id: org.slug,
            requested_by: "w984dx",
            deployment_name: "deploy-#{System.unique_integer([:positive])}",
            environment: :prod,
            reason: :security_finding
          },
          tenant: org.slug
        )
        |> Ash.create!(authorize?: false)

      changeset = approve_changeset!(row, org.slug)
      assert %Ash.Changeset{action_type: :update} = changeset

      assert FreezeWindowActive.match?(%{org_id: org.slug}, %{subject: changeset}, [])
    end

    @tag :w984dx
    test "update changeset whose data lacks org_id is not a freeze subject" do
      org = real_org!("w984dx-cs2")
      active!(org.slug)

      bare = %Ash.Changeset{action_type: :update, data: %Xaas.Governance.FreezeWindow{}}

      refute FreezeWindowActive.match?(%{}, %{subject: bare}, [])
    end
  end

  describe "boundary semantics (real datetimes, inclusive edges)" do
    @tag :w984dx
    test "starts_at == now (second-truncated) is IN the window" do
      org = real_org!("w984dx-startedge")
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      window!(org.slug, starts_at: now, ends_at: DateTime.add(now, 600, :second))

      assert FreezeWindowActive.match?(%{org_id: org.slug}, %{subject: %{org_id: org.slug}}, [])
    end

    @tag :w984dx
    test "ends_at == now (second-truncated) is IN the window" do
      org = real_org!("w984dx-endoedge")
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      window!(org.slug, starts_at: DateTime.add(now, -600, :second), ends_at: now)

      assert FreezeWindowActive.match?(%{org_id: org.slug}, %{subject: %{org_id: org.slug}}, [])
    end

    @tag :w984dx
    test "starts_at strictly in the future is NOT active" do
      org = real_org!("w984dx-future")
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      window!(org.slug,
        starts_at: DateTime.add(now, 3600, :second),
        ends_at: DateTime.add(now, 7200, :second)
      )

      refute FreezeWindowActive.match?(%{org_id: org.slug}, %{subject: %{org_id: org.slug}}, [])
    end

    @tag :w984dx
    test "ends_at strictly in the past is NOT active" do
      org = real_org!("w984dx-past")
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      window!(org.slug,
        starts_at: DateTime.add(now, -7200, :second),
        ends_at: DateTime.add(now, -3600, :second)
      )

      refute FreezeWindowActive.match?(%{org_id: org.slug}, %{subject: %{org_id: org.slug}}, [])
    end

    @tag :w984dx
    test "an active window for a DIFFERENT org does not forbid this org" do
      org = real_org!("w984dx-other-a")
      other = real_org!("w984dx-other-b")
      active!(other.slug)

      refute FreezeWindowActive.match?(%{org_id: org.slug}, %{subject: %{org_id: org.slug}}, [])
    end
  end

  describe "emergency override branching at unit level" do
    @tag :w984dx
    test "overrideable window with no override row still forbids (true)" do
      org = real_org!("w984dx-emerg1")
      window!(org.slug, allow_emergency_override: true)

      assert FreezeWindowActive.match?(%{org_id: org.slug}, %{subject: %{org_id: org.slug}}, [])
    end

    @tag :w984dx
    test "overrideable window with an APPROVED override does not forbid (false)" do
      org = real_org!("w984dx-emerg2")
      window = window!(org.slug, allow_emergency_override: true)
      approved_override!(org.slug, window)

      refute FreezeWindowActive.match?(%{org_id: org.slug}, %{subject: %{org_id: org.slug}}, [])
    end

    @tag :w984dx
    test "overrideable window with a FILED-but-unapproved override still forbids" do
      org = real_org!("w984dx-emerg3")
      window = window!(org.slug, allow_emergency_override: true)

      ApprovalFreezeOverride
      |> Ash.Changeset.for_create(:create, %{
        org_id: org.slug,
        requested_by: "w984dx-requester",
        freeze_window_id: window.id,
        reason: "filed, never approved"
      })
      |> Ash.create!(authorize?: false)

      assert FreezeWindowActive.match?(%{org_id: org.slug}, %{subject: %{org_id: org.slug}}, [])
    end

    @tag :w984dx
    test "non-overrideable window: override filing itself is refused, gate still forbids" do
      org = real_org!("w984dx-emerg4")
      window = active!(org.slug)

      # Real contract: overrides cannot even be FILED against a
      # non-overrideable window (ApprovalFreezeOverride create validation).
      assert {:error, %Ash.Error.Invalid{}} =
               ApprovalFreezeOverride
               |> Ash.Changeset.for_create(:create, %{
                 org_id: org.slug,
                 requested_by: "w984dx-requester",
                 freeze_window_id: window.id,
                 reason: "cannot be filed"
               })
               |> Ash.create(authorize?: false)

      assert FreezeWindowActive.match?(%{org_id: org.slug}, %{subject: %{org_id: org.slug}}, [])
    end
  end
end
