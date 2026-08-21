defmodule KanbanWeb.PrometheusQueryAllowlist do
  @moduledoc """
  Real, pragmatic PromQL query-shape allowlist for
  `KanbanWeb.PrometheusQueryController` -- see that module's `@moduledoc`
  for the full disclosed design rationale. Not a full PromQL parser; a
  regex/pattern-based check over two real risk axes: metric-name prefix
  and range-vector duration.
  """

  # Real metric-name prefixes this app's own PromEx setup actually
  # emits, grounded in config/config.exs's `Kanban.PromEx` config and
  # lib/kanban/prom_ex.ex's `dashboard_assigns`/plugin list:
  #   - PromEx.Plugins.Application -> `application_*`
  #   - PromEx.Plugins.Beam        -> `beam_*`
  #   - PromEx.Plugins.Phoenix     -> `phoenix_*`
  #   - PromEx.Plugins.Ecto        -> `ecto_*`
  #   - PromEx.Plugins.PhoenixLiveView -> `phoenix_live_view_*`
  #   - Kanban.PromEx.CpuPlugin    -> `cpu_*` (metric name [:cpu, :util])
  #   - PromEx itself              -> `promex_*` (internal PromEx health metrics)
  @allowed_metric_prefixes ~w(
    application_
    beam_
    phoenix_live_view_
    phoenix_
    ecto_
    cpu_
    promex_
  )

  # Metric-name-shaped tokens: PromQL metric names are
  # `[a-zA-Z_:][a-zA-Z0-9_:]*`.
  @metric_name_regex ~r/\b[a-zA-Z_:][a-zA-Z0-9_:]*\b/

  # Range-vector selector: `metric_name{...}[<duration>]` or
  # `metric_name[<duration>]`. Captures the duration token.
  @range_vector_regex ~r/\[\s*([0-9]+)\s*([smhdwy])\s*\]/i

  # Subquery syntax: `expr[range:step]` -- always rejected, regardless
  # of duration, since it's a query shape none of this app's own
  # dashboards use and it multiplies real query cost.
  @subquery_regex ~r/\[\s*[0-9]+[smhdwy]\s*:\s*[0-9]*[smhdwy]?\s*\]/i

  @unbounded_duration_seconds 86_400

  @duration_unit_seconds %{
    "s" => 1,
    "m" => 60,
    "h" => 3_600,
    "d" => 86_400,
    "w" => 604_800,
    "y" => 31_536_000
  }

  @doc """
  Checks a raw PromQL query string against the real allowlist.
  Returns `:ok` if the query is permitted, or `{:error, reason}` with a
  real, specific rejection reason otherwise.
  """
  @spec check(String.t()) :: :ok | {:error, String.t()}
  def check(promql) when is_binary(promql) do
    with :ok <- reject_subquery(promql),
         :ok <- reject_unbounded_range(promql),
         :ok <- require_allowed_metric_name(promql) do
      :ok
    end
  end

  defp reject_subquery(promql) do
    if Regex.match?(@subquery_regex, promql) do
      {:error,
       "subquery syntax (expr[range:step]) is not in the real, configured allowlist of query shapes"}
    else
      :ok
    end
  end

  defp reject_unbounded_range(promql) do
    @range_vector_regex
    |> Regex.scan(promql)
    |> Enum.find_value(:ok, fn [full_match, amount, unit] ->
      unit = String.downcase(unit)
      seconds = String.to_integer(amount) * Map.fetch!(@duration_unit_seconds, unit)

      if seconds >= @unbounded_duration_seconds do
        {:error,
         "range-vector selector #{full_match} has a duration of #{amount}#{unit} (>= 1 day), " <>
           "which is not in the real, configured allowlist of query shapes " <>
           "(unbounded-lookback queries are rejected regardless of metric name)"}
      end
    end)
  end

  defp require_allowed_metric_name(promql) do
    metric_names =
      @metric_name_regex
      |> Regex.scan(promql)
      |> List.flatten()
      |> Enum.reject(&promql_keyword_or_number?/1)

    if Enum.any?(metric_names, &allowed_metric_name?/1) do
      :ok
    else
      {:error,
       "no metric name in the real, configured allowlist found in query #{inspect(promql)} " <>
         "(allowed prefixes: #{Enum.join(@allowed_metric_prefixes, ", ")})"}
    end
  end

  defp allowed_metric_name?(token) do
    Enum.any?(@allowed_metric_prefixes, &String.starts_with?(token, &1))
  end

  # PromQL keywords/functions/label names that are NOT metric names,
  # so they don't false-negative the allowlist check (e.g. `rate`,
  # `by`, a label key like `instance`) and don't false-positive it
  # either (none of these happen to share an allowed prefix).
  @promql_reserved ~w(
    by without and or unless on ignoring group_left group_right offset
    bool
    sum min max avg group stddev stdvar count count_values quantile
    topk bottomk
    rate irate increase delta idelta
    abs ceil floor round exp ln log2 log10 sqrt
    time timestamp vector scalar
    label_replace label_join
    histogram_quantile
    sort sort_desc
    clamp clamp_min clamp_max
    absent absent_over_time
    changes resets
    predict_linear deriv
    holt_winters
  )

  defp promql_keyword_or_number?(token) do
    token in @promql_reserved or Regex.match?(~r/^[0-9]+$/, token)
  end
end
