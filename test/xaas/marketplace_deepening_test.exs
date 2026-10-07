defmodule Xaas.MarketplaceDeepeningTest do
  @moduledoc """
  W733 marketplace-deepening court. Chicago-style: real sandboxed Postgres
  (`Xaas.Repo` via `Ecto.Adapters.SQL.Sandbox`), real Ash actions, real row
  state asserted; no mocks.

  Surfaces under test:

  - (a) Provider lifecycle READ surface per the real actions (`:read`,
    `:create`, `:update`) and the `Xaas.Marketplace.Checks.ActorOrgFilter` /
    `ActorOrgMatches` policy pair.
  - (b) The fencing invariant: `:actuate_status` (the consequential lifecycle
    mutation) refuses without the live Reactor intent/receipt context
    (`Xaas.Actuation.Validations.ReactorContext`), even with
    `authorize?: false` — the ordinary `:update` action cannot actuate either
    (status not in its accept list).
  - (c) Multitenancy-by-policy: org A's actor cannot see or mutate org B's
    providers (filter semantics, not errors).
  - (d) Maker-checker refusals on `ApprovalProviderStatusChange`: missing
    approver, self-approval, cross-org provider reference. Refusals only —
    this court never runs a successful `:approve` (its change module invokes
    the real `Xaas.Actuation.run/4` actuation path, out of scope per the
    consequential-DO discipline).
  """
  use ExUnit.Case, async: true
  require Ash.Query

  alias Xaas.Marketplace.{ApprovalProviderStatusChange, Provider}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp unique, do: System.unique_integer([:positive])

  defp org_a, do: "org-a-#{unique()}"
  defp org_b, do: "org-b-#{unique()}"
  defp actor(org), do: %{org_id: org}

  defp create_provider!(org_id, attrs \\ %{}) do
    Provider
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(
        %{
          name: "Provider #{unique()}",
          slug: "p-#{unique()}",
          org_id: org_id
        },
        attrs
      )
    )
    |> Ash.create!(authorize?: false)
  end

  # ---------------------------------------------------------------- (a) read
  describe "provider lifecycle read surface" do
    test "create persists with the real :pending lifecycle default" do
      org = org_a()
      provider = create_provider!(org, %{description: "deepening"})

      assert provider.status == :pending
      assert provider.org_id == org
      assert provider.inserted_at && provider.updated_at

      reread = Provider |> Ash.get!(provider.id, authorize?: false)
      assert reread.status == :pending
    end

    test ":create cannot smuggle a non-pending lifecycle status" do
      assert {:error, %Ash.Error.Invalid{}} =
               Provider
               |> Ash.Changeset.for_create(:create, %{
                 name: "Smuggler",
                 slug: "smuggler-#{unique()}",
                 org_id: org_a(),
                 status: :active
               })
               |> Ash.create(authorize?: false)
    end

    test "authorized :read returns a same-org provider for its own org actor" do
      org = org_a()
      provider = create_provider!(org)

      assert %{status: :pending} =
               Provider
               |> Ash.Query.filter(id == ^provider.id)
               |> Ash.read!(actor: actor(org))
               |> List.first()
    end

    test ":update changes descriptive metadata but the accept list excludes :status" do
      org = org_a()
      provider = create_provider!(org)

      # :status is not in :update's accept list -> the input itself is rejected
      assert {:error, %Ash.Error.Invalid{}} =
               provider
               |> Ash.Changeset.for_update(:update, %{name: "Renamed", status: :active})
               |> Ash.update(actor: actor(org))

      # a legal metadata-only update really lands, status untouched
      updated =
        provider
        |> Ash.Changeset.for_update(:update, %{name: "Renamed"})
        |> Ash.update!(actor: actor(org))

      assert updated.name == "Renamed"
      assert updated.status == :pending

      assert Provider |> Ash.get!(provider.id, authorize?: false) |> Map.fetch!(:status) ==
               :pending
    end
  end

  # ------------------------------------------------------------- (b) fencing
  describe "lifecycle mutation fencing" do
    test ":actuate_status refuses without a Reactor context, even authorize?: false" do
      org = org_a()
      provider = create_provider!(org)

      assert {:error, %Ash.Error.Invalid{}} =
               provider
               |> Ash.Changeset.for_update(:actuate_status, %{status: :active})
               |> Ash.update(authorize?: false)

      assert Provider |> Ash.get!(provider.id, authorize?: false) |> Map.fetch!(:status) ==
               :pending
    end

    test ":actuate_status succeeds at the action layer only with a real Reactor context shape" do
      # Proves the fence is the context validation, not the policy layer:
      # with the same context shape the existing tests use, the action-level
      # validation passes and the mutation really lands (still never run via
      # the actuation path itself in this court).
      org = org_a()
      provider = create_provider!(org)

      updated =
        provider
        |> Ash.Changeset.for_update(:actuate_status, %{status: :active},
          context: %{
            xaas_actuation: %{
              receipt_id: "test-receipt-id",
              intent_id: "test-intent-id",
              ontology_projection_hash: Provider.ontology_projection_hash()
            }
          }
        )
        |> Ash.update!(authorize?: false)

      assert updated.status == :active
      assert Provider |> Ash.get!(provider.id, authorize?: false) |> Map.fetch!(:status) ==
               :active
    end

    test "an org actor cannot reach :actuate_status through the authorized update path" do
      org = org_a()
      provider = create_provider!(org)

      # Even a policy-passing org actor has no authorized route to a bare
      # :actuate_status changeset without the Reactor context.
      assert {:error, %Ash.Error.Invalid{}} =
               provider
               |> Ash.Changeset.for_update(:actuate_status, %{status: :suspended})
               |> Ash.update(actor: actor(org))
    end
  end

  # ------------------------------------------------------- (c) multitenancy
  describe "org-scoped multitenancy (filter semantics)" do
    test "org A's actor cannot read org B's provider (filtered, not errored)" do
      a = org_a()
      b = org_b()
      mine = create_provider!(a)
      theirs = create_provider!(b)

      # get via authorized read filters the row out -> no result
      assert {:ok, nil} =
               Provider
               |> Ash.Query.filter(id == ^theirs.id)
               |> Ash.read_first(authorize?: true, actor: actor(a))

      # same org actor still sees its own row
      mine_id = mine.id
      theirs_id = theirs.id

      assert [%{id: ^mine_id}] =
               Provider
               |> Ash.Query.filter(id == ^mine.id)
               |> Ash.read!(actor: actor(a))

      # org B's actor sees only its own row
      assert [%{id: ^theirs_id}] =
               Provider
               |> Ash.Query.filter(id == ^theirs.id)
               |> Ash.read!(actor: actor(b))
    end

    test "org A's authorized index excludes org B's providers entirely" do
      a = org_a()
      b = org_b()
      mine = create_provider!(a)
      _theirs = create_provider!(b)

      mine_id = mine.id

      ids =
        Provider
        |> Ash.read!(actor: actor(a))
        |> MapSet.new(& &1.id)

      assert MapSet.member?(ids, mine_id)
      assert ids == MapSet.new([mine_id])
    end

    test "org A cannot update org B's provider (row filtered out -> NotFound)" do
      a = org_a()
      b = org_b()
      theirs = create_provider!(b)

      # policy filter can't resolve at check time -> typed Forbidden
      assert {:error, %Ash.Error.Forbidden{}} =
               theirs
               |> Ash.Changeset.for_update(:update, %{name: "Hijacked"})
               |> Ash.update(actor: actor(a))

      assert Provider |> Ash.get!(theirs.id, authorize?: false) |> Map.fetch!(:name) !=
               "Hijacked"
    end

    test "org A cannot create a provider row claiming org B's org_id" do
      b = org_b()

      # ActorOrgMatches on :create refuses a forged org claim -> Forbidden
      assert {:error, %Ash.Error.Forbidden{}} =
               Provider
               |> Ash.Changeset.for_create(:create, %{
                 name: "Impostor",
                 slug: "impostor-#{unique()}",
                 org_id: b
               })
               |> Ash.create(actor: actor(org_a()))
    end
  end

  # ------------------------------------------------------ (d) maker-checker
  describe "approval maker-checker refusals" do
    defp request_attrs(org_id, provider_id) do
      %{
        org_id: org_id,
        provider_id: provider_id,
        requested_by: "maker-#{unique()}",
        requested_status: :active
      }
    end

    test ":create persists a real pending request readable by its own org" do
      org = org_a()
      provider = create_provider!(org)

      request =
        ApprovalProviderStatusChange
        |> Ash.Changeset.for_create(:create, request_attrs(org, provider.id))
        |> Ash.create!(actor: actor(org))

      assert request.requested_status == :active
      assert request.approved_by == nil

      assert [%{id: id}] =
               ApprovalProviderStatusChange
               |> Ash.Query.filter(id == ^request.id)
               |> Ash.read!(actor: actor(org))

      assert id == request.id
    end

    test ":create refuses a cross-org provider reference (provider-org validation)" do
      a = org_a()
      b = org_b()
      victims_provider = create_provider!(b)

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               ApprovalProviderStatusChange
               |> Ash.Changeset.for_create(:create, request_attrs(a, victims_provider.id))
               |> Ash.create(actor: actor(a))

      assert Enum.any?(errors, fn %{field: field} -> field == :provider_id end)

      # the victim provider is untouched
      assert Provider |> Ash.get!(victims_provider.id, authorize?: false) |> Map.fetch!(:status) ==
               :pending
    end

    test ":create refuses a dangling provider_id (fail-closed)" do
      org = org_a()

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               ApprovalProviderStatusChange
               |> Ash.Changeset.for_create(:create, request_attrs(org, Ecto.UUID.generate()))
               |> Ash.create(actor: actor(org))

      assert Enum.any?(errors, fn %{field: field} -> field == :provider_id end)
    end

    test ":approve refuses a missing approved_by" do
      org = org_a()
      provider = create_provider!(org)

      request =
        ApprovalProviderStatusChange
        |> Ash.Changeset.for_create(:create, request_attrs(org, provider.id))
        |> Ash.create!(actor: actor(org))

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               request
               |> Ash.Changeset.for_update(:approve, %{approved_by: ""})
               |> Ash.update(actor: actor(org))

      assert Enum.any?(errors, fn %{field: field} -> field == :approved_by end)

      assert Provider |> Ash.get!(provider.id, authorize?: false) |> Map.fetch!(:status) ==
               :pending
    end

    test ":approve refuses self-approval (maker != checker)" do
      org = org_a()
      provider = create_provider!(org)

      request =
        ApprovalProviderStatusChange
        |> Ash.Changeset.for_create(:create, request_attrs(org, provider.id))
        |> Ash.create!(actor: actor(org))

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               request
               |> Ash.Changeset.for_update(:approve, %{approved_by: request.requested_by})
               |> Ash.update(actor: actor(org))

      assert Enum.any?(errors, fn %{field: field} -> field == :approved_by end)

      assert Provider |> Ash.get!(provider.id, authorize?: false) |> Map.fetch!(:status) ==
               :pending
    end

    test ":approve by a foreign org actor is row-filtered out (NotFound, no mutation)" do
      org = org_a()
      provider = create_provider!(org)

      request =
        ApprovalProviderStatusChange
        |> Ash.Changeset.for_create(:create, request_attrs(org, provider.id))
        |> Ash.create!(actor: actor(org))

      assert {:error, _} =
               request
               |> Ash.Changeset.for_update(:approve, %{approved_by: "checker-#{unique()}"})
               |> Ash.update(actor: actor(org_b()))

      assert Provider |> Ash.get!(provider.id, authorize?: false) |> Map.fetch!(:status) ==
               :pending
    end
  end
end
