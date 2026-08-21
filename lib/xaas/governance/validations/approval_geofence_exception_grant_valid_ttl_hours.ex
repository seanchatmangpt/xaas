defmodule Xaas.Governance.Validations.ApprovalGeofenceExceptionGrantValidTtlHours do
  @moduledoc """
  Real TTL-range validation, ported verbatim from platform-console's
  `POST /api/owner/geofence-policy` body check:
  `typeof v?.ttlHours === "number" && v.ttlHours > 0 && v.ttlHours <= 168`
  (a bounded-TTL exception can be granted for at most one week).
  """
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :ttl_hours) do
      ttl when is_integer(ttl) and ttl > 0 and ttl <= 168 ->
        :ok

      _ ->
        {:error, field: :ttl_hours, message: "must be greater than 0 and at most 168 (one week)"}
    end
  end
end
