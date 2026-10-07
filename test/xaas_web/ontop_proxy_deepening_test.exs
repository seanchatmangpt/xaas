defmodule XaasWeb.OntopProxyDeepeningTest do
  @moduledoc """
  W776 deepening court for the Ontop SPARQL reverse proxy
  (`XaasWeb.OntopProxyPlug`, mounted at `/internal-api/sparql` in
  `lib/xaas_web/router.ex`).

  Chicago-style, real end to end: a real `XaasWeb.ConnCase` connection
  dispatched through the real router (so the real
  `XaasWeb.Plugs.RequireInternalApiToken` floor it sits behind is
  exercised for real), and a real Bandit HTTP receiver on a real OS-assigned
  ephemeral port standing in for the Ontop endpoint, reached over the real
  network via the `config :xaas, :ontop_base_url` override the plug itself
  documents. No mocks of owned code and no interaction-only assertions:
  every assertion is on real bytes (real query bytes observed by the
  receiver, real response bytes observed on the returned conn).

  The one stated exception, same as the existing
  `test/xaas_web/plugs/ontop_proxy_plug_test.exs`: the real third-party
  Ontop Java container is not assumed to be running, so a real local
  Bandit HTTP server stands in for it. It is a real HTTP server speaking
  real HTTP over a real socket, not a stub of owned code.
  """

  use XaasWeb.ConnCase, async: false

  @query_bytes "SELECT ?s ?p ?o WHERE%20%7B?s ?p ?o%7D%20LIMIT%203"

  # ---------------------------------------------------------------------------
  # Real Bandit receiver standing in for the Ontop endpoint
  # ---------------------------------------------------------------------------

  defmodule ReceiverPlug do
    @moduledoc false
    import Plug.Conn

    def init(opts), do: opts

    def call(conn, _opts) do
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      send(
        :ontop_proxy_deepening_test,
        {:ontop_receiver_saw, %{method: conn.method, path: conn.path_info,
         query_string: conn.query_string, req_headers: conn.req_headers,
         body: body}}
      )

      {status, resp_body, content_type} = receiver_response()

      conn
      |> put_resp_content_type(content_type)
      |> send_resp(status, resp_body)
    end

    defp receiver_response do
      case Application.get_env(:xaas, :ontop_receiver_response) do
        nil ->
          {200,
           ~s({"head":{"vars":["s"]},"results":{"bindings":[{"s":{"type":"uri","value":"http://xaas.local/resource/subscription/deepening-1"}}]}}),
           "application/sparql-results+json"}

        {status, body, ct} ->
          {status, body, ct}
      end
    end
  end

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Process.register(self(), :ontop_proxy_deepening_test)

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

      Application.delete_env(:xaas, :ontop_receiver_response)
      if Process.alive?(server_pid), do: Process.exit(server_pid, :shutdown)
    end)

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  defp authed(conn), do: put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))

  defp drain_receiver do
    receive do
      {:ontop_receiver_saw, _} -> drain_receiver()
    after
      0 -> :ok
    end
  end

  # ---------------------------------------------------------------------------
  # (a) byte-exact forwarding + verbatim relay
  # ---------------------------------------------------------------------------

  test "GET forwards the query string byte-exact and relays the receiver response verbatim", %{
    conn: conn
  } do
    drain_receiver()

    conn =
      conn
      |> authed()
      |> get("/internal-api/sparql?query=" <> URI.encode_www_form(@query_bytes))

    assert conn.status == 200
    # verbatim relay: the exact bytes the receiver produced, including its
    # real content-type header
    assert conn.resp_body ==
             ~s({"head":{"vars":["s"]},"results":{"bindings":[{"s":{"type":"uri","value":"http://xaas.local/resource/subscription/deepening-1"}}]}})

    assert get_resp_header(conn, "content-type") == [
             "application/sparql-results+json; charset=utf-8"
           ]

    assert_receive {:ontop_receiver_saw, seen}
    assert seen.method == "GET"
    assert seen.path == ["sparql"]
    # byte-exact upstream path+query: the percent-encoded query bytes the
    # client sent are the bytes Ontop receives
    assert seen.query_string == "query=" <> URI.encode_www_form(@query_bytes)
  end

  test "POST forwards the request body byte-exact (SPARQL Protocol POST direct) and relays verbatim", %{
    conn: conn
  } do
    drain_receiver()

    # application/sparql-query is the SPARQL 1.1 Protocol direct-POST
    # content type; the endpoint's Plug.Parsers (urlencoded/multipart/json)
    # does not match it, so the raw body survives to the proxy and is
    # forwarded byte-exact.
    body = "query=" <> URI.encode_www_form(@query_bytes)

    conn =
      conn
      |> authed()
      |> put_req_header("content-type", "application/sparql-query")
      |> post("/internal-api/sparql", body)

    assert conn.status == 200

    assert conn.resp_body ==
             ~s({"head":{"vars":["s"]},"results":{"bindings":[{"s":{"type":"uri","value":"http://xaas.local/resource/subscription/deepening-1"}}]}})

    assert_receive {:ontop_receiver_saw, seen}
    assert seen.method == "POST"
    assert seen.body == body
  end

  test "authorization header is stripped, not forwarded upstream", %{conn: conn} do
    drain_receiver()

    conn = conn |> authed() |> get("/internal-api/sparql?query=ASK%20%7B%7D")

    assert conn.status == 200
    assert_receive {:ontop_receiver_saw, seen}

    refute Enum.any?(seen.req_headers, fn {k, _v} -> k == "authorization" end)
  end

  # ---------------------------------------------------------------------------
  # (b) receiver down -> the real typed behavior
  # ---------------------------------------------------------------------------

  test "receiver down -> 502 with exact body %{error => ontop_unreachable}, halted", %{conn: conn} do
    drain_receiver()

    # point at a guaranteed-closed real port: bind, capture, release — a
    # real connection-refused, not a stubbed client
    {:ok, sock} =
      :gen_tcp.listen(0, [{:ip, {127, 0, 0, 1}}, :binary, {:active, false}])

    {:ok, closed_port} = :inet.port(sock)
    :ok = :gen_tcp.close(sock)

    Application.put_env(:xaas, :ontop_base_url, "http://127.0.0.1:#{closed_port}")

    conn =
      conn
      |> authed()
      |> get("/internal-api/sparql?query=SELECT%20*%20WHERE%20%7B%7D")

    assert conn.status == 502
    body = Jason.decode!(conn.resp_body)
    assert body["error"] == "ontop_unreachable"
    assert is_binary(body["detail"]) and body["detail"] != ""
    assert body["detail"] =~ "refused"

    assert conn.halted
  end

  # ---------------------------------------------------------------------------
  # (c) receiver 4xx/5xx -> real passthrough contract
  # ---------------------------------------------------------------------------

  test "receiver 400 -> status and body passthrough verbatim", %{conn: conn} do
    drain_receiver()
    Application.put_env(:xaas, :ontop_receiver_response, {400, ~s({"error":"malformed query"}), "application/json"})

    conn = conn |> authed() |> get("/internal-api/sparql?query=bogus")

    assert conn.status == 400
    assert conn.resp_body == ~s({"error":"malformed query"})
    assert not conn.halted
  end

  test "receiver 500 -> status and body passthrough verbatim (no rewrite, no retry)", %{conn: conn} do
    drain_receiver()

    Application.put_env(
      :xaas,
      :ontop_receiver_response,
      {500, ~s({"error":"internal ontop failure"}), "application/json"}
    )

    conn = conn |> authed() |> get("/internal-api/sparql?query=SELECT%20%3Fs%20WHERE%20%7B%7D")

    assert conn.status == 500
    assert conn.resp_body == ~s({"error":"internal ontop failure"})
    assert not conn.halted
  end

  # ---------------------------------------------------------------------------
  # (d) auth floor per the W723 pinned matrix
  # ---------------------------------------------------------------------------

  test "no Authorization header -> 401 exact W723 body, receiver never sees the request", %{
    conn: conn
  } do
    drain_receiver()

    conn = get(conn, "/internal-api/sparql?query=SELECT%20*%20WHERE%20%7B%7D")

    assert conn.status == 401
    assert Jason.decode!(conn.resp_body) == %{
             "error" => "unauthorized",
             "detail" => "missing or invalid Bearer token"
           }

    assert conn.halted
    refute_received {:ontop_receiver_saw, _}
  end

  test "wrong Bearer token -> 401, receiver never sees the request", %{conn: conn} do
    drain_receiver()

    conn =
      conn
      |> put_req_header("authorization", "Bearer not-the-real-token")
      |> get("/internal-api/sparql?query=SELECT%20*%20WHERE%20%7B%7D")

    assert conn.status == 401
    assert conn.halted
    refute_received {:ontop_receiver_saw, _}
  end

  # ---------------------------------------------------------------------------
  # (e) read-only posture of what the proxy permits
  # ---------------------------------------------------------------------------

  test "proxy forwards client methods verbatim with no method allow-list (typed gap, disclosed)", %{
    conn: conn
  } do
    drain_receiver()

    # The plug forwards conn.method and the full body unchanged for ANY
    # method. Here: a DELETE with a body is forwarded byte-exact, exactly
    # like GET/POST. Read-only-ness is enforced only by Ontop's own SPARQL
    # endpoint (a SPARQL query endpoint has no update surface), not by this
    # proxy. Typed gap: UNSUPPORTED(method_allowlist) at the proxy layer.
    Application.put_env(:xaas, :ontop_receiver_response, {200, ~s({"ok":true}), "application/json"})

    conn =
      conn
      |> authed()
      |> put_req_header("content-type", "text/plain")
      |> delete("/internal-api/sparql?query=x", [])

    assert conn.status == 200

    assert_receive {:ontop_receiver_saw, seen}
    assert seen.method == "DELETE"
    assert seen.path == ["sparql"]

    # ...and a POST with a non-SPARQL body would equally be forwarded
    conn2 =
      Phoenix.ConnTest.build_conn()
      |> authed()
      |> put_req_header("content-type", "application/json")
      |> post("/internal-api/sparql", Jason.encode!(%{"anything" => "goes"}))

    assert conn2.status == 200
    assert_receive {:ontop_receiver_saw, seen2}
    assert seen2.method == "POST"

    # W794 FIX (was UNSUPPORTED(raw_body_preservation_after_parsers), see
    # docs/sjira/v26.10.6/plans/w794-raw-body-fix.md): the endpoint's
    # :body_reader now caches the exact raw bytes for this path, and the
    # proxy forwards them byte-exact. A json POST is no longer bodyless.
    assert seen2.body == Jason.encode!(%{"anything" => "goes"})
  end

  # ---------------------------------------------------------------------------
  # (f) W794 raw-body preservation across Plug.Parsers
  # ---------------------------------------------------------------------------

  test "urlencoded SPARQL Protocol form POST arrives upstream with the exact original body bytes", %{
    conn: conn
  } do
    drain_receiver()

    # Byte-exactness wrinkle: '+' and '%2B' and '~' must survive the
    # endpoint's Plug.Parsers urlencoded round-trip untouched, because the
    # proxy forwards the CACHED RAW bytes, never a re-serialization of the
    # parsed params.
    body =
      "query=" <> URI.encode_www_form("SELECT * WHERE { ?s ?p ?o }") <> "&note=a%2Bb~c+d"

    conn =
      conn
      |> authed()
      |> put_req_header("content-type", "application/x-www-form-urlencoded")
      |> post("/internal-api/sparql", body)

    assert conn.status == 200

    assert_receive {:ontop_receiver_saw, seen}
    assert seen.method == "POST"
    # THE load-bearing assert: exact original bytes upstream. If the
    # raw-body capture in StripeRawBodyReader is dropped for this path
    # (or the proxy stops preferring assigns[:raw_body]), Plug.Parsers has
    # already consumed the body and the proxy forwards "" -- this assert
    # fails with got "" / expected the original bytes.
    assert seen.body == body

    # the parsed params still decoded normally through the endpoint
    assert conn.body_params["note"] == "a+b~c d"
  end

  test "multipart POST remains a pinned typed gap: body_reader is bypassed, upstream still sees empty", %{
    conn: conn
  } do
    drain_receiver()

    boundary = "----W794Boundary"
    body =
      "--" <> boundary <> "\r\n" <>
        "content-disposition: form-data; name=\"query\"\r\n\r\n" <>
        "SELECT * WHERE { ?s ?p ?o }\r\n" <>
        "--" <> boundary <> "--\r\n"

    conn =
      conn
      |> authed()
      |> put_req_header("content-type", "multipart/form-data; boundary=" <> boundary)
      |> post("/internal-api/sparql", body)

    assert conn.status == 200

    assert_receive {:ontop_receiver_saw, seen}
    assert seen.method == "POST"

    # Typed gap stays open for multipart ONLY: Plug.Parsers' :body_reader
    # (the W794 capture point) is bypassed by the multipart parser, which
    # reads part bodies straight off the adapter, so the exact raw bytes
    # are unrecoverable by the time the proxy runs. Fixing this would need
    # a capture plug mounted before Plug.Parsers in the endpoint pipeline
    # (outside this lane's file lease). Pinned here as the real behavior:
    # UNSUPPORTED(raw_body_preservation_multipart).
    assert seen.body == ""
  end
end
