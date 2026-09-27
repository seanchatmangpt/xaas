defmodule Xaas.Ultracode.CapitalCensus.ExperienceCluster do
  use Ash.Resource, otp_app: :xaas, domain: Xaas.Ultracode, data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key(:id)

    attribute :required_closure, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :residual_shape, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :context, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :episode_count, :integer do
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    has_many(:gaps, Xaas.Ultracode.CapitalCensus.Gap)
  end

  actions do
    defaults([
      :read,
      create: [:required_closure, :residual_shape, :context, :episode_count],
      update: [:required_closure, :residual_shape, :context, :episode_count]
    ])
  end

  postgres do
    table("experience_clusters")
    repo(Xaas.Repo)
  end
end
