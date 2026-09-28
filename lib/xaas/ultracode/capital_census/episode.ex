defmodule Xaas.Ultracode.CapitalCensus.Episode do
  use Xaas.Resource, otp_app: :xaas, domain: Xaas.Ultracode, data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key(:id)

    attribute :subject, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :outcome, Xaas.Ultracode.CapitalCensus.Types.FrontierOutcome do
      allow_nil?(false)
      public?(true)
    end

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

    timestamps()
  end

  actions do
    defaults([
      :read,
      create: [:subject, :outcome, :required_closure, :residual_shape, :context],
      update: [:subject, :outcome, :required_closure, :residual_shape, :context]
    ])
  end

  postgres do
    table("episodes")
    repo(Xaas.Repo)
  end
end
