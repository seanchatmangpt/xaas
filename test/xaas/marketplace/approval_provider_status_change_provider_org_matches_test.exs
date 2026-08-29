defmodule Xaas.Marketplace.ApprovalProviderStatusChangeProviderOrgMatchesTest do
  @moduledoc """
  Real Chicago-style tests for the real, twenty-third-pass ERRC grid fix
  (`docs/claude/diataxis/explanation/errc-innovation-grid.md`, item 33):
  `Xaas.Marketplace.ApprovalProviderStatusChange`'s `:create` action
  previously accepted a caller-supplied `provider_id` with zero validation
  against the referenced `Xaas.Marketplace.Provider`'s own `org_id`, even
  though both `:create` and `:approve` correctly scoped the request row's
  own `org_id` to the actor. This file proves the real fix --
  `Xaas.Marketplace.Validations.ApprovalProviderStatusChangeProviderOrgMatches`
  -- against a real, sandboxed Postgres (`Xaas.Repo`), real
  `Ash.Changeset.for_create` + `Ash.create` calls. No mocking.

  A real, temporary, uncommitted HTTP-level repro (written, run once,
  deleted, never committed) independently re-confirmed the live pre-fix
  exploit this session: `CREATE STATUS: 201`, `APPROVE STATUS: 200`,
  `VICTIM PROVIDER STATUS AFTER: active` -- an actor entirely within its
  own org flipped a different, victim org's real `Provider.status`. The
  full end-to-end HTTP-level regression test for that exact attack shape
  lives in
  `test/kanban_web/controllers/approval_provider_status_change_controller_test.exs`
  (added alongside this file); this file covers the validation's own unit
  behavior directly.
  """
  use ExUnit.Case, async: true

  alias Xaas.Marketplace.{ApprovalProviderStatusChange, Provider}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_provider!(org_id, status) do
    # `status` is intentionally absent from Provider's public :create accept
    # list -- lifecycle status is consequential state that must flow through
    # the real Reactor-actuated per-transition actions (:activate/:suspend/
    # :reactivate). For fixture setup
    # here we only need the *precondition* row state, not to exercise that
    # actuation path, so seed the status directly the same way this repo's
    # other Chicago-style tests seed precondition state (Ash.Seed.seed!).
    Provider
    |> Ash.Changeset.for_create(:create, %{
      name: "Test Provider",
      slug: "provider-#{System.unique_integer([:positive])}",
      org_id: org_id
    })
    |> Ash.create!(authorize?: false)
    |> Ash.Seed.update!(%{status: status}, authorize?: false)
  end

  defp change_attrs(org_id, provider_id) do
    %{
      org_id: org_id,
      provider_id: provider_id,
      requested_by: "requester-#{System.unique_integer([:positive])}",
      requested_status: :active
    }
  end

  defp field_errors(%Ash.Error.Invalid{errors: errors}, field) do
    Enum.filter(errors, fn
      %{field: ^field} -> true
      _ -> false
    end)
  end

  test "a real request referencing a real, same-org provider succeeds" do
    org_id = "org-legit-#{System.unique_integer([:positive])}"
    provider = create_provider!(org_id, :pending)

    change =
      ApprovalProviderStatusChange
      |> Ash.Changeset.for_create(:create, change_attrs(org_id, provider.id))
      |> Ash.create!(authorize?: false)

    assert change.provider_id == provider.id
    assert change.org_id == org_id
  end

  test "a provider_id that references zero real rows is rejected" do
    org_id = "org-ghost-#{System.unique_integer([:positive])}"
    fake_id = Ecto.UUID.generate()

    assert {:error, error} =
             ApprovalProviderStatusChange
             |> Ash.Changeset.for_create(:create, change_attrs(org_id, fake_id))
             |> Ash.create(authorize?: false)

    assert [_ | _] = field_errors(error, :provider_id)

    persisted =
      ApprovalProviderStatusChange
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&(&1.org_id == org_id))

    assert persisted == []
  end

  test "a real provider belonging to a DIFFERENT org is rejected -- the real, live exploit this fix closes" do
    victim_org = "org-victim-#{System.unique_integer([:positive])}"
    attacker_org = "org-attacker-#{System.unique_integer([:positive])}"
    victim_provider = create_provider!(victim_org, :pending)

    assert {:error, error} =
             ApprovalProviderStatusChange
             |> Ash.Changeset.for_create(:create, change_attrs(attacker_org, victim_provider.id))
             |> Ash.create(authorize?: false)

    assert [_ | _] = field_errors(error, :provider_id)

    # No real cross-org request row was persisted despite the rejection.
    persisted =
      ApprovalProviderStatusChange
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&(&1.org_id == attacker_org))

    assert persisted == []

    # The victim's Provider status was never touched.
    victim_after = Provider |> Ash.get!(victim_provider.id, authorize?: false)
    assert victim_after.status == :pending
  end

  test ":approve is unaffected by this fix -- provider_id is not in its accept list" do
    org_id = "org-approve-#{System.unique_integer([:positive])}"
    provider = create_provider!(org_id, :pending)

    change =
      ApprovalProviderStatusChange
      |> Ash.Changeset.for_create(:create, change_attrs(org_id, provider.id))
      |> Ash.create!(authorize?: false)

    approved =
      change
      |> Ash.Changeset.for_update(:approve, %{approved_by: "approver-1"})
      |> Ash.update!(authorize?: false)

    assert approved.approved_by == "approver-1"
    assert approved.provider_id == provider.id

    provider_after = Provider |> Ash.get!(provider.id, authorize?: false)
    assert provider_after.status == :active
  end
end
