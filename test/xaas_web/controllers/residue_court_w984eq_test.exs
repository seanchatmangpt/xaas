defmodule XaasWeb.Controllers.ResidueCourtW984eqTest do
  @moduledoc """
  Lane W984eq unclaimed-family probe: controller-surface residue court.

  Census (module CamelCase grep against test/) classified every
  `lib/xaas_web/controllers/` module; the residue this court pins is the
  set of branches with zero direct or indirect HTTP exercise elsewhere:

  - `XaasWeb.PrometheusQueryController.query/2`'s `missing_query_param`
    clause (`query/2` head-2): no existing test issues a request without
    a `query` param. Mutation rationale: deleting the clause or renaming
    the error atom changes or 500s this response; the court fails.
  - `XaasWeb.PrometheusQueryAllowlist.check/1` subquery branch
    (`expr[range:step]` rejection) — exercised here through the real
    controller HTTP path. Existing tests cover disallowed-metric and
    `[365d]` unbounded-range 400s, never subquery syntax. Mutation
    rationale: removing `reject_subquery/1` from the `with` chain lets
    this request forward to Prometheus (502 on the real closed port)
    instead of the 400 `query_not_allowed` with "subquery syntax" detail.
  - `XaasWeb.ErrorJSON.render/2` and `XaasWeb.ErrorHTML.render/2`: zero
    test files name either module; the 404 JSON and HTML error renders
    are asserted here through the real endpoint (real unmatched-route
    dispatch), plus a direct `ErrorJSON.render/2` call pinning the
    template-name -> status-message mapping.

  Chicago-style: real ConnCase requests through the real router with the
  real `INTERNAL_API_TOKEN` set by test/test_helper.exs, real state,
  zero mocks. Real Prometheus unreachability (closed port) is load
  bearing in the subquery mutation rationale.
  """

  use XaasWeb.ConnCase, async: false

  import Plug.Conn
  import Phoenix.ConnTest

  @endpoint XaasWeb.Endpoint

  defp tokened(conn), do: put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))

  test "p1. GET /internal-api/prometheus/query without a query param returns 400 missing_query_param" do
    # Mutation: delete `def query(conn, _params)` clause ->
    # FunctionClauseError -> 500 instead of this 400 body.
    conn =
      build_conn()
      |> tokened()
      |> get("/internal-api/prometheus/query", %{})

    assert %{"error" => "missing_query_param"} = json_response(conn, 400)
  end

  test "p2. subquery PromQL is 400-rejected with the subquery detail, never forwarded" do
    # Mutation: drop `reject_subquery/1` from the allowlist `with` chain
    # -> allowlist passes -> real HTTP attempt to the unreachable default
    # Prometheus -> 502 prometheus_unreachable instead of this 400.
    conn =
      build_conn()
      |> tokened()
      |> get("/internal-api/prometheus/query", %{"query" => "rate(beam_memory_process_bytes[5m:1m])"})

    resp = json_response(conn, 400)
    assert resp["error"] == "query_not_allowed"
    assert resp["detail"] =~ "subquery syntax"
  end

  test "p3. unmatched plain-JSON route renders ErrorJSON 404 with Not Found detail" do
    # Observed (probe finding): the /internal-api surface renders 404s as
    # JSON:API error objects, not via XaasWeb.ErrorJSON. The plain-JSON
    # workbench scope is where ErrorJSON is the actual renderer.
    # Mutation: any regression in the JSON error render path (view swap,
    # template rename) changes this body.
    conn =
      build_conn()
      |> tokened()
      |> put_req_header("accept", "application/json")
      |> get("/definitely-not-a-route-w984eq")

    assert %{"errors" => %{"detail" => "Not Found"}} = json_response(conn, 404)
  end

  test "p4. unmatched browser route renders ErrorHTML 404" do
    conn = get(build_conn(), "/definitely-not-a-route-w984eq")

    assert conn.status == 404
    assert get_resp_header(conn, "content-type") |> List.first() =~ "text/html"
  end

  test "p5. ErrorJSON.render maps template names to Phoenix status messages" do
    # Mutation: change the render clause to drop
    # status_message_from_template/1 -> detail no longer "Not Found".
    assert %{errors: %{detail: "Not Found"}} = XaasWeb.ErrorJSON.render("404.json", %{})
    assert %{errors: %{detail: "Internal Server Error"}} = XaasWeb.ErrorJSON.render("500.json", %{})
  end
end
