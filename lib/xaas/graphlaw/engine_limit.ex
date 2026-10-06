defmodule Xaas.Graphlaw.EngineLimit do
  @moduledoc """
  One engine limit from graphlaw's capability registry (e.g.
  `max_json_depth = 64`, scope `abi`, source `src/abi.rs`).

  `refusal_name` is the engine's typed refusal payload name for the limit
  (e.g. `state_quads`); nil when the engine enforces the limit without a
  dedicated refusal name — mirroring the source registry exactly.
  """
  use Xaas.Resource,
    domain: Xaas.Graphlaw,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("graphlaw_engine_limits")
    repo(Xaas.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:value, :integer, allow_nil?: false, public?: true)
    attribute(:scope, :string, allow_nil?: false, public?: true)
    attribute(:source, :string, allow_nil?: false, public?: true)
    attribute(:unit, :string, allow_nil?: false, public?: true)
    attribute(:refusal_name, :string, allow_nil?: true, public?: true)

    timestamps()
  end

  identities do
    identity(:unique_name, [:name])
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name, :value, :scope, :source, :unit, :refusal_name])
      upsert?(true)
      upsert_identity(:unique_name)
    end
  end
end
