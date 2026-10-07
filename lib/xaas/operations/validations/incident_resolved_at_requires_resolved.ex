defmodule Xaas.Operations.Validations.IncidentResolvedAtRequiresResolved do
  @moduledoc """
  Real lifecycle guard for `Xaas.Operations.Incident`'s `:update` action
  (lane W902 batch 3, v26.10.6, closing W793's `GAP(NO_RESOLVED_AT_GUARD)`):
  a `resolved_at` timestamp requires the incident's status to be
  `:resolved`. `resolved_at` while `:open` is the exact state W793
  observed live: a "resolved" timestamp on an incident whose status still
  says open -- a timestamp with no resolution behind it.

  Complement of `Xaas.Operations.Validations.IncidentResolvedRequiresResolvedAt`
  (status `:resolved` requires `resolved_at`), so together the two guards
  make `status == :resolved <=> resolved_at != nil` a real invariant of
  the `:update` surface, and `:create` cannot mint the state at all
  (`:create` does not accept `:resolved_at`).
  """

  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    new_status = final_status(changeset)

    resolved_at =
      case Ash.Changeset.get_attribute(changeset, :resolved_at) do
        nil -> changeset.data && changeset.data.resolved_at
        value -> value
      end

    if resolved_at != nil and new_status == :open do
      {:error, field: :resolved_at,
       message:
         "cannot coexist with status :open -- setting resolved_at requires " <>
           "resolving the incident (status :resolved)"}
    else
      :ok
    end
  end

  defp final_status(changeset) do
    case Ash.Changeset.get_attribute(changeset, :status) do
      nil -> changeset.data && changeset.data.status
      status -> status
    end
  end
end
