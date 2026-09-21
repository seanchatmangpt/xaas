defmodule Xaas.Billing.RevenueRecognition do
  @moduledoc """
  Durable evidence that an admitted FIBO-grounded economic source was recognized as
  revenue or other income by an authorized accounting decision.

  This resource is deliberately not public-writeable. `:actuate_recognition` is a
  consequential create action and is fenced by `Xaas.Actuation.Validations.ReactorContext`.
  The only supported mutation path is therefore `Xaas.Actuation` (normally through
  `Xaas.Billing.Revenue.recognize/3`), which gives the event an intent, prepared receipt,
  authority evidence, idempotency key, and deterministic replay behavior.

  The source ontology revision is persisted alongside the source IRI so a historical
  receipt retains semantic standing if the upstream ontology later changes.

  A row records an accounting assertion; it does not itself move money or call an
  external payment rail.
  """

  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Billing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "billing_revenue_recognitions"
    repo Xaas.Repo
  end

  policies do
    bypass action_type(:read) do
      authorize_if always()
    end

    policy always() do
      forbid_if always()
    end
  end

  actions do
    defaults [:read]

    create :actuate_recognition do
      public? false

      accept [
        :org_id,
        :source_key,
        :source_label,
        :source_iri,
        :source_revision,
        :economic_family,
        :accounting_classification,
        :recognition_basis,
        :amount,
        :currency,
        :contract_ref,
        :counterparty_ref,
        :external_ref,
        :evidence,
        :period_start,
        :period_end,
        :recognized_at
      ]

      validate Xaas.Actuation.Validations.ReactorContext
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :org_id, :string do
      allow_nil? false
      public? true
    end

    attribute :source_key, :string do
      allow_nil? false
      public? true
    end

    attribute :source_label, :string do
      allow_nil? false
      public? true
    end

    attribute :source_iri, :string do
      allow_nil? false
      public? true
    end

    attribute :source_revision, :string do
      allow_nil? false
      public? true
    end

    attribute :economic_family, :string do
      allow_nil? false
      public? true
    end

    attribute :accounting_classification, :string do
      allow_nil? false
      public? true
    end

    attribute :recognition_basis, :string do
      allow_nil? false
      public? true
    end

    attribute :amount, :decimal do
      allow_nil? false
      public? true
    end

    attribute :currency, :string do
      allow_nil? false
      public? true
    end

    attribute :contract_ref, :string do
      public? true
    end

    attribute :counterparty_ref, :string do
      public? true
    end

    attribute :external_ref, :string do
      public? true
    end

    attribute :evidence, :map do
      allow_nil? false
      default %{}
      public? true
    end

    attribute :period_start, :utc_datetime do
      public? true
    end

    attribute :period_end, :utc_datetime do
      public? true
    end

    attribute :recognized_at, :utc_datetime do
      allow_nil? false
      default &DateTime.utc_now/0
      public? true
    end

    timestamps()
  end
end
