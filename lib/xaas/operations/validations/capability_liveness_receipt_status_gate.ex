defmodule Xaas.Operations.Validations.CapabilityLivenessReceiptStatusGate do
  @moduledoc """
  W768 (G1 from W750's receipt `docs/sjira/v26.10.6/plans/w750-liveness-deepening.md`):
  mechanical enforcement of the doctrine's standing-vocabulary law at
  `Xaas.Operations.CapabilityLivenessReceipt`'s `:ingest` action.

  Two rules, both typed:

  1. `status` must be a member of the standing vocabulary actually consumed
     by this resource's real consumers (the regression detector keys on
     `"ALIVE"` vs non-`"ALIVE"`; the existing liveness suites exercise
     ALIVE / REFUTED / BLOCKED / UNKNOWN / PARTIAL / PARTIAL_ALIVE /
     UNSUPPORTED / BUILD_BROKEN — the doctrine standing vocabulary).
     Anything else (e.g. a fabricated standing string) refuses typed as
     `INVALID_STATUS_VOCABULARY`.
  2. `status == "ALIVE"` requires `executed == true` — a receipt claiming
     ALIVE without observed execution refuses typed as
     `ALIVE_WITHOUT_EXECUTION` ("ALIVE requires observed execution").

  Deliberately NOT a data-layer enum migration: the standing vocabulary is
  enforced at the admission boundary (`:ingest`), leaving already-persisted
  historical rows untouched (read paths and `detect/1` unaffected).

  Follows the house validation-module idiom used by every neighbor in
  `lib/xaas/operations/validations/` (e.g.
  `IncidentResolvedRequiresResolvedAt`): a real `Ash.Resource.Validation`,
  no `atomic/3` (not needed for `:create`), no mocks.
  """

  use Ash.Resource.Validation

  @standing_vocabulary ~w(
    ALIVE
    REFUTED
    BLOCKED
    UNKNOWN
    PARTIAL
    PARTIAL_ALIVE
    UNSUPPORTED
    BUILD_BROKEN
  )

  @impl true
  def validate(changeset, _opts, _context) do
    status = Ash.Changeset.get_argument_or_attribute(changeset, :status)
    executed = Ash.Changeset.get_argument_or_attribute(changeset, :executed)

    cond do
      status not in @standing_vocabulary ->
        {:error, field: :status, message: "INVALID_STATUS_VOCABULARY: #{inspect(status)}"}

      status == "ALIVE" and executed != true ->
        {:error,
         field: :executed,
         message: "ALIVE_WITHOUT_EXECUTION: status ALIVE requires executed == true"}

      true ->
        :ok
    end
  end
end
