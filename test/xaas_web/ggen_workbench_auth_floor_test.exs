defmodule XaasWeb.GgenWorkbenchAuthFloorTest do
  @moduledoc """
  W150 (W113 finding 1): on the ggen-workbench scope the auth floor must
  precede content negotiation, so a no-token probe answers a typed 401 (or
  503 fail-closed), never a 406 that leaks the accepted content types.
  """

  use XaasWeb.ConnCase

  test "GET /api/workbench/ggen/health without a token fails closed at the token floor (not 406)" do
    conn =
      build_conn()
      |> get("/api/workbench/ggen/health")

    assert conn.status in [401, 503]
    refute conn.status == 406
  end

  test "POST /api/workbench/ggen without a token fails closed at the token floor (not 406)" do
    conn =
      build_conn()
      |> post("/api/workbench/ggen", %{})

    assert conn.status in [401, 503]
    refute conn.status == 406
  end

  test "POST /api/workbench/ggen without a token and with Accept: application/json fails closed at the token floor (not 406)" do
    conn =
      build_conn()
      |> put_req_header("accept", "application/json")
      |> post("/api/workbench/ggen", %{})

    assert conn.status in [401, 503]
    refute conn.status == 406
  end

  # W299c: GET on the POST-only /ggen route matches nothing in the
  # /api/workbench scope and falls through to the /api forward (InternalApi
  # stack), whose :internal_api pipeline carried plug(:accepts, ["json-api"])
  # BEFORE the token floor -- a tokenless GET with Accept: application/json
  # was answered 406 by content negotiation before any auth check.
  test "GET /api/workbench/ggen (no such route) without a token and with Accept: application/json fails closed at the token floor (not 406)" do
    conn =
      build_conn()
      |> put_req_header("accept", "application/json")
      |> get("/api/workbench/ggen")

    assert conn.status in [401, 503]
    refute conn.status == 406
  end
end
