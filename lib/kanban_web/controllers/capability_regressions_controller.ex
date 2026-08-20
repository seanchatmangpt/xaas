defmodule KanbanWeb.CapabilityRegressionsController do
  @moduledoc """
  Real internal self-observability endpoint: HTTP-exposes
  `Xaas.Operations.CapabilityLivenessRegressions.detect/1` (already real,
  tested against real persisted state -- see
  test/xaas/operations/capability_liveness_receipt_test.exs and the
  real property test) so the autonomic loop's "Analyze" step is
  reachable over HTTP, not only from the ingest Mix task.

  Plain JSON (not JSON:API) since the response isn't a resource
  representation -- it's a computed diagnostic over resource history.
  """

  use KanbanWeb, :controller

  def index(conn, _params) do
    regressions = Xaas.Operations.CapabilityLivenessRegressions.detect()

    json(conn, %{
      regressions: Enum.map(regressions, &format/1),
      count: length(regressions)
    })
  end

  defp format(%{capability: capability, was: was, now: now}) do
    %{
      capability: capability,
      was: %{status: was.status, subject: was.subject},
      now: %{status: now.status, subject: now.subject}
    }
  end
end
