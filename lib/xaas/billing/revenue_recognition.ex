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
    otp_app: :xaas,
    domain: Xaas.Billing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("billing_revenue_recognitions")
    repo(Xaas.Repo)
  end

  # SPEC-07 (W905 W729-GAP-3, lane W982p): real Ash attribute-strategy
  # multitenancy backstop, converging on the convention lane W970a landed on
  # the sibling Xaas.Billing approval resources (see
  # approval_pricing_override.ex for the full comment, including the Ash
  # 3.34 update-path reason for `global?(true)`). Tenant-less operations
  # behave exactly as before (org_id remains `allow_nil?(false)` and is
  # accepted on :actuate_recognition, the only create); any operation that
  # DOES bind a tenant is hard-filtered to that org's rows. The
  # ReactorContext validation below is unchanged -- it still refuses any
  # :actuate_recognition not manufactured through the Xaas.Actuation DO
  # path (which itself accepts a tenant option that now binds isolation).
  # See test/xaas/billing/billing_multitenancy_court_test.exs.
  multitenancy do
    strategy(:attribute)
    attribute(:org_id)
    global?(true)
  end

  policies do
    bypass action_type(:read) do
      authorize_if(always())
    end

    policy always() do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    create :actuate_recognition do
      public?(false)

      accept([
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
      ])

      validate(Xaas.Actuation.Validations.ReactorContext)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :org_id, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :source_key, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :source_label, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :source_iri, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :source_revision, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :economic_family, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :accounting_classification, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :recognition_basis, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :amount, :decimal do
      allow_nil?(false)
      public?(true)
    end

    attribute :currency, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :contract_ref, :string do
      public?(true)
    end

    attribute :counterparty_ref, :string do
      public?(true)
    end

    attribute :external_ref, :string do
      public?(true)
    end

    attribute :evidence, :map do
      allow_nil?(false)
      default(%{})
      public?(true)
    end

    attribute :period_start, :utc_datetime do
      public?(true)
    end

    attribute :period_end, :utc_datetime do
      public?(true)
    end

    attribute :recognized_at, :utc_datetime do
      allow_nil?(false)
      default(&DateTime.utc_now/0)
      public?(true)
    end

    timestamps()
  end
end
