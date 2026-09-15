defmodule Xaas.Ultracode do
  @moduledoc """
  Run/Epoch/Receipt control-plane domain.

  Formalizes the Run/Epoch/Receipt semantic model from
  `docs/jira/v26.9.11/unified-causal-receipt.md` as real, executable Ash
  resources. A `Run` is a bounded attempt at a goal across ordered `Epoch`s;
  each `Epoch` is one cycle of that attempt and, on completion, must be
  evidenced by a `Receipt` (see the `CompletedEpoch => Receipt` invariant on
  `Xaas.Ultracode.Epoch`).

  Deliberately not modeled as resources here (per the ontology recon this
  domain is manufactured from): `ExactSubject` (a plain string, no identity
  beyond itself), `AuthorityCeiling` (a `:map`, matching the existing
  `authority: Keyword.get(opts, :authority, %{})` pattern in
  `Xaas.Actuation.run/4` -- this repo has no `Authority` module/system and
  none is invented here), and `Standing`/lifecycle state (an `:atom`
  controlled-vocabulary attribute, matching `WebhookDelivery`/
  `CapabilityLivenessReceipt`'s existing status-as-attribute convention
  rather than one resource type per state).
  """

  use Ash.Domain,
    otp_app: :xaas,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain, AshAdmin.Domain]

  admin do
    show?(true)
  end

  resources do
    resource(Xaas.Ultracode.Run)
    resource(Xaas.Ultracode.Epoch)
    resource(Xaas.Ultracode.Receipt)
  end
end
