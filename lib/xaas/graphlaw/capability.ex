defmodule Xaas.Graphlaw.Capability do
  @moduledoc """
  One semantic authority entry from graphlaw's capability registry: a named
  capability (`RDF 1.2 / codecs / storage IR`), the algorithm/authority that
  provides it (`purrdf`, `purrdf::sparql`), the registry profile (graphlaw
  version) it was ingested under, and the engines that support it.
  """
  use Xaas.Resource,
    domain: Xaas.Graphlaw,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: []

  postgres do
    table("graphlaw_capabilities")
    repo(Xaas.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:algorithm, :string, allow_nil?: false, public?: true)
    attribute(:profile, :string, allow_nil?: false, public?: true)
    attribute(:supported_in, {:array, :string}, allow_nil?: false, default: [], public?: true)

    # SPEC-09 (W731-GAP-1, W905 backlog): the W731 brief's assumed
    # `:capability_class` enum, now real. Defaults to `:observe` so registry
    # ingest rows (which do not carry a class) stay lawfully least-authority.
    attribute(:capability_class, :atom,
      constraints: [one_of: [:observe, :select, :construct, :do]],
      default: :observe,
      public?: true
    )

    timestamps()
  end

  identities do
    identity(:unique_name_algorithm, [:name, :algorithm])
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name, :algorithm, :profile, :supported_in, :capability_class])
      upsert?(true)
      upsert_identity(:unique_name_algorithm)
    end
  end

  # SPEC-31 deepening (lane W984l): get+list read queries over the existing
  # `:read` action; deny-by-default floor added in the same transition
  # (W982a/W983h precedent), with a `bypass action(:create)` carve-out so the
  # registry ingest/upsert consumption path keeps its existing authorized
  # behavior.

  policies do
    bypass action_type(:read) do
      authorize_if(always())
    end

    bypass action(:create) do
      authorize_if(always())
    end

    policy always() do
      forbid_if(always())
    end
  end
end
