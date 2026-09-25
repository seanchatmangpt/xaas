defmodule Xaas.Governance.ApprovalFreezeOverrideTest do
  @moduledoc """
  Real Chicago-style tests for the real, twenty-second-pass ERRC grid fix
  (`docs/claude/diataxis/explanation/errc-innovation-grid.md`):
  `Xaas.Governance.ApprovalFreezeOverride`'s `:create` action previously
  accepted a caller-supplied `freeze_window_id` with zero validation
  against any real `Xaas.Governance.FreezeWindow` row. This file proves
  the real fix -- `Xaas.Governance.Validations.
  ApprovalFreezeOverrideFreezeWindowExists` -- against a real, sandboxed
  Postgres (`Xaas.Repo`), real `Ash.Changeset.for_create` + `Ash.create`
  calls. No mocking.

  Covers all 3 real gaps the fix closes: existence, cross-org integrity,
  and the referenced window's own `allow_emergency_override` flag -- plus
  the legitimate accept path (matching the pre-existing
  `freeze_window_controller_test.exs` link test, which stays green because
  it already uses a real, same-org, `allow_emergency_override: true`
  window).
  """
  use ExUnit.Case, async: true

  alias Xaas.Governance.{ApprovalFreezeOverride, FreezeWindow}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_window!(org_id, allow_emergency_override) do
    now = DateTime.utc_now()

    FreezeWindow
    |> Ash.Changeset.for_create(:create, %{
      org_id: org_id,
      starts_at: now,
      ends_at: DateTime.add(now, 3600, :second),
      reason: "real freeze window under test",
      allow_emergency_override: allow_emergency_override,
      created_by: "test-actor"
    })
    |> Ash.create!(authorize?: false)
  end

  defp override_attrs(org_id, freeze_window_id) do
    %{
      org_id: org_id,
      requested_by: "requester-#{System.unique_integer([:positive])}",
      freeze_window_id: freeze_window_id,
      reason: "emergency hotfix during freeze"
    }
  end

  defp field_errors(%Ash.Error.Invalid{errors: errors}, field) do
    Enum.filter(errors, fn
      %{field: ^field} -> true
      _ -> false
    end)
  end

  test "a real override referencing a real, same-org, emergency-eligible window succeeds" do
    org_id = "org-legit-#{System.unique_integer([:positive])}"
    window = create_window!(org_id, true)

    override =
      ApprovalFreezeOverride
      |> Ash.Changeset.for_create(:create, override_attrs(org_id, window.id))
      |> Ash.create!(authorize?: false)

    assert override.freeze_window_id == window.id
    assert override.org_id == org_id
  end

  test "gap 1 -- a freeze_window_id that references zero real rows is rejected" do
    org_id = "org-ghost-#{System.unique_integer([:positive])}"
    fake_id = Ecto.UUID.generate()

    assert {:error, error} =
             ApprovalFreezeOverride
             |> Ash.Changeset.for_create(:create, override_attrs(org_id, fake_id))
             |> Ash.create(authorize?: false)

    assert [_ | _] = field_errors(error, :freeze_window_id)

    # No real row was persisted despite the rejection.
    persisted =
      ApprovalFreezeOverride
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&(&1.org_id == org_id))

    assert persisted == []
  end

  test "gap 1b -- a non-UUID freeze_window_id string is rejected, not crashed on" do
    org_id = "org-badformat-#{System.unique_integer([:positive])}"

    assert {:error, error} =
             ApprovalFreezeOverride
             |> Ash.Changeset.for_create(:create, override_attrs(org_id, "not-a-real-uuid"))
             |> Ash.create(authorize?: false)

    assert [_ | _] = field_errors(error, :freeze_window_id)
  end

  test "gap 2 -- a real window belonging to a DIFFERENT org is rejected" do
    victim_org = "org-victim-#{System.unique_integer([:positive])}"
    attacker_org = "org-attacker-#{System.unique_integer([:positive])}"
    window = create_window!(victim_org, true)

    assert {:error, error} =
             ApprovalFreezeOverride
             |> Ash.Changeset.for_create(:create, override_attrs(attacker_org, window.id))
             |> Ash.create(authorize?: false)

    assert [_ | _] = field_errors(error, :freeze_window_id)

    persisted =
      ApprovalFreezeOverride
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&(&1.org_id == attacker_org))

    assert persisted == []
  end

  test "gap 3 -- a real, same-org window with allow_emergency_override: false is rejected" do
    org_id = "org-noemergency-#{System.unique_integer([:positive])}"
    window = create_window!(org_id, false)

    assert {:error, error} =
             ApprovalFreezeOverride
             |> Ash.Changeset.for_create(:create, override_attrs(org_id, window.id))
             |> Ash.create(authorize?: false)

    assert [_ | _] = field_errors(error, :freeze_window_id)

    persisted =
      ApprovalFreezeOverride
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&(&1.org_id == org_id))

    assert persisted == []
  end

  test ":approve is unaffected by this fix -- freeze_window_id is not in its accept list" do
    org_id = "org-approve-#{System.unique_integer([:positive])}"
    window = create_window!(org_id, true)

    override =
      ApprovalFreezeOverride
      |> Ash.Changeset.for_create(:create, override_attrs(org_id, window.id))
      |> Ash.create!(authorize?: false)

    approved =
      override
      |> Ash.Changeset.for_update(:approve, %{approved_by: "approver-1"})
      |> Ash.update!(authorize?: false)

    assert approved.approved_by == "approver-1"
    assert approved.freeze_window_id == window.id
  end
end
