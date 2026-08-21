defmodule KanbanWeb.PrometheusQueryController do
  @moduledoc """
  Real internal-only proxy for Prometheus's real `/api/v1/query` HTTP
  API. Forwards the `query` param via `Req` (already a project dep) to
  the real Prometheus base URL configured by the `PROMETHEUS_URL` env
  var (default `http://localhost:9090` for local dev; the real deployed
  base URL in `kind-xaas` is the `prometheus` pod, see `k8s/`).

  Gated by the router-level `KanbanWeb.Plugs.RequireInternalApiToken`
  Bearer check -- same as the other `/internal-api` routes.

  Real Prometheus JSON responses are returned as-is (status + body) so
  callers get Prometheus's own `status`/`data`/`errorType`/`error`
  shape. If Prometheus is unreachable (real `Req.TransportError`, e.g.
  connection refused or timeout), this returns a real 502 with a clear
  JSON error body instead of crashing.
  """

  use KanbanWeb, :controller

  @default_base_url "http://localhost:9090"

  def query(conn, %{"query" => promql}) do
    base_url = System.get_env("PROMETHEUS_URL", @default_base_url)

    case Req.get(base_url <> "/api/v1/query", params: [query: promql]) do
      {:ok, %Req.Response{status: status, body: body}} ->
        conn
        |> put_status(status)
        |> json(body)

      {:error, %Req.TransportError{reason: reason}} ->
        conn
        |> put_status(502)
        |> json(%{
          error: "prometheus_unreachable",
          detail: "could not reach Prometheus at #{base_url}: #{inspect(reason)}"
        })

      {:error, other} ->
        conn
        |> put_status(502)
        |> json(%{
          error: "prometheus_unreachable",
          detail: "could not reach Prometheus at #{base_url}: #{inspect(other)}"
        })
    end
  end

  def query(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{error: "missing_query_param", detail: "GET /internal-api/prometheus/query requires a \"query\" param"})
  end
end
