defmodule Xaas.Graphlaw.Capability do
  @moduledoc """
  One semantic authority entry from graphlaw's capability registry: a named
  capability (`RDF 1.2 / codecs / storage IR`), the algorithm/authority that
  provides it (`purrdf`, `purrdf::sparql`), the registry profile (graphlaw
  version) it was ingested under, and the engines that support it.
  """
  use Xaas.Resource,
    domain: Xaas.Graphlaw,
    data_layer: AshPostgres.DataLayer

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

    timestamps()
  end

  identities do
    identity(:unique_name_algorithm, [:name, :algorithm])
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name, :algorithm, :profile, :supported_in])
      upsert?(true)
      upsert_identity(:unique_name_algorithm)
    end
  end
end
