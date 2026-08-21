defmodule Xaas.Governance.Validations.ApprovalDrFailoverRequiresOpenIncident do
  @moduledoc """
  Real enforcement of platform-console's own additional runtime
  precondition on `POST /api/dr/initiate-failover` (see
  `~/chatman-ecosystem/platform-console`): a DR failover may not be
  approved unless an open incident referencing the same `from_region`
  exists.

  `Xaas.Governance.ApprovalDrFailover`'s moduledoc previously disclosed
  this as a real, honest gap -- ported everything else from
  platform-console's maker-checker flow but not this check, because xaas
  had no `Incident` resource to query. `Xaas.Operations.Incident` is now
  that resource; this validation is the real query against it, run on
  `ApprovalDrFailover`'s `:approve` action.

  ## Real fix (seventeenth pass) -- the query had no `org_id` filter,
  enabling a real cross-org escalation

  Real, live-HTTP-proven gap found by the seventeenth-pass ERRC grid
  sweep: this query previously filtered only on `region == ^from_region
  and status == "open"`, with no `org_id` check at all. Combined with
  `Xaas.Operations.Incident`'s own then-bare `authorize_if(always())`
  bypass (see that resource's moduledoc), any actor could fabricate an
  `Incident` under a completely invented, never-authenticated `org_id`
  and satisfy this precondition for a REAL, unrelated victim org's
  `ApprovalDrFailover:approve` -- itself already correctly org-scoped via
  `Xaas.Governance.Checks.ActorOrgMatches`. A real, temporary
  (deleted-after-run) HTTP test proved this live: a real victim-org DR
  failover was approved (`HTTP 200`, real `EnqueueWebhookDeliveries`/
  `WriteAuditLogEntry` effects fired) on the strength of a fabricated,
  attacker-controlled incident with zero real relationship to that org.

  The fix adds `org_id == ^target_org_id` to the query, reading the
  target org off the changeset's own record (`ApprovalDrFailover`'s
  persisted `org_id`, not accepted on `:approve` so never a pending
  change) -- the same `resolve_org_id/1` pattern
  `Xaas.Governance.Checks.ActorOrgMatches` and its Billing/Operations
  siblings already use for reading a non-`:create` action's real org.
  """
  use Ash.Resource.Validation

  require Ash.Query

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    from_region = Ash.Changeset.get_attribute(changeset, :from_region)
    org_id = resolve_org_id(changeset)

    query =
      Xaas.Operations.Incident
      |> Ash.Query.filter(region == ^from_region and status == "open" and org_id == ^org_id)

    case Ash.read(query, authorize?: false) do
      {:ok, [_ | _]} ->
        :ok

      {:ok, []} ->
        {:error,
         field: :from_region,
         message:
           "requires an open Xaas.Operations.Incident referencing this region AND this org before failover can be approved"}

      {:error, error} ->
        {:error, field: :from_region, message: "could not verify open incident: #{inspect(error)}"}
    end
  end

  # :approve is an :update action and org_id is not in its accept list,
  # so it is never a pending change -- the real fact to check is the
  # existing persisted ApprovalDrFailover record's own org_id.
  defp resolve_org_id(%Ash.Changeset{data: %{org_id: org_id}}), do: org_id
  defp resolve_org_id(_), do: nil
end
