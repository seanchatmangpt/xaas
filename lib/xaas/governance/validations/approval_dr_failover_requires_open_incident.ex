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
  """
  use Ash.Resource.Validation

  require Ash.Query

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    from_region = Ash.Changeset.get_attribute(changeset, :from_region)

    query =
      Xaas.Operations.Incident
      |> Ash.Query.filter(region == ^from_region and status == "open")

    case Ash.read(query, authorize?: false) do
      {:ok, [_ | _]} ->
        :ok

      {:ok, []} ->
        {:error,
         field: :from_region,
         message:
           "requires an open Xaas.Operations.Incident referencing this region before failover can be approved"}

      {:error, error} ->
        {:error, field: :from_region, message: "could not verify open incident: #{inspect(error)}"}
    end
  end
end
