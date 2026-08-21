defmodule Xaas.Governance.Types.DeploymentQuarantineReason do
  @moduledoc """
  NOT ported from a real platform-console enum -- no matching
  quarantine/deploy-block route was found under
  `platform-console/app/app/api/` (searched for `quarantine`/`deploy-block`;
  the closest real routes are `deployments/canary` (traffic-shifting
  promote/rollback, no quarantine concept) and `castle/deploy` (records a
  deployed image, no approval flow)). This is a reasonable, honestly-
  invented fixed set of reasons a deployment would be pulled out of
  rotation pending approval, designed to fit this domain's real
  maker-checker pattern -- not a verbatim port.
  """
  use Ash.Type.Enum, values: [:failed_healthcheck, :security_finding, :manual_hold, :rollback_candidate]
end
