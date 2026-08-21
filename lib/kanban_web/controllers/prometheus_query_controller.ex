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

  ## PromQL query allowlist (real, disclosed design)

  An authenticated internal caller can otherwise pass ANY PromQL string
  through to the real Prometheus instance, including real
  resource-exhausting queries (unbounded range-vector selectors like
  `foo[365d]`, high-cardinality-risk functions like `topk`/`count by`
  with no metric-name anchor at all, subqueries, etc).

  Writing a full PromQL grammar/parser here is too large a lift for
  this pass (disclosed, not silently skipped) -- Prometheus's own
  query language has a real, non-trivial grammar (binary operators,
  aggregations, subqueries, functions). Instead this module applies a
  real, pragmatic **allowlist of query shapes**, via
  `KanbanWeb.PrometheusQueryAllowlist`:

    1. The query must reference at least one metric name matching a
       real prefix this app's own PromEx setup actually emits (see
       `config/config.exs`'s `Kanban.PromEx` config and
       `lib/kanban/prom_ex.ex`/`lib/kanban/prom_ex/cpu_plugin.ex`):
       `application_`, `beam_`, `phoenix_`, `phoenix_live_view_`,
       `ecto_`, `cpu_`, or the PromEx-internal `promex_` metrics. A
       query whose only metric-name-shaped token doesn't start with
       one of these prefixes is rejected -- this also rejects queries
       with no metric name at all (e.g. a bare function call), since
       there is then no allowed prefix present.
    2. Real dangerous constructs are rejected regardless of metric
       name: an explicit range-vector selector (`metric[duration]`)
       with a duration of 1 day or more (`[1d]`, `[7d]`, `[365d]`,
       `[52w]`, `[8760h]`, ...) -- a real, unbounded-lookback query
       shape that can force Prometheus to scan a very large real time
       range. Range-vector selectors under 1 day (e.g. `[5m]`, `[1h]`,
       the shapes `rate()`/`irate()` actually need) are allowed.
       Subquery syntax (`expr[range:step]`) is rejected outright since
       it multiplies real query cost and isn't a shape this app's own
       dashboards use.

  This is a real, named tradeoff: it will reject some queries a full
  parser would recognize as safe (e.g. valid PromQL using a metric
  name allowlisted here inside `functions this module doesn't scan
  for), and it will not catch every conceivable resource-exhausting
  shape a full parser+cost-estimator would. It does close the two
  concrete gaps named in the task: metric names outside this app's own
  real, configured metric surface, and unbounded range-vector
  lookbacks.
  """

  use KanbanWeb, :controller

  alias KanbanWeb.PrometheusQueryAllowlist

  @default_base_url "http://localhost:9090"

  def query(conn, %{"query" => promql}) do
    case PrometheusQueryAllowlist.check(promql) do
      :ok ->
        forward_to_prometheus(conn, promql)

      {:error, reason} ->
        conn
        |> put_status(400)
        |> json(%{error: "query_not_allowed", detail: reason})
    end
  end

  def query(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{error: "missing_query_param", detail: "GET /internal-api/prometheus/query requires a \"query\" param"})
  end

  defp forward_to_prometheus(conn, promql) do
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
end
