defmodule Xaas.Generation do
  @moduledoc """
  Deterministic generation closure domain (docs/jira/v26.9.11/
  deterministic-generation-closure.md). Owns the admission boundary
  enforcing `g(CanonicalGraph) -> Projection` as the only lawful
  generation path, and forbidding `CanonicalGraph + ManualPatch`.
  """
  use Ash.Domain, otp_app: :xaas

  resources do
    resource(Xaas.Generation.ProjectionRecord)
  end
end
