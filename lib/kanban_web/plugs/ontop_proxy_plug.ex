defmodule KanbanWeb.OntopProxyPlug do
  @moduledoc """
  Real reverse-proxy in front of the real Ontop SPARQL endpoint (see
  `docs/claude/diataxis/explanation/r2rml-ontop-prototype.md`).

  Ontop is a real, third-party Java service (`ontop/ontop:latest`) with its
  own real embedded Tomcat HTTP server and no native Ash-policy integration
  -- a SPARQL query against it bypasses Ash's authorization layer entirely.
  Real fix chosen this session: bind Ontop's real host-published port to
  `127.0.0.1:8888` only (see `docker-compose.ontop.yaml`, no longer
  `0.0.0.0`, so it is unreachable from outside this machine at all) AND
  require every request to pass through this plug first, mounted at
  `/internal-api/sparql` behind the same real
  `KanbanWeb.Plugs.RequireInternalApiToken` pipeline every other
  `/internal-api` route already uses -- no new auth mechanism, no new
  container, reusing the existing real `INTERNAL_API_TOKEN` env var and
  the existing `Req` dependency (already in `mix.exs`, `~> 0.5.7`).

  This module itself talks to Ontop over the real internal Docker network
  (`http://ontop:8080`, the compose service name + its real internal
  container port -- both `xaas-web-1` and the `ontop` service are joined
  onto the same real `xaas_default` bridge network, confirmed via
  `docker inspect`), not through the host-published `127.0.0.1:8888` port
  (which is only reachable from the host machine itself, for local
  `curl`/troubleshooting -- not from inside the `xaas-web-1` container,
  where `127.0.0.1` refers to that container, not the host). Overridable
  via `config :kanban, :ontop_base_url` for tests/dev without a live
  container.

  This plug's own job is ONLY forwarding -- the actual Bearer-token check
  happens one plug earlier in the pipeline
  (`KanbanWeb.Plugs.RequireInternalApiToken`), same as every other
  `/internal-api` route. By the time `call/2` runs here, the request has
  already been real-authenticated; this module never re-implements or
  duplicates that check.

  ## What's still NOT solved (disclosed)

  This is host-level network binding + a proxy-level bearer check, not
  per-query Ash policy enforcement -- anyone holding the shared
  `INTERNAL_API_TOKEN` can run arbitrary SPARQL against all 4 mapped
  tables (no row-level or resource-level authorization inside Ontop
  itself). Same standing limitation already disclosed for
  `Xaas.Ledger`/`Xaas.Accounts` in this repo's other docs -- token
  possession, not per-actor Ash policy, is the real access-control
  boundary here.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    {:ok, body, conn} = read_body(conn)

    upstream_path =
      case conn.path_info do
        ["internal-api", "sparql" | rest] -> "/" <> Enum.join(["sparql" | rest], "/")
        _ -> "/sparql"
      end

    query_string = if conn.query_string == "", do: "", else: "?" <> conn.query_string
    url = ontop_base_url() <> upstream_path <> query_string

    forwarded_headers =
      conn.req_headers
      |> Enum.reject(fn {k, _v} -> k in ["host", "authorization", "content-length"] end)

    case req_module().request(
           method: conn.method,
           url: url,
           headers: forwarded_headers,
           body: body,
           retry: false
         ) do
      {:ok, %{status: status, headers: resp_headers, body: resp_body}} ->
        conn =
          Enum.reduce(resp_headers, conn, fn {k, v}, acc ->
            if String.downcase(k) in ["transfer-encoding", "connection"] do
              acc
            else
              put_resp_header(acc, k, to_string(v))
            end
          end)

        send_resp(conn, status, encode_body(resp_body))

      {:error, reason} ->
        conn
        |> put_status(502)
        |> Phoenix.Controller.json(%{
          error: "ontop_unreachable",
          detail: inspect(reason)
        })
        |> halt()
    end
  end

  defp encode_body(body) when is_binary(body), do: body
  defp encode_body(body), do: Jason.encode!(body)

  defp req_module, do: Application.get_env(:kanban, :ontop_proxy_http_client, Req)

  defp ontop_base_url,
    do: Application.get_env(:kanban, :ontop_base_url, "http://ontop:8080")
end
