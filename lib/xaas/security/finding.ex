defmodule Xaas.Security.Finding do
  @moduledoc """
  One security finding from an estate scan (sobelow / hex.audit / trivy /
  mutation / red team), with its admission disposition. ETS-backed: this
  slice is the ingestion + disposition boundary, not durable storage.
  """
  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Security,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: []

  ets do
    private?(true)
  end

  # SPEC-31 deepening (lane W982a): read carve-out via bypass; the floor
  # stays deny-by-default for every other action type.
  policies do
    bypass action_type(:read) do
      authorize_if(always())
    end

    policy always() do
      forbid_if(always())
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:severity, :atom,
      allow_nil?: false,
      public?: true,
      constraints: [one_of: [:critical, :high, :medium, :low, :info]]
    )

    attribute(:source, :atom,
      allow_nil?: false,
      public?: true,
      constraints: [one_of: [:sobelow, :hex_audit, :trivy, :mutation, :red_team]]
    )

    attribute(:file, :string, allow_nil?: false, public?: true)
    attribute(:line, :integer, allow_nil?: true, public?: true)
    attribute(:description, :string, allow_nil?: false, public?: true)

    attribute(:disposition, :atom,
      allow_nil?: false,
      public?: true,
      default: :pending,
      constraints: [one_of: [:fixed, :accepted_typed, :refused_by_design, :pending]]
    )

    attribute(:court_ref, :string, allow_nil?: true, public?: true)
    attribute(:discovered_at, :utc_datetime, allow_nil?: true, public?: true)
    create_timestamp(:inserted_at)
  end

  actions do
    defaults([:read])

    create :ingest do
      accept([
        :severity,
        :source,
        :file,
        :line,
        :description,
        :disposition,
        :court_ref,
        :discovered_at
      ])
    end
  end
end
