defmodule Xaas.Marketplace.FamilyCourtW984fiTest do
  @moduledoc """
  Lane W984fi unclaimed-family probe court over `lib/xaas/marketplace/`.

  Disposition sweep (2026-10-07, branch feat/playwright-surface) found the
  family heavily covered by existing courts, with three genuinely
  unexercised state-bearing branches:

    1. the `:suspended` requested_status through a real, successful
       maker-checker `:approve` (every existing success-path court
       hardcodes `:active`; `:suspended` appeared only in refusal-path
       courts), plus the full pending -> suspended -> active round-trip
       on one real Provider row;
    2. the `requested_status` atom `one_of` constraint
       (`[:active, :suspended]`) refusing a garbage atom with a typed
       error while leaving the target Provider untouched;
    3. the `Xaas.Marketplace.Checks.ActorOrgMatches.match?/3` catch-all
       `def match?(_actor, _context, _opts), do: false` fallthrough --
       an actor that does not conform to the `%{org_id: binary}` shape
       (here: a plain binary actor with no `:org_id` key) must be denied
       `:create` on both resources that real-reuse the check.

  Real resources, real actions, real sandboxed Postgres / ETS state,
  zero mocks. Mutation rationale per test inline.
  """

  use ExUnit.Case, async: true

  require Ash.Query

  alias Xaas.Marketplace.{ApprovalProviderStatusChange, Provider}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp unique, do: System.unique_integer([:positive, :monotonic])

  defp create_provider!(org_id) do
    Provider
    |> Ash.Changeset.for_create(
      :create,
      %{
        name: "W984fi Provider #{unique()}",
        slug: "w984fi-provider-#{unique()}",
        description: "lane W984fi family court target",
        org_id: org_id
      },
      authorize?: false
    )
    |> Ash.create!()
  end

  defp request!(org_id, provider_id, status) do
    ApprovalProviderStatusChange
    |> Ash.Changeset.for_create(
      :create,
      %{
        org_id: org_id,
        provider_id: provider_id,
        requested_by: "maker-w984fi-#{unique()}",
        requested_status: status
      },
      authorize?: false
    )
    |> Ash.create!()
  end

  defp approve!(approval, checker) do
    approval
    |> Ash.Changeset.for_update(:approve, %{approved_by: checker}, authorize?: false)
    |> Ash.update!()
  end

  defp status(provider_id),
    do: Provider |> Ash.get!(provider_id, authorize?: false) |> Map.fetch!(:status)

  test "an approved :suspended request really suspends the provider; a second approved :active request reactivates it",
       _context do
    # Mutation rationale: kills a mutant that drops/hardcodes the
    # `requested_status` wiring in ApplyProviderStatusChange's
    # `Xaas.Actuation.run/4` call (e.g. always :active) -- the round-trip
    # asserts BOTH enum values actually land on the real row.
    org = "w984fi-suspend-org-#{unique()}"
    provider = create_provider!(org)
    assert status(provider.id) == :pending

    suspend_req = request!(org, provider.id, :suspended)
    approve!(suspend_req, "checker-w984fi-#{unique()}")
    assert status(provider.id) == :suspended

    reactivate_req = request!(org, provider.id, :active)
    approve!(reactivate_req, "checker-w984fi-#{unique()}")
    assert status(provider.id) == :active
  end

  test "requested_status outside the one_of constraint is refused with a typed error and the provider stays untouched",
       _context do
    # Mutation rationale: kills removal of the `constraints(one_of:
    # [:active, :suspended])` block on requested_status -- a garbage atom
    # must be refused at the changeset boundary, not persisted or crashed.
    org = "w984fi-oneof-org-#{unique()}"
    provider = create_provider!(org)

    assert {:error, %Ash.Error.Invalid{}} =
             ApprovalProviderStatusChange
             |> Ash.Changeset.for_create(
               :create,
               %{
                 org_id: org,
                 provider_id: provider.id,
                 requested_by: "maker-w984fi-#{unique()}",
                 requested_status: :deleted
               },
               authorize?: false
             )
             |> Ash.create()

    assert status(provider.id) == :pending
  end

  test "a non-conforming actor (no org_id key) is denied :create on Provider via the ActorOrgMatches catch-all",
       _context do
    # Mutation rationale: kills deletion of the
    # `def match?(_actor, _context, _opts), do: false` fallthrough in
    # Xaas.Marketplace.Checks.ActorOrgMatches -- an actor without the
    # asserted-org shape must fail closed, not raise or pass.
    org = "w984fi-actor-org-#{unique()}"
    provider_attrs = %{
      name: "W984fi Denied #{unique()}",
      slug: "w984fi-denied-#{unique()}",
      description: "must not persist",
      org_id: org
    }

    assert {:error, %Ash.Error.Forbidden{}} =
             Provider
             |> Ash.Changeset.for_create(:create, provider_attrs, actor: "raw-binary-actor")
             |> Ash.create()

    assert Provider
           |> Ash.Query.filter(slug == ^provider_attrs.slug)
           |> Ash.read!(authorize?: false) == []
  end

  test "a non-conforming actor is likewise denied :create on ApprovalProviderStatusChange (verbatim check reuse)",
       _context do
    # Mutation rationale: kills a mutant that swaps either resource's
    # :create bypass off the shared ActorOrgMatches check (the moduledoc
    # claims verbatim reuse across both Marketplace resources) --
    # fail-closed must hold on the approval resource too.
    org = "w984fi-actor-org-#{unique()}"
    provider = create_provider!(org)

    assert {:error, %Ash.Error.Forbidden{}} =
             ApprovalProviderStatusChange
             |> Ash.Changeset.for_create(
               :create,
               %{
                 org_id: org,
                 provider_id: provider.id,
                 requested_by: "maker-w984fi-#{unique()}",
                 requested_status: :active
               },
               actor: %{unrelated: :shape}
             )
             |> Ash.create()

    assert ApprovalProviderStatusChange
           |> Ash.Query.filter(org_id == ^org)
           |> Ash.read!(authorize?: false) == []
  end
end
