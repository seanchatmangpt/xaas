defmodule XaasWeb.ProvOriginHeaderTest do
  @moduledoc """
  W605 court: PROV-O artificial-origin provenance header is live on the
  real public machine surfaces. Chicago-style — real endpoint pipeline
  (`XaasWeb.Endpoint` -> `XaasWeb.Router`), real responses, no mocks.

  Courts:
    1. `/a2a` transport responses carry the exact `x-prov-o` header shape.
    2. `/api` (forward to `XaasWeb.ApiRouter`) responses carry it too.
    3. The values are constant/config-driven: identical across requests.
    4. Precision pin: a non-wired surface (`/`, `:browser` pipeline) does
       NOT carry the header.
  """

  use XaasWeb.ConnCase

  @header "x-prov-o"
  @expected ~s(wasGeneratedBy=<https://w3id.org/xaas/agent/xaas-platform>) <>
              ~s(; actedOnBehalfOf=<https://w3id.org/xaas/operator/xaas-operators>)

  test "1. /a2a transport response carries the exact PROV-O header shape" do
    conn =
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> post("/a2a/v1", Jason.encode!(%{"jsonrpc" => "2.0", "method" => "tools/list", "id" => "w605-1"}))

    # The auth floor is not this court's subject; the token-floor refusal
    # envelope must still be provenance-marked (:prov_origin is first in
    # the scope's pipe_through, so its before_send survives the halt).
    assert conn.status in [200, 401]
    assert {@header, @expected} in conn.resp_headers
  end

  test "2. /api surface response carries the exact PROV-O header shape" do
    conn =
      build_conn()
      |> put_req_header("accept", "application/json")
      |> get("/api/xaas_library_books")

    assert conn.status in [200, 401]
    assert {@header, @expected} in conn.resp_headers
  end

  test "3. values are constant (config-driven application identity, not per-request)" do
    conns =
      for id <- ["a", "b", "c"] do
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> post("/a2a/v1", Jason.encode!(%{"jsonrpc" => "2.0", "method" => "tools/list", "id" => id}))
      end

    values =
      Enum.map(conns, fn conn ->
        assert conn.status in [200, 401]
        {"x-prov-o", v} = List.keyfind(conn.resp_headers, "x-prov-o", 0)
        v
      end)

    assert Enum.uniq(values) == [@expected]
  end

  test "4. precision pin: non-wired surface (/) does NOT carry the header" do
    conn = get(build_conn(), "/")

    assert conn.status == 200
    refute List.keyfind(conn.resp_headers, "x-prov-o", 0)
  end

  test "5. mutation witness: the plug itself attaches the exact value" do
    # Plug-level court that isolates the unit under mutation — dropping the
    # plug from the router makes courts 1-2 RED; this one fails if the plug
    # module itself stops attaching the header at all.
    conn =
      Plug.Test.conn(:get, "/api/anything")
      |> XaasWeb.Plugs.ProvOriginHeader.call([])
      |> Plug.Conn.send_resp(200, "ok")

    assert {@header, @expected} in conn.resp_headers
  end
end
