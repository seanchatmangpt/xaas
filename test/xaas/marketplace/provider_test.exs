defmodule Xaas.Marketplace.ProviderTest do
  @moduledoc """
  Real Chicago-style tests: real `Ecto.Adapters.SQL.Sandbox`-backed
  Postgres (`Xaas.Repo`), real `Ash.Changeset.for_create` + `Ash.create!`/
  `Ash.read!` calls against the real `marketplace_providers` table. No
  mocking.
  """
  use ExUnit.Case, async: true
  require Ash.Query

  alias Xaas.Marketplace.Provider

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create!(attrs) do
    Provider
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create!(authorize?: false)
  end

  test "creating a provider persists real attributes with the real :pending default status" do
    org_id = "org-#{System.unique_integer([:positive])}"

    provider =
      create!(%{
        name: "Acme Widgets",
        slug: "acme-widgets-#{System.unique_integer([:positive])}",
        description: "Widgets as a service",
        org_id: org_id
      })

    assert provider.name == "Acme Widgets"
    assert provider.status == :pending
    assert provider.org_id == org_id
    assert provider.inserted_at != nil
    assert provider.updated_at != nil

    reread = Provider |> Ash.get!(provider.id, authorize?: false)
    assert reread.id == provider.id
  end

  test "slug uniqueness is really enforced" do
    slug = "dup-slug-#{System.unique_integer([:positive])}"
    create!(%{name: "First", slug: slug, org_id: "org-a"})

    assert {:error, %Ash.Error.Invalid{}} =
             Provider
             |> Ash.Changeset.for_create(:create, %{name: "Second", slug: slug, org_id: "org-b"})
             |> Ash.create(authorize?: false)
  end

  test "provider lifecycle status cannot bypass the Reactor actuation boundary" do
    provider =
      create!(%{name: "Beta Co", slug: "beta-co-#{System.unique_integer([:positive])}", org_id: "org-c"})

    assert {:error, %Ash.Error.Invalid{}} =
             provider
             |> Ash.Changeset.for_update(:actuate_status, %{status: :active})
             |> Ash.update(authorize?: false)

    assert Provider |> Ash.get!(provider.id, authorize?: false) |> Map.fetch!(:status) == :pending
  end

  # Real, disclosed change this session: Xaas.Marketplace.Provider gained a real
  # AshStateMachine `state_machine do transitions do ... end end` declaration
  # (pending -> active -> suspended -> active) enforced by the new
  # Xaas.Marketplace.Validations.ProviderStatusTransition validation (see that
  # module's moduledoc for why AshStateMachine's own built-in `transition_state/1`
  # change can't be used directly here). These two tests exercise it through the
  # real Reactor actuation boundary -- Xaas.Actuation.run/4, same as
  # test/xaas/actuation_test.exs -- rather than a bare `authorize?: false` update,
  # so a real admitted intent/receipt context is present and the failure being
  # asserted is genuinely the transition-graph validation, not ReactorContext.
  test "an undeclared status transition (pending -> suspended, skipping active) is really refused" do
    provider =
      create!(%{
        name: "Skip Co",
        slug: "skip-co-#{System.unique_integer([:positive])}",
        org_id: "org-skip"
      })

    assert {:error, %Ash.Error.Invalid{} = error} =
             Xaas.Actuation.run(
               Provider,
               :actuate_status,
               %{status: :suspended},
               subject_id: provider.id,
               idempotency_key: "provider-status-transition-test-#{System.unique_integer([:positive])}",
               authorize?: false,
               authority: %{kind: "test_authority", source: "provider_test"}
             )

    assert Exception.message(error) =~ "invalid provider status transition"
    assert Provider |> Ash.get!(provider.id, authorize?: false) |> Map.fetch!(:status) == :pending
  end

  test "the real declared transition graph (pending -> active -> suspended -> active) is admitted" do
    provider =
      create!(%{
        name: "Graph Co",
        slug: "graph-co-#{System.unique_integer([:positive])}",
        org_id: "org-graph"
      })

    key_prefix = "provider-status-transition-graph-test-#{System.unique_integer([:positive])}"

    assert {:ok, %{status: :succeeded}} =
             Xaas.Actuation.run(Provider, :actuate_status, %{status: :active},
               subject_id: provider.id,
               idempotency_key: "#{key_prefix}-1",
               authorize?: false,
               authority: %{kind: "test_authority", source: "provider_test"}
             )

    assert Provider |> Ash.get!(provider.id, authorize?: false) |> Map.fetch!(:status) == :active

    assert {:ok, %{status: :succeeded}} =
             Xaas.Actuation.run(Provider, :actuate_status, %{status: :suspended},
               subject_id: provider.id,
               idempotency_key: "#{key_prefix}-2",
               authorize?: false,
               authority: %{kind: "test_authority", source: "provider_test"}
             )

    assert Provider |> Ash.get!(provider.id, authorize?: false) |> Map.fetch!(:status) == :suspended
  end

  # Real, disclosed change this session: the `AshIam` pilot on this
  # resource was removed (see `Xaas.Marketplace.Provider`'s own moduledoc
  # "AshIam read pilot -- removed this session" section for the real,
  # live-verified reason: `ash_iam`'s auto-injected field_policies
  # ANDed against every other authorization path and made every real
  # HTTP `POST`/`PATCH` response serialize its attributes as
  # `Ash.ForbiddenField` -> `null`, regardless of a real, already-passing
  # action-level authorization). `:read` now runs on
  # `Xaas.Marketplace.Checks.ActorOrgFilter`, the same real
  # `%{org_id: ...}`-actor mechanism `:create`/`:update` use -- these two
  # tests are rewritten to that real mechanism rather than the removed
  # `iam_policy`/`AshIam.Check` shape.
  test "an actor whose real org_id matches can read that org's real row" do
    provider =
      create!(%{
        name: "Readable Co",
        slug: "readable-co-#{System.unique_integer([:positive])}",
        org_id: "org-readable"
      })

    results = Provider |> Ash.read!(actor: %{org_id: "org-readable"})
    assert Enum.any?(results, &(&1.id == provider.id))
  end

  test "an actor with no real org_id is really denied read -- not silently allowed" do
    _provider =
      create!(%{name: "Hidden Co", slug: "hidden-co-#{System.unique_integer([:positive])}", org_id: "org-d"})

    results = Provider |> Ash.read!(actor: %{})
    assert results == []
  end

  test "an actor whose real org_id names a different org cannot read this row" do
    visible =
      create!(%{
        name: "Visible Co",
        slug: "visible-co-#{System.unique_integer([:positive])}",
        org_id: "org-visible"
      })

    other =
      create!(%{
        name: "Other Co",
        slug: "other-co-#{System.unique_integer([:positive])}",
        org_id: "org-other"
      })

    results = Provider |> Ash.read!(actor: %{org_id: "org-visible"})
    assert Enum.any?(results, &(&1.id == visible.id))
    refute Enum.any?(results, &(&1.id == other.id))
  end
end
