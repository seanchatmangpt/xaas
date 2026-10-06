defmodule Xaas.Witness do
  @moduledoc """
  Certified-receipt witness surface for xaas (implementation lane PW5).

  Brings affidavit's certified-receipt surface into xaas as real Ash
  resources: `Xaas.Witness.CertifiedReceipt` holds an immutable,
  signature-bearing receipt over a subject; `Xaas.Witness.VerificationKey`
  holds the registered verifying keys the receipts verify against.
  `Xaas.Witness.Catalog` is the context that ingests affidavit's mutation
  baseline + signing-surface metadata into these resources and records
  verification results.
  """
  use Ash.Domain,
    otp_app: :xaas,
    extensions: [AshAdmin.Domain]

  admin do
    show?(true)
  end

  resources do
    resource(Xaas.Witness.CertifiedReceipt)
    resource(Xaas.Witness.VerificationKey)
  end
end
