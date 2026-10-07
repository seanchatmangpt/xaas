defmodule Xaas.Governance.Validations.AuditExportTokenNoActiveFreezeWindow do
  @moduledoc """
  Real business rule for `Xaas.Governance.AuditExportToken`'s `:issue`
  action (lane W801, closing the W765 GAP-D disclosure): while an org has
  an active `Xaas.Governance.FreezeWindow` (`starts_at <= now <= ends_at`),
  new audit-export bearer credentials are refused for that org.

  Scope discipline (deliberate, per the W801 work order): this is the
  minimal honest enforcement the documentation implies -- the resource
  most adjacent to the audit-export governance pair -- NOT a global
  freeze interceptor across the platform. Other freeze-sensitive paths
  (`ApprovalEnvironmentPromote`'s documented platform-console
  checkFreezeGuard analogue) remain unwired; that is a design change
  beyond this repair and stays disclosed as such.

  Real, `authorize?: false` cross-resource read, mirroring the
  established pattern in
  `Xaas.Governance.Validations.ApprovalFreezeOverrideFreezeWindowExists`
  (a real read against a related resource inside a validation context,
  same fail-closed discipline: a read error denies rather than passes).

  Deliberately scoped to `:issue` only -- `:revoke` must stay available
  during a freeze (killing credentials is not what a change-freeze
  governs), and `:read`/`:revoke` never mint anything.
  """
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    org_id = Ash.Changeset.get_attribute(changeset, :org_id)

    case org_id do
      nil ->
        # allow_nil? false on the attribute itself already covers absence.
        :ok

      _ ->
        check_active_freeze_window(org_id)
    end
  end

  defp check_active_freeze_window(org_id) do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    freeze_windows =
      Xaas.Governance.FreezeWindow
      |> Ash.Query.filter(org_id == ^org_id and starts_at <= ^now and ends_at >= ^now)
      |> Ash.read(authorize?: false)

    case freeze_windows do
      {:ok, []} ->
        :ok

      {:ok, [window | _]} ->
        {:error,
         field: :org_id,
         message:
           "is in an active change-freeze window (#{window.id}, ends_at #{DateTime.to_iso8601(window.ends_at)}); " <>
             "new audit export tokens are refused until the window ends or an emergency override is granted"}

      {:error, _} ->
        # fail closed: an unresolvable freeze-window check denies the mint
        {:error,
         field: :org_id,
         message: "could not be checked against active change-freeze windows; refusing"}
    end
  end
end
