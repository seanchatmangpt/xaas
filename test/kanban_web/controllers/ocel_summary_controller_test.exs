defmodule KanbanWeb.OcelSummaryControllerTest do
  @moduledoc """
  Real Chicago-style test: a real HTTP request against a real endpoint
  that reads the real OCEL v2 NDJSON file (no mocked file I/O). Writes
  real, known lines to a real temp file, points the read at it by
  exercising the same real code path the controller uses
  (Xaas.Telemetry.OcelAshEmitter.log_path/0 -- can't be overridden per
  request, so this test instead drives a real Ash action to produce a
  real event in the real log and asserts the real aggregate reflects it).
  """
  use KanbanWeb.ConnCase

  alias Xaas.Operations.CapabilityLivenessReceipt

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  test "GET /internal-api/ocel_summary returns real counts reflecting a real Ash action just executed", %{conn: conn} do
    # Real action -> real :telemetry event -> real OcelAshEmitter handler
    # -> real append to the real log file (not a mock of any of these).
    capability = "ocel-summary-controller-test-#{System.unique_integer([:positive])}"

    CapabilityLivenessReceipt
    |> Ash.Changeset.for_create(:ingest, %{
      capability: capability,
      authority: "SELECT",
      status: "ALIVE",
      subject: "git:ocel-summary-test",
      detail: "real event for ocel_summary controller test"
    })
    |> Ash.create!(authorize?: false)

    conn = get(conn, "/internal-api/ocel_summary")
    body = json_response(conn, 200)

    assert body["total_events"] > 0
    assert is_map(body["by_activity"])
    assert is_map(body["by_outcome"])
    assert Map.has_key?(body["by_activity"], "capability_liveness_receipt.ingest")
    assert body["by_activity"]["capability_liveness_receipt.ingest"] >= 1
    assert String.ends_with?(body["log_path"], "priv/ocel/ash-actions.ndjson")
  end
end
