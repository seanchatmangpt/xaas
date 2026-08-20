defmodule KanbanWeb.CapabilityRegressionsControllerTest do
  @moduledoc """
  Real Chicago-style test: real Phoenix ConnCase HTTP request against the
  real endpoint, real Ash.create! rows in the real sandboxed Postgres
  (Xaas.Repo), asserting on the real decoded JSON response body -- no
  mocking of CapabilityLivenessRegressions or the DB.
  """
  use KanbanWeb.ConnCase

  alias Xaas.Operations.CapabilityLivenessReceipt

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  test "GET /internal-api/capability_liveness_regressions returns real, empty regressions when none exist", %{conn: conn} do
    conn = get(conn, "/internal-api/capability_liveness_regressions")

    assert %{"count" => 0, "regressions" => []} = json_response(conn, 200)
  end

  test "GET /internal-api/capability_liveness_regressions surfaces a real detected regression", %{conn: conn} do
    capability = "regress-controller-test-#{System.unique_integer([:positive])}"

    CapabilityLivenessReceipt
    |> Ash.Changeset.for_create(:ingest, %{
      capability: capability,
      authority: "SELECT",
      status: "ALIVE",
      subject: "git:before",
      detail: "real prior alive run"
    })
    |> Ash.create!(authorize?: false)

    # Real, distinct inserted_at ordering -- Postgres timestamp resolution.
    Process.sleep(5)

    CapabilityLivenessReceipt
    |> Ash.Changeset.for_create(:ingest, %{
      capability: capability,
      authority: "SELECT",
      status: "BUILD_BROKEN",
      subject: "git:after",
      detail: "real regressed run"
    })
    |> Ash.create!(authorize?: false)

    conn = get(conn, "/internal-api/capability_liveness_regressions")
    body = json_response(conn, 200)

    assert body["count"] >= 1
    assert Enum.any?(body["regressions"], fn r ->
             r["capability"] == capability and
               r["was"]["status"] == "ALIVE" and
               r["now"]["status"] == "BUILD_BROKEN"
           end)
  end
end
