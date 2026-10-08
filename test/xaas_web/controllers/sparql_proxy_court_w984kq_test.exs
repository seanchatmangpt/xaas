defmodule XaasWeb.SparqlProxyCourtW984kqTest do
  @moduledoc """
  W984kq unclaimed-family probe court for the SPARQL proxy surface
  (`XaasWeb.OntopProxyPlug`, mounted at `/internal-api/sparql` via
  `forward/2` in `lib/xaas_web/router.ex:268`).

  Census disposition of `XaasWeb.OntopProxyPlug.call/2` branches against
  the pre-existing courts (`test/xaas_web/ontop_proxy_deepening_test.exs`,
  `test/xaas_web/plugs/ontop_proxy_plug_test.exs`):

  | branch | disposition |
  |---|---|
  | query-string-present (`"?" <> qs`) | COVERED (deepening (a)) |
  | header strip: authorization/host/content-length | COVERED (deepening (a) auth-strip; content-length never observable downstream — Bandit re-frames the request) |
  | `{:ok, resp}` 200 relay verbatim | COVERED (deepening (a)) |
  | `{:error, reason}` -> 502 `ontop_unreachable`, halted | COVERED (deepening (b), real connection-refused) |
  | 4xx/5xx passthrough, not halted | COVERED (deepening (c)) |
  | 401 auth floor before plug | COVERED (deepening (d)) |
  | raw-body preference (`assigns[:raw_body]`) | COVERED (deepening (f), incl. multipart pinned gap) |
  | method verbatim, no allow-list | COVERED (deepening (e), typed gap disclosed) |
  | **empty query-string branch** (`qs == ""`) | UNCOVERED -> courted here (T1) |
  | **`read_body` `{:more, ...}` accumulation** | UNCOVERED -> courted here (T2) |
  | **upstream hop-by-hop header strip** (`transfer-encoding`/`connection`) | UNCOVERED -> courted here (T3) |
  | defensive `path_info` fallback (`"/sparql"`) | UNCOVERED via router (dead: `forward/2` preserves the full `path_info`, so the `["internal-api","sparql" | rest]` clause always matches; reachable only at plug level) -> courted here at plug level (T4) |
  | `encode_body` non-binary clause | UNREACHABLE through `Req`'s public contract (a `Req.request/1` body is a binary) — typed, no filler test |

  Chicago-style: a real Bandit HTTP receiver on a real OS-assigned
  ephemeral port stands in for the third-party Ontop Java container (same
  stated exception as `test/xaas_web/ontop_proxy_deepening_test.exs` --
  the real container is not assumed to be running). Real ConnCase
  dispatch through the real router; no mocks, no interaction-only
  assertions; every assertion is on real bytes or real conn state.
  """

  use XaasWeb.ConnCase, async: false

  @receiver :sparql_proxy_court_w984kq_receiver

  defmodule ReceiverPlug do
    @moduledoc false
    import Plug.Conn

    def init(opts), do: opts

    def call(conn, _opts) do
      {body, conn} = read_all(conn)

      send(
        :sparql_proxy_court_w984kq_receiver,
        {:ontop_receiver_saw, %{method: conn.method, path: conn.path_info,
         query_string: conn.query_string, body: body}}
      )

      {status, resp_body, extra_headers} =
        case Application.get_env(:xaas, :sparql_court_receiver_response) do
          nil ->
            {200, ~s({"ok":true}), []}

          {status, resp_body, extra_headers} ->
            {status, resp_body, extra_headers}
        end

      conn =
        Enum.reduce(extra_headers, conn, fn {k, v}, acc ->
          put_resp_header(acc, k, v)
        end)

      conn
      |> put_resp_content_type("application/sparql-results+json")
      |> send_resp(status, resp_body)
    end

    # the receiver must itself accumulate {:more, _, _} chunks (same
    # contract the proxy plug implements) -- Bandit chunks large bodies
    defp read_all(conn, acc \\ "") do
      case Plug.Conn.read_body(conn) do
        {:ok, body, conn} -> {acc <> body, conn}
        {:more, body, conn} -> read_all(conn, acc <> body)
      end
    end
  end

  defmodule FakeHopByHopClient do
    @moduledoc """
    Real module implementing the same `request/1` contract `Req` exposes
    (the exact seam `config :xaas, :ontop_proxy_http_client` documents and
    the existing `test/xaas_web/plugs/ontop_proxy_plug_test.exs` uses),
    returning a response that carries hop-by-hop headers. Needed because a
    real Bandit receiver cannot emit `transfer-encoding`/`connection` on a
    response -- Bandit owns HTTP framing and rejects the plug-set header.
    Not a mock: no interaction/call assertions; asserted state is the real
    resulting conn headers. Real-module exception stated per Chicago rule.
    """
    def request(_opts) do
      {:ok,
       %{
         status: 200,
         headers: [
           {"transfer-encoding", "chunked"},
           {"connection", "close"},
           {"x-ontop-node", "ontop-1"},
           {"content-type", "application/sparql-results+json"}
         ],
         body: ~s({"ok":true})
       }}
    end
  end

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Process.register(self(), @receiver)

    {:ok, server_pid} = Bandit.start_link(plug: ReceiverPlug, port: 0, ip: {127, 0, 0, 1})
    Process.unlink(server_pid)
    {:ok, {_address, port}} = ThousandIsland.listener_info(server_pid)

    previous_url = Application.get_env(:xaas, :ontop_base_url)
    Application.put_env(:xaas, :ontop_base_url, "http://127.0.0.1:#{port}")

    on_exit(fn ->
      if previous_url do
        Application.put_env(:xaas, :ontop_base_url, previous_url)
      else
        Application.delete_env(:xaas, :ontop_base_url)
      end

      Application.delete_env(:xaas, :sparql_court_receiver_response)

      if Process.alive?(server_pid), do: Process.exit(server_pid, :shutdown)
    end)

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  defp authed(conn),
    do: put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))

  defp drain_receiver do
    receive do
      {:ontop_receiver_saw, _} -> drain_receiver()
    after
      0 -> :ok
    end
  end

  # ---------------------------------------------------------------------------
  # T1: empty query-string branch (line: `if conn.query_string == ""`)
  # Mutation rationale: if the plug appended "?" unconditionally (or the
  # empty branch were deleted to `"" <> "?"`), the upstream query_string
  # becomes "?" instead of "" -- this assert is the falsifier.
  # ---------------------------------------------------------------------------

  test "T1: GET with no query string forwards upstream with a truly empty query_string (no dangling '?')", %{
    conn: conn
  } do
    drain_receiver()

    conn = conn |> authed() |> get("/internal-api/sparql")

    assert conn.status == 200

    assert_receive {:ontop_receiver_saw, seen}
    assert seen.path == ["sparql"]
    assert seen.query_string == ""
  end

  # ---------------------------------------------------------------------------
  # T2: read_body {:more, body, conn} accumulation clause (chunked / large
  # application/sparql-query POST: Plug.Parsers does not match
  # application/sparql-query, so no raw_body cache exists and the proxy
  # must read the body itself; > 8MB forces the {:more, ...} recursion).
  # Mutation rationale: collapsing the recursion (e.g. matching only
  # {:ok, body, conn}) would truncate the forwarded body at the first 8MB
  # chunk and fail `seen.body == body`; crashing on {:more} fails the test
  # outright. Either way the branch removal is observed on real bytes.
  # ---------------------------------------------------------------------------

  test "T2: large application/sparql-query POST exceeding the first read_body chunk arrives upstream byte-complete", %{
    conn: conn
  } do
    drain_receiver()

    # > Plug.Parsers'/read_body's default 8_000_000-byte length so the
    # first read returns {:more, _, _} and the accumulation clause runs.
    big_tail = String.duplicate("x", 8_000_000 + 1024)
    body = "SELECT * WHERE { ?s ?p " <> big_tail <> " }"

    conn =
      conn
      |> authed()
      |> put_req_header("content-type", "application/sparql-query")
      |> post("/internal-api/sparql", body)

    assert conn.status == 200

    assert_receive {:ontop_receiver_saw, seen}
    assert seen.method == "POST"
    # byte-complete: the full >8MB body, not the first 8MB chunk
    assert seen.body == body
  end

  # ---------------------------------------------------------------------------
  # T3: upstream response hop-by-hop header stripping (the
  # `String.downcase(k) in ["transfer-encoding", "connection"]` reject
  # inside the Enum.reduce over resp_headers).
  # Mutation rationale: deleting either name from the reject list would
  # put the hop-by-hop header on the client conn, failing the refute;
  # deleting the whole strip would also fail the custom-header assert's
  # complement.
  # ---------------------------------------------------------------------------

  test "T3: upstream connection/transfer-encoding headers are stripped, other upstream headers are relayed", %{
    conn: conn
  } do
    drain_receiver()

    # Real Bandit receivers cannot emit hop-by-hop response headers
    # (Bandit owns framing and rejects them), so this test goes through
    # the plug's documented `ontop_proxy_http_client` seam with the real
    # FakeHopByHopClient module above (same idiom as
    # test/xaas_web/plugs/ontop_proxy_plug_test.exs).
    Application.put_env(:xaas, :ontop_proxy_http_client, FakeHopByHopClient)

    conn = conn |> authed() |> get("/internal-api/sparql?query=ASK%20%7B%7D")

    assert conn.status == 200
    assert get_resp_header(conn, "x-ontop-node") == ["ontop-1"]
    assert get_resp_header(conn, "transfer-encoding") == []
    assert get_resp_header(conn, "connection") == []
    assert conn.resp_body == ~s({"ok":true})

    on_exit(fn -> Application.delete_env(:xaas, :ontop_proxy_http_client) end)
  end

  # ---------------------------------------------------------------------------
  # T4: defensive path_info fallback (`_ -> "/sparql"`), reachable only at
  # plug level because the router's forward/2 preserves the full path_info.
  # Mutation rationale: mangling the fallback (e.g. to "" or dropping the
  # join) sends the upstream request to a different path and the receiver
  # observes the wrong path/404s.
  # ---------------------------------------------------------------------------

  test "T4: plug-level call with a non-sparql path_info falls back to the /sparql upstream path", %{
    conn: conn
  } do
    drain_receiver()

    # Direct plug dispatch, as a pipeline mounting this plug outside
    # /internal-api/sparql would produce (the documented
    # `config :xaas, :ontop_base_url` override still applies).
    conn =
      conn
      |> authed()
      |> Map.put(:path_info, ["other", "place"])
      |> XaasWeb.OntopProxyPlug.call([])

    assert conn.status == 200

    assert_receive {:ontop_receiver_saw, seen}
    assert seen.path == ["sparql"]
    refute seen.path == ["other", "place"]
  end
end
