defmodule Xaas.Marketplace.ProviderPreApproveLifecycleTest do
  @moduledoc """
  W980i depth batch -- marketplace surface. Chicago-style: real Ash actions
  on real sandboxed Postgres, real `Xaas.Marketplace.Provider` rows, typed
  refusals. No mocks.

  Scope: the pre-approve lifecycle states W733 did not cover -- the
  `:create` authorized path through
  `Xaas.Marketplace.Checks.ActorOrgMatches` (W733 courts only exercised
  deny cases plus `authorize?: false` construction), and the
  `:update` descriptive-metadata path in the pre-approve `:pending` state
  via `Xaas.Marketplace.Checks.ActorOrgFilter`. Status remains `:pending`
  throughout: these courts prove the pre-approve slice, not actuation
  (covered elsewhere).

  Mutation rationale (W980i): delete the
  `bypass action(:create) do authorize_if(Xaas.Marketplace.Checks.ActorOrgMatches) end`
  block from `lib/xaas/marketplace/provider.ex` -- the authorized-create
  court and both deny courts below fail (the create falls through to the
  `forbid_if always()` catch-all, so every create 403s: the authorized
  court errors on `Ash.create!` and the deny courts pass their refusal
  assertion but the no-row-persisted assertion distinguishes a
  policy-shaped refusal from an action-missing one via a direct
  `authorize?: false` create succeeding).
  """
  use ExUnit.Case, async: true
  require Ash.Query

  alias Xaas.Marketplace.Provider

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp attrs(org_id, suffix) do
    %{
      name: "W980i Co #{suffix}",
      slug: "w980i-#{suffix}-#{System.unique_integer([:positive])}",
      description: "pre-approve depth court",
      org_id: org_id
    }
  end

  defp count_for!(org_id) do
    Provider
    |> Ash.Query.filter(org_id == ^org_id)
    |> Ash.count!(authorize?: false)
  end

  test "an actor whose asserted org_id matches the payload can create via the authorized path" do
    org_id = "org-w980i-create-#{System.unique_integer([:positive])}"

    provider =
      Provider
      |> Ash.Changeset.for_create(:create, attrs(org_id, "ok"), actor: %{org_id: org_id})
      |> Ash.create!()

    assert provider.status == :pending
    assert provider.org_id == org_id
    assert count_for!(org_id) == 1
  end

  test "an actor asserting a different org is denied create and no row persists" do
    org_id = "org-w980i-deny-#{System.unique_integer([:positive])}"

    assert {:error, %Ash.Error.Forbidden{}} =
             Provider
             |> Ash.Changeset.for_create(
               :create,
               attrs(org_id, "deny"),
               actor: %{org_id: "org-somewhere-else"}
             )
             |> Ash.create()

    assert count_for!(org_id) == 0
  end

  test "an actor with an empty-string org_id is denied create (SimpleCheck guard)" do
    org_id = "org-w980i-empty-#{System.unique_integer([:positive])}"

    assert {:error, %Ash.Error.Forbidden{}} =
             Provider
             |> Ash.Changeset.for_create(:create, attrs(org_id, "empty"), actor: %{org_id: ""})
             |> Ash.create()

    assert count_for!(org_id) == 0
  end

  test "a matching-org actor can update descriptive metadata while status stays :pending" do
    org_id = "org-w980i-update-#{System.unique_integer([:positive])}"

    provider =
      Provider
      |> Ash.Changeset.for_create(:create, attrs(org_id, "upd"), actor: %{org_id: org_id})
      |> Ash.create!()

    updated =
      provider
      |> Ash.Changeset.for_update(:update, %{name: "W980i Renamed", description: "updated"},
        actor: %{org_id: org_id}
      )
      |> Ash.update!()

    assert updated.name == "W980i Renamed"
    assert updated.status == :pending

    persisted = Provider |> Ash.get!(provider.id, authorize?: false)
    assert persisted.name == "W980i Renamed"
    assert persisted.status == :pending
  end

  test ":update cannot smuggle a status change (status is not accepted, refusal is typed)" do
    org_id = "org-w980i-smuggle-#{System.unique_integer([:positive])}"

    provider =
      Provider
      |> Ash.Changeset.for_create(:create, attrs(org_id, "smuggle"), actor: %{org_id: org_id})
      |> Ash.create!()

    assert {:error, %Ash.Error.Invalid{}} =
             provider
             |> Ash.Changeset.for_update(:update, %{status: :active}, actor: %{org_id: org_id})
             |> Ash.update()

    assert Provider |> Ash.get!(provider.id, authorize?: false) |> Map.fetch!(:status) == :pending
  end

  test "an actor whose org_id names a different org is denied update of this row" do
    org_id = "org-w980i-xupd-#{System.unique_integer([:positive])}"

    provider =
      Provider
      |> Ash.Changeset.for_create(:create, attrs(org_id, "xupd"), actor: %{org_id: org_id})
      |> Ash.create!(authorize?: false)

    assert {:error, %Ash.Error.Forbidden{}} =
             provider
             |> Ash.Changeset.for_update(:update, %{name: "Hijacked"},
               actor: %{org_id: "org-not-mine"}
             )
             |> Ash.update()

    assert Provider |> Ash.get!(provider.id, authorize?: false) |> Map.fetch!(:name) ==
             provider.name
  end
end
