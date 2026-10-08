defmodule Xaas.Marketplace.RemainderCourtW984huTest do
  @moduledoc """
  Lane W984hu — unclaimed-family probe of the remainder of
  `lib/xaas/marketplace/`, going past W984fi (approval flow +
  ActorOrgMatches + ApplyProviderStatusChange) and W984dg (Catalog
  consumption surface). Chicago-style: real sandboxed Postgres rows via
  `Ecto.Adapters.SQL.Sandbox`, real ETS-backed Pack rows, real Ash
  actions, zero mocks. Each test names the mutation it kills.

  Three genuinely unexercised state-bearing branches found in the
  remainder:

    1. `Pack.update` — no direct court ever asserted that `:name` is
       absent from the `:update` accept list (identity immutability) or
       that a direct `:update` round-trips every other accepted v2 field.
    2. `Pack.get_by_id` — the read action's `filter(expr(name == ^arg(:id)))`
       on an ABSENT name was never courted at the action layer (W984dg
       courted `Catalog.get_pack!/1` raising, a different path; the
       HTTP-level test only hits an existing id).
    3. `ApprovalProviderStatusChange` cross-org READ — the resource's
       `:read` bypass delegates to `ActorOrgFilter`, but only Provider's
       cross-org read was ever courted; no test asserted org A cannot
       read org B's pending approval request rows.
  """

  use ExUnit.Case, async: false
  require Ash.Query

  alias Xaas.Marketplace.{ApprovalProviderStatusChange, Pack, Provider}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Pack |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)
    :ok
  end

  defp unique, do: System.unique_integer([:positive])

  defp org_a, do: "org-a-#{unique()}"
  defp org_b, do: "org-b-#{unique()}"

  defp create_provider!(org_id) do
    Provider
    |> Ash.Changeset.for_create(:create, %{
      name: "Provider #{unique()}",
      slug: "p-#{unique()}",
      org_id: org_id
    })
    |> Ash.create!(authorize?: false)
  end

  defp create_pack!(overrides \\ %{}) do
    Pack
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(
        %{
          name: "pack-#{unique()}",
          version: "1.0.0",
          digest: "sha256:" <> String.duplicate("ab", 32),
          download_url: "https://example.com/pack.tar.gz",
          lifecycle_tier: "thin",
          readiness: "gates",
          description: "w984hu court pack"
        },
        overrides
      )
    )
    |> Ash.create!(authorize?: false)
  end

  test "Pack :update round-trips accepted v2 fields in place and :name is immutable (kills an accept-list mutant adding :name)" do
    pack = create_pack!(%{pack_class: nil, ontology_fingerprint: nil, deprecated: false})

    # :name is not in the :update accept list -- supplying it is refused at
    # the real boundary (a mutant that adds :name to the accept list turns
    # this refusal into a successful rename).
    assert_raise Ash.Error.Invalid, ~r/NoSuchInput.*name|name.*invalid|is not accepted/s, fn ->
      pack
      |> Ash.Changeset.for_update(:update, %{name: "hijacked-name"})
      |> Ash.update!(authorize?: false)
    end

    updated =
      pack
      |> Ash.Changeset.for_update(:update, %{
        version: "2.0.0",
        digest: "sha256:" <> String.duplicate("cd", 32),
        download_url: "https://example.com/v2.tar.gz",
        lifecycle_tier: "core",
        readiness: "gates+readiness+verify+witnesses",
        pack_class: "ash",
        ontology_fingerprint: "fp-#{unique()}",
        description: "updated in place",
        deprecated: true
      })
      |> Ash.update!(authorize?: false)

    assert updated.version == "2.0.0"
    assert updated.digest == "sha256:" <> String.duplicate("cd", 32)
    assert updated.download_url == "https://example.com/v2.tar.gz"
    assert updated.lifecycle_tier == "core"
    assert updated.readiness == "gates+readiness+verify+witnesses"
    assert updated.pack_class == "ash"
    assert updated.ontology_fingerprint != nil
    assert updated.description == "updated in place"
    assert updated.deprecated == true

    # Name unchanged on the persisted row, and still only one row.
    reloaded = Pack |> Ash.Query.filter(name == ^pack.name) |> Ash.read_one!(authorize?: false)
    assert reloaded.name == pack.name
    assert Pack |> Ash.Query.filter(name == "hijacked-name") |> Ash.read_one!(authorize?: false) == nil
  end

  test "Pack get_by_id on an absent name really filters to empty (kills removal of the name == ^arg(:id) filter)" do
    create_pack!()

    results =
      Pack
      |> Ash.Query.for_read(:get_by_id, %{id: "never-ingested-pack-#{unique()}"})
      |> Ash.read!(authorize?: false)

    assert results == []

    # Sanity: the same action really returns the row for a present name.
    present = create_pack!()

    assert [%{name: name}] =
             Pack
             |> Ash.Query.for_read(:get_by_id, %{id: present.name})
             |> Ash.read!(authorize?: false)

    assert name == present.name
  end

  test "org A's actor cannot read org B's pending approval request rows (kills removal of the ActorOrgFilter bypass on the read policy)" do
    a = org_a()
    b = org_b()
    provider_b = create_provider!(b)

    _request_b =
      ApprovalProviderStatusChange
      |> Ash.Changeset.for_create(
        :create,
        %{
          org_id: b,
          provider_id: provider_b.id,
          requested_by: "maker-#{unique()}",
          requested_status: :suspended
        },
        actor: %{org_id: b}
      )
      |> Ash.create!()

    # Org A's authorized read is filtered, not errored: zero of org B's rows.
    assert ApprovalProviderStatusChange
           |> Ash.Query.filter(org_id == ^b)
           |> Ash.read(actor: %{org_id: a}) == {:ok, []}

    # The row still exists and is readable by its own org.
    assert {:ok, [_row]} =
             ApprovalProviderStatusChange
             |> Ash.Query.filter(org_id == ^b)
             |> Ash.read(actor: %{org_id: b})
  end
end
