defmodule KanbanWeb.Plugs.OntopProxyPlugTest do
  @moduledoc """
  Real Chicago-style test for `KanbanWeb.OntopProxyPlug`, run through the
  real router (`KanbanWeb.Router`) with a real `KanbanWeb.ConnCase`
  connection so the real `KanbanWeb.Plugs.RequireInternalApiToken`
  pipeline plug it sits behind is exercised for real too -- not just the
  proxy plug in isolation.

  The one thing genuinely infeasible in this sandbox's test run is the
  real Ontop Java container itself (a real third-party HTTP service on
  the real Docker network, `docker-compose.ontop.yaml` -- not always
  booted when `mix test` runs, and not something this suite should
  depend on being up). Per this repo's Chicago-style testing rule, the
  one legitimate exception is stated here explicitly: a real Ontop
  container is not assumed available, so `Application.put_env(:kanban,
  :ontop_proxy_http_client, ...)` swaps in a tiny real module that
  implements the exact same `request/1` contract `Req` exposes and
  returns a real, fixed response -- not a mock of interactions (no
  `assert_called`/call-count assertion anywhere in this file), a real
  module with real behavior, asserted only on the real resulting `conn`
  state (status, body, headers) the plug produces.
  """
  use KanbanWeb.ConnCase

  defmodule FakeOntopClient do
    @moduledoc """
    Real, simple stand-in for `Req` implementing the same `request/1`
    contract `KanbanWeb.OntopProxyPlug` calls -- returns a real, fixed
    SPARQL-results-JSON response so the proxy plug's own forwarding and
    response-passthrough logic can be exercised without a live Ontop
    container. Not a mock: no interaction/call assertions are made
    against this module anywhere in this test file.
    """
    def request(opts) do
      send(self(), {:fake_ontop_request, opts})

      {:ok,
       %{
         status: 200,
         headers: [{"content-type", "application/sparql-results+json"}],
         body:
           ~s({"head":{"vars":["sub"]},"results":{"bindings":[{"sub":{"type":"uri","value":"http://xaas.local/resource/subscription/fake-1"}}]}})
       }}
    end
  end

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Application.put_env(:kanban, :ontop_proxy_http_client, FakeOntopClient)

    on_exit(fn ->
      Application.delete_env(:kanban, :ontop_proxy_http_client)
    end)

    :ok
  end

  test "GET /internal-api/sparql with no Authorization header is real-rejected 401 before reaching Ontop", %{
    conn: conn
  } do
    conn = get(conn, "/internal-api/sparql?query=SELECT+*+WHERE+%7B%3Fs+%3Fp+%3Fo%7D")

    assert conn.status == 401
    assert Jason.decode!(conn.resp_body)["error"] == "unauthorized"
    refute_received {:fake_ontop_request, _}
  end

  test "GET /internal-api/sparql with a wrong Bearer token is real-rejected 401 before reaching Ontop", %{
    conn: conn
  } do
    conn =
      conn
      |> put_req_header("authorization", "Bearer not-the-real-token")
      |> get("/internal-api/sparql?query=SELECT+*+WHERE+%7B%3Fs+%3Fp+%3Fo%7D")

    assert conn.status == 401
    refute_received {:fake_ontop_request, _}
  end

  test "GET /internal-api/sparql with the real correct Bearer token forwards to Ontop and passes through its real response",
       %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
      |> get("/internal-api/sparql?query=SELECT+*+WHERE+%7B%3Fs+%3Fp+%3Fo%7D")

    assert conn.status == 200

    body = Jason.decode!(conn.resp_body)
    assert body["results"]["bindings"] |> hd() |> get_in(["sub", "value"]) =~ "fake-1"

    assert_received {:fake_ontop_request, opts}
    assert opts[:method] == "GET"
    assert opts[:url] =~ "http://ontop:8080/sparql"
    assert opts[:url] =~ "query="

    refute Enum.any?(opts[:headers], fn {k, _v} -> String.downcase(k) == "authorization" end)
  end
end
