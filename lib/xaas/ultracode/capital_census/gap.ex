defmodule Xaas.Ultracode.CapitalCensus.Gap do
  use Ash.Resource, otp_app: :xaas, domain: Xaas.Ultracode, data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key(:id)

    attribute :experience_cluster_id, :uuid do
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

    attribute :recurrence_class, Xaas.Ultracode.CapitalCensus.Types.RecurrenceClass do
      allow_nil?(false)
      public?(true)
    end

    attribute :primitive_target, Xaas.Ultracode.CapitalCensus.Types.PrimitiveTarget do
      allow_nil?(false)
      public?(true)
    end

    attribute :episode_count, :integer do
      allow_nil?(false)
      public?(true)
    end

    attribute :falsifier, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :status, Xaas.Ultracode.CapitalCensus.Types.GapStatus do
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    has_many(:work_orders, Xaas.Ultracode.CapitalCensus.WorkOrder)
  end

  actions do
    defaults([
      :read,
      create: [
        :experience_cluster_id,
        :required_closure,
        :residual_shape,
        :context,
        :recurrence_class,
        :primitive_target,
        :episode_count,
        :falsifier,
        :status
      ],
      update: [
        :experience_cluster_id,
        :required_closure,
        :residual_shape,
        :context,
        :recurrence_class,
        :primitive_target,
        :episode_count,
        :falsifier,
        :status
      ]
    ])
  end

  postgres do
    table("gaps")
    repo(Xaas.Repo)
  end
end
