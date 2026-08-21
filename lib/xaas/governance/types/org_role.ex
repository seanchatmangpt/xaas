defmodule Xaas.Governance.Types.OrgRole do
  @moduledoc """
  Real org role enum, values ported verbatim from platform-console's
  `ROLES` (`app/lib/authz.ts`): `["viewer", "member", "owner"]`. Used to
  validate each entry's `role` field in
  `Xaas.Governance.ApprovalSsoRoleMappingUpdate`'s `requested_mappings`
  array (see
  `Xaas.Governance.Validations.ApprovalSsoRoleMappingUpdateValidMappings`).
  """
  use Ash.Type.Enum, values: [:viewer, :member, :owner]
end
