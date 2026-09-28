defmodule Xaas.Ultracode.CapitalCensus.Resolution do
  use Xaas.Resource, otp_app: :xaas, domain: Xaas.Ultracode, data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key(:id)

    attribute :outcome, Xaas.Ultracode.CapitalCensus.Types.ResolutionOutcome do
      allow_nil?(false)
      public?(true)
    end

    attribute :receipt_ref, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :work_order_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  actions do
    defaults([
      :read,
      create: [:outcome, :receipt_ref, :work_order_id],
      update: [:outcome, :receipt_ref, :work_order_id]
    ])
  end

  postgres do
    table("resolutions")
    repo(Xaas.Repo)
  end
end
