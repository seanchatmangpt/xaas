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
    data_layer: Ash.DataLayer.Ets

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
end
