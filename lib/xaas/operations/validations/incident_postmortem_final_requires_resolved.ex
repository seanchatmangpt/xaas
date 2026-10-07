defmodule Xaas.Operations.Validations.IncidentPostmortemFinalRequiresResolved do
  @moduledoc """
  Real lifecycle guard for `Xaas.Operations.Incident`'s `:update` action
  (lane W902 batch 3, v26.10.6, closing W793's
  `GAP(NO_POSTMORTEM_STATUS_GUARD)`): a postmortem may be marked `:final`
  only on a `:resolved` incident. `:final` postmortem on an `:open`
  incident is the exact state W793 observed live -- a closed-out
  postmortem for an incident that never resolved.

  Other postmortem transitions (e.g. `:draft` annotation while `:open`)
  stay allowed: the gap W793 pinned is specifically the `:final`
  close-out, and gating only it keeps annotation-on-open legal.
  """

  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    new_status = final_status(changeset)

    postmortem_status = Ash.Changeset.get_attribute(changeset, :postmortem_status)

    if postmortem_status == :final and new_status != :resolved do
      {:error, field: :postmortem_status,
       message:
         "postmortem_status cannot be :final while the incident is not :resolved " <>
           "(status: #{inspect(new_status)}) -- resolve the incident before finalizing its postmortem"}
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
