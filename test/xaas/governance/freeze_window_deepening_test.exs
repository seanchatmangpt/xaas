defmodule Xaas.Governance.FreezeWindowDeepeningTest do
  @moduledoc false

  use XaasWeb.ConnCase, async: false
  require Ash.Query
  import Ecto.Query

  alias Xaas.Accounts.Org
  alias Xaas.Governance.ApprovalDeploymentQuarantine
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

  defp freeze_window!(org_id, starts_at, ends_at, opts \\ []) do
    FreezeWindow
    |> Ash.Changeset.for_create(:create, %{
      org_id: org_id,
      starts_at: starts_at,
      ends_at: ends_at,
      reason: "w983g court freeze",
      created_by: "w983g",
      allow_emergency_override: Keyword.get(opts, :allow_emergency_override, false)
    })
    |> Ash.create!(authorize?: false)
  end

  defp pending_quarantine!(org_slug) do
    unique = System.unique_integer([:positive])

    ApprovalDeploymentQuarantine
    |> Ash.Changeset.for_create(
      :create,
      %{
        org_id: org_slug,
        requested_by: "w983g-requester",
        deployment_name: "deploy-#{unique}",
        environment: :prod,
        reason: :security_finding
      },
      tenant: org_slug
    )
    |> Ash.create!(authorize?: false)
  end

  defp approve(row, org_slug) do
    row
    |> Ash.Changeset.for_update(:approve, %{approved_by: "w983g-approver"},
      actor: %{org_id: org_slug},
      tenant: org_slug
    )
    |> Ash.update(authorize?: true)
  end

  defp date_window!(window_id, field, value) do
    # Valid-dating the row directly (no clock mock): the check reads
    # real wall-clock now and compares against the stored row.
    {1, _} =
      from(f in FreezeWindow, where: f.id == ^window_id)
      |> Xaas.Repo.update_all(set: [{field, value}])
  end

  defp now0, do: DateTime.utc_now() |> DateTime.truncate(:second)

  describe "W983g freeze-window deepening" do
    @tag :w983g
    test "1 boundary precision: gate is inclusive at both edges, second-granular" do
      org = real_org!("w983g-boundary")
      row = pending_quarantine!(org.slug)

      # Future window: not yet active, approve admits.
      window = freeze_window!(org.slug, now0() |> DateTime.add(3600), now0() |> DateTime.add(7200))
      assert {:ok, _} = approve(row, org.slug)

      # Fresh row per state: :approve is single-shot
      # (approval_not_already_approved), so each boundary probe gets its
      # own unapproved record.

      # Roll starts_at back to EXACTLY now: starts_at <= now is
      # inclusive -> refused at the exact freeze-start boundary.
      date_window!(window.id, :starts_at, now0())
      assert {:error, %Ash.Error.Forbidden{}} = approve_fail(pending_quarantine!(org.slug), org.slug)

      # Move starts_at to now-1 (1s before the boundary): still refused
      # (window active). This is the real precision floor: :utc_datetime
      # stores seconds, and the check truncates now to :second, so
      # sub-second (microsecond) edges are NOT representable -- a
      # one-microsecond-before probe would truncate to the same second.
      date_window!(window.id, :starts_at, now0() |> DateTime.add(-1))
      assert {:error, %Ash.Error.Forbidden{}} = approve_fail(pending_quarantine!(org.slug), org.slug)

      # Ends boundary: ends_at == now is still refused (ends_at >= now
      # inclusive); ends_at = now-1 admits.
      date_window!(window.id, :ends_at, now0())
      assert {:error, %Ash.Error.Forbidden{}} = approve_fail(pending_quarantine!(org.slug), org.slug)

      date_window!(window.id, :ends_at, now0() |> DateTime.add(-1))
      assert {:ok, _} = approve(pending_quarantine!(org.slug), org.slug)
    end

    @tag :w983g
    test "2 org spanning: a freeze in org A does not block org B's identical action" do
      org_a = real_org!("w983g-orga")
      org_b = real_org!("w983g-orgb")

      _window = freeze_window!(org_a.slug, now0() |> DateTime.add(-60), now0() |> DateTime.add(3600))

      row_b = pending_quarantine!(org_b.slug)
      # The check filters freeze windows by the SUBJECT record's org_id,
      # so org B -- with no window of its own -- approves normally while
      # org A is frozen.
      assert {:ok, %ApprovalDeploymentQuarantine{approved_by: "w983g-approver"}} =
               approve(row_b, org_b.slug)

      # Control: the same freeze does block org A's own action.
      row_a = pending_quarantine!(org_a.slug)
      assert {:error, %Ash.Error.Forbidden{}} = approve_fail(row_a, org_a.slug)
    end

    @tag :w983g
    test "3 freeze lift: valid-dating ends_at into the past admits the previously-refused action" do
      org = real_org!("w983g-lift")
      window =
        freeze_window!(org.slug, now0() |> DateTime.add(-60), now0() |> DateTime.add(3600))

      row = pending_quarantine!(org.slug)
      assert {:error, %Ash.Error.Forbidden{}} = approve_fail(row, org.slug)

      date_window!(window.id, :ends_at, now0() |> DateTime.add(-10))

      assert {:ok, %ApprovalDeploymentQuarantine{approved_by: "w983g-approver"}} =
               approve(row, org.slug)
    end

    @tag :w983g
    test "4 idempotent creation: the real contract permits duplicate windows (no dedup)" do
      org = real_org!("w983g-dup")
      s = now0() |> DateTime.add(-60)
      e = now0() |> DateTime.add(3600)

      w1 = freeze_window!(org.slug, s, e)
      w2 = freeze_window!(org.slug, s, e)

      # DESIGN-FINDING (typed, report-only): :create has no unique
      # identity on (org_id, starts_at, ends_at) -- the second identical
      # create is ADMITTED, not deduped or refused. The contract is
      # duplicate-permitting.
      refute w1.id == w2.id

      count =
        FreezeWindow
        |> Ash.Query.filter(org_id == ^org.slug and starts_at == ^s and ends_at == ^e)
        |> Ash.read!(authorize?: false)
        |> length()

      assert count == 2

      # Behavioral consequence: either row alone satisfies the gate's
      # existential active-window query, so duplication does not weaken
      # enforcement.
      row = pending_quarantine!(org.slug)
      assert {:error, %Ash.Error.Forbidden{}} = approve_fail(row, org.slug)
    end
  end

  defp approve_fail(row, org_slug) do
    row
    |> Ash.Changeset.for_update(:approve, %{approved_by: "w983g-approver"},
      actor: %{org_id: org_slug},
      tenant: org_slug
    )
    |> Ash.update(authorize?: true)
  end
end
