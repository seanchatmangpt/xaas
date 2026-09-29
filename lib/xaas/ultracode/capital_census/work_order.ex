defmodule Xaas.Ultracode.CapitalCensus.WorkOrder do
  use Xaas.Resource, otp_app: :xaas, domain: Xaas.Ultracode, data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key(:id)

    attribute :ticket_id, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :subject, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :observed, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :expected, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :residual, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :classification, Xaas.Ultracode.CapitalCensus.Types.RecurrenceClass do
      allow_nil?(false)
      public?(true)
    end

    attribute :candidate_repair, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :falsifier, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :success_criteria, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :derived_from_receipt, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :status, Xaas.Ultracode.CapitalCensus.Types.WorkOrderStatus do
      allow_nil?(false)
      public?(true)
    end

    attribute :gap_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    has_many(:resolutions, Xaas.Ultracode.CapitalCensus.Resolution)
  end

  actions do
    defaults([
      :read,
      create: [
        :ticket_id,
        :subject,
        :observed,
        :expected,
        :residual,
        :classification,
        :candidate_repair,
        :falsifier,
        :success_criteria,
        :derived_from_receipt,
        :status,
        :gap_id
      ],
      update: [
        :ticket_id,
        :subject,
        :observed,
        :expected,
        :residual,
        :classification,
        :candidate_repair,
        :falsifier,
        :success_criteria,
        :derived_from_receipt,
        :status,
        :gap_id
      ]
    ])
  end

  postgres do
    table("work_orders")
    repo(Xaas.Repo)
  end
end
