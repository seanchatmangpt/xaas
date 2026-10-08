defmodule XaasWeb.Plugs.FamilyCourtW984gfTest do
  @moduledoc """
  W984gf unclaimed-family probe court — `lib/xaas_web/plugs/`.

  Census result: 10 of 11 plugs already carry direct or strong indirect
  courts (RequireInternalApiToken excluded per lane charter). The one
  uncovered state-bearing module is `XaasWeb.Plugs.A2AParseFloor` (W150):
  its malformed-JSON (`4b`) and happy paths are exercised through
  `test/xaas_web/a2a/v1_protocol_test.exs`, but three branches are genuinely
  unexercised end to end:

    1. valid JSON that is NOT an object (array / scalar) — the
       `{:ok, _non_map}` clause must pre-fill `body_params` with `%{}`
       (NOT answer -32700) and let the pinned dep classify -32600;
    2. the `{:more}` oversized-body clause — must answer -32700 with the
       "Body too large" detail suffix;
    3. the detail-suffix message branch of `parse_error/2` reached by (2).

  Chicago-style: real endpoint pipeline (`XaasWeb.Endpoint` ->
  `XaasWeb.Router` -> `/a2a` scope -> `AshA2A.Protocol.Plug`), real token
  floor, real Jason decode; zero mocks. Mutation rationale per test inline.
  """

  use XaasWeb.ConnCase

  @rpc_path "/a2a/v1"

  defp token, do: System.fetch_env!("INTERNAL_API_TOKEN")
  defp authed(conn), do: put_req_header(conn, "authorization", "Bearer " <> token())

  test "1. valid JSON array body is NOT a parse error — dep classifies -32600 (W150 non-map branch)" do
    # Mutation rationale: flipping the `{:ok, _non_map}` clause to answer
    # parse_error/0 would turn this into a -32700 envelope; routing the
    # branch to passthrough (mark_fetched never runs) would leave the body
    # unfetched and the response shape uncontrolled. The court pins both:
    # HTTP 200 + typed -32600 invalid-request from the pinned dep.
    conn =
      build_conn()
      |> authed()
      |> put_req_header("content-type", "application/json")
      |> post(@rpc_path, "[1, 2, 3]")

    assert conn.status == 200

    assert %{
             "jsonrpc" => "2.0",
             "error" => %{"code" => -32600, "message" => message}
           } = json_response(conn, 200)

    assert is_binary(message) and message != ""
  end

  test "2. valid JSON scalar body (string) is likewise delegated, not -32700" do
    # Mutation rationale: same clause as case 1, different non-map shape —
    # a scalar exercises the `is_map(decoded)` guard failing on a non-list
    # non-object term; a regression that special-cases arrays only would
    # pass case 1 and fail here.
    conn =
      build_conn()
      |> authed()
      |> put_req_header("content-type", "application/json")
      |> post(@rpc_path, ~s("just a string"))

    assert conn.status == 200

    assert %{
             "jsonrpc" => "2.0",
             "error" => %{"code" => -32600, "message" => message}
           } = json_response(conn, 200)

    assert is_binary(message) and message != ""
  end

  test "3. oversized POST body (>8MB read length) answers -32700 with 'Body too large' detail" do
    # Mutation rationale: deleting the `{:more}` clause of read_body/1
    # makes the oversized case raise CaseClauseError (500, no envelope);
    # silently passing through would feed a partial body to Plug.Parsers.
    # The court pins the halt-with-detail branch, and case 4 pins the
    # detail-suffix composition in parse_error/2 it feeds.
    oversized = String.duplicate("x", 8_000_001)

    conn =
      build_conn()
      |> authed()
      |> put_req_header("content-type", "application/json")
      |> post(@rpc_path, oversized)

    assert conn.status == 200

    assert %{
             "jsonrpc" => "2.0",
             "id" => nil,
             "error" => %{"code" => -32700, "message" => "Invalid JSON payload: Body too large"}
           } = json_response(conn, 200)
  end

  test "4. parse floor does not intercept non-/a2a POSTs — malformed JSON there stays a bare parser 400" do
    # Mutation rationale: widening the plug's path guard (e.g. matching any
    # POST with a JSON content-type) would convert this bare 400 into the
    # parse-floor's HTTP-200 -32700 envelope; the court pins the
    # non-/a2a passthrough so the guard stays scoped to the AI surface.
    # In the test dispatch, Plug.Parsers.ParseError propagates out of the
    # endpoint unwrapped (the exception itself names Plug.Parsers, not the
    # parse floor), which pins that the floor never intercepted.
    assert_raise Plug.Parsers.ParseError, ~r/Jason.DecodeError/, fn ->
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> post("/api/xaas_library_books", "this is { not json")
    end
  end
end
