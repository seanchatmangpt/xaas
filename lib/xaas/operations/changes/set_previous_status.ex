defmodule Xaas.Operations.Changes.SetPreviousStatus do
  @moduledoc """
  W968c / SPEC-14 (W750-G2): body of the `:ingest` upsert path on
  `Xaas.Operations.CapabilityLivenessReceipt`. Before the identity upsert
  overwrites a `(capability, subject)` row in place, capture that row's
  current `status` into `previous_status`, so the regression detector
  (`CapabilityLivenessRegressions.detect/1`) can see an in-place
  ALIVE->non-ALIVE flip that the overwrite would otherwise destroy.

  `previous_status` is deliberately NOT in the `:ingest` accept list, so a
  caller cannot forge it; the only writer is this change, reading the real
  row from the real tables.
  """

  use Ash.Resource.Change
  require Ash.Query

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, &capture_previous_status/1)
  end

  defp capture_previous_status(changeset) do
    capability = Ash.Changeset.get_argument_or_attribute(changeset, :capability)
    subject = Ash.Changeset.get_argument_or_attribute(changeset, :subject)

    existing =
      Xaas.Operations.CapabilityLivenessReceipt
      |> Ash.Query.filter(capability == ^capability and subject == ^subject)
      |> Ash.read_one!(authorize?: false)

    case existing do
      nil -> changeset
      %{status: prior} -> Ash.Changeset.change_attribute(changeset, :previous_status, prior)
    end
  end
end
