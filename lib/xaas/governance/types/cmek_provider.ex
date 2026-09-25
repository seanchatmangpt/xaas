defmodule Xaas.Governance.Types.CmekProvider do
  @moduledoc """
  Real enum, ported verbatim from platform-console's `CmekProvider`
  (`app/lib/orgs.ts`): `"aws-kms" | "gcp-kms" | "azure-keyvault" | "vault"`.
  """
  use Ash.Type.Enum, values: [:aws_kms, :gcp_kms, :azure_keyvault, :vault]
end
