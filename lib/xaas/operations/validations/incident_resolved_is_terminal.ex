defmodule Xaas.Operations.Validations.IncidentResolvedIsTerminal do
  @moduledoc """
  Real lifecycle guard for `Xaas.Operations.Incident`'s `:update` action
  (lane W818, v26.10.6, closing W793's `GAP(NO_REOPEN_GUARD)`): an
  incident whose persisted status is `:resolved` is terminal through
  `:update` -- no silent reopen. Reopening (if it is ever a real product
  need) must be an explicit dedicated action that also clears
  `resolved_at` and re-opens the DR-failover precondition consciously,
  not a bare status flip through the generic annotation action.

  This is exactly the gap W793 observed live: `resolved -> open` was
  permitted through `:update` while retaining the stale `resolved_at`,
  and the reopen re-satisfied
  `Xaas.Governance.Validations.ApprovalDrFailoverRequiresOpenIncident`'s
  precondition query as a real cross-resource side effect. With this
  guard, the stale-`resolved_at` retention W793 pinned dies with the
  reopen path itself.
  """

  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    persisted_status =
      case changeset.data do
        nil -> nil
        data -> data.status
      end

    new_status = Ash.Changeset.get_attribute(changeset, :status)

    if persisted_status == :resolved and new_status != :resolved do
      {:error, field: :status,
       message:
         "is terminal -- reopening a resolved incident requires an explicit reopen action"}
    else
      :ok
    end
  end
end
