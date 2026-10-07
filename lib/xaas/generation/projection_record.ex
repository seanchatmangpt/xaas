defmodule Xaas.Generation.ProjectionRecord do
  @moduledoc """
  The one concrete Ash admission path for this ticket's slice: a record
  of one declared `g(CanonicalGraph) -> Projection` edge, admitted only
  when `Xaas.Generation.Validations.NoManualPatch` confirms the real
  on-disk projection either matches its recorded hash or is a registered
  irreducible handwritten residue.

  Uses `Ash.DataLayer.Ets` (in-memory, ships with Ash core, no Postgres
  migration needed) — this slice is about the admission/validation
  boundary itself, not about giving generation records durable storage,
  which is a separate, later decision.
  """
  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Generation,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    # W982a/W982u-precedent deny-by-default policies floor (previously this
    # resource had NO policies block).
    extensions: []

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:source_path, :string, allow_nil?: false, public?: true)
    attribute(:projection_path, :string, allow_nil?: false, public?: true)
    attribute(:generator_id, :string, allow_nil?: false, public?: true)
    attribute(:recorded_hash, :string, allow_nil?: false, public?: true)
    create_timestamp(:inserted_at)
  end

  actions do
    defaults([:read])

    create :admit do
      accept([:source_path, :projection_path, :generator_id, :recorded_hash])
      validate(Xaas.Generation.Validations.NoManualPatch)
    end
  end

  # SPEC-31 deepening (lane W983h): get+list read queries + deny-by-default
  # policies floor (read bypass, everything else forbidden) — W982a/W982u
  # precedent for resources that previously had no policies block.

  policies do
    bypass action_type(:read) do
      authorize_if(always())
    end

    # Existing tests/DSL consumers create via `:admit`; carve it out
    # explicitly (Witness.CertifiedReceipt's `bypass action(:ingest)`
    # precedent) so the floor only closes non-read, non-admit actions.
    bypass action(:admit) do
      authorize_if(always())
    end

    policy always() do
      forbid_if(always())
    end
  end
end
