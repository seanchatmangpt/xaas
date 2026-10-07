defmodule Xaas.Igniter do
  @moduledoc """
  Real, new Ash domain holding ggen_igniter's machine/pack surface as
  consumer-side projections:

    * `Xaas.Igniter.RefusalCode` — the typed refusal vocabulary
      (ggen_igniter `priv/schema/refusals.schema.json`).
    * `Xaas.Igniter.PackManifest` — the pack manifest inventory (pack name,
      version, profile, gate/verify/misfiled counts).

  The schema/manifest files are the store; these ETS resources are queryable
  projections maintained by `Xaas.Igniter.Catalog`.
  """
  use Ash.Domain,
    otp_app: :xaas,
    extensions: [AshJsonApi.Domain, AshAdmin.Domain, AshTypescript.Rpc]

  admin do
    show?(true)
  end

  resources do
    resource(Xaas.Igniter.PackManifest)
    resource(Xaas.Igniter.RefusalCode)
  end
end
