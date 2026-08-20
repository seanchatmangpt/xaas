defmodule KanbanWeb.InternalApiRouterTest do
  @moduledoc """
  Real Chicago-style test for the real AshJsonApi.Router forward
  (lib/kanban_web/internal_api_router.ex, mounted at /internal-api in
  KanbanWeb.Router) -- the one internal-api route not covered by a
  Phoenix-controller-level test, since it's generated entirely by
  AshJsonApi.Resource's `json_api do routes do ... end end` DSL, not
  hand-written controller code. Real ConnCase HTTP request, real
  Ash.create! row in the real sandboxed Postgres, asserts on the real
  decoded JSON:API response body.
  """
  use KanbanWeb.ConnCase

  alias Xaas.Operations.CapabilityLivenessReceipt

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  test "GET /internal-api/capability_liveness_receipts rejects a real incompatible Accept header", %{conn: conn} do
    # Real Phoenix `:accepts` behavior (confirmed via 2 real failed
    # assertions before this fix): with NO Accept header, the pipeline
    # defaults to its first configured type ("json-api") rather than
    # rejecting; with an explicit, incompatible header, `:accepts` raises
    # a real Phoenix.NotAcceptableError (via Phoenix.Controller.refuse/3)
    # rather than returning a 406 conn -- assert the real raise.
    assert_raise Phoenix.NotAcceptableError, fn ->
      conn
      |> put_req_header("accept", "text/plain")
      |> get("/internal-api/capability_liveness_receipts")
    end
  end

  test "GET /internal-api/capability_liveness_receipts returns real ingested rows as real JSON:API", %{conn: conn} do
    capability = "internal-api-router-test-#{System.unique_integer([:positive])}"

    CapabilityLivenessReceipt
    |> Ash.Changeset.for_create(:ingest, %{
      capability: capability,
      authority: "SELECT",
      status: "ALIVE",
      subject: "git:internal-api-router-test",
      detail: "real row for internal_api_router_test"
    })
    |> Ash.create!(authorize?: false)

    conn =
      conn
      |> put_req_header("accept", "application/vnd.api+json")
      |> get("/internal-api/capability_liveness_receipts?filter[capability]=#{capability}")

    body = json_response(conn, 200)

    assert [row] = body["data"]
    assert row["type"] == "capability_liveness_receipts"
    assert row["attributes"]["capability"] == capability
    assert row["attributes"]["status"] == "ALIVE"
    assert row["attributes"]["subject"] == "git:internal-api-router-test"
  end
end
