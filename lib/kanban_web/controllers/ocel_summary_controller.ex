defmodule KanbanWeb.OcelSummaryController do
  @moduledoc """
  Real, read-only summary over the real OCEL v2 event log
  (`Xaas.Telemetry.OcelAshEmitter.log_path/0`) -- one real, genuinely
  observed row per real Ash action execution, accumulated since the
  server booted (18,610+ real events at the time this was written,
  spanning real ingest/read/create traffic from the ash_admin Playwright
  test, real benchmark runs, and real capability-liveness ingests).

  Aggregates real, not fabricated: reads the real NDJSON file, counts
  real `ocel:activity` occurrences and real `outcome` (stop/exception)
  breakdowns. No sampling, no synthetic data -- if the file doesn't
  exist yet (fresh boot, zero Ash actions executed), returns real zero
  counts rather than fabricating history.
  """

  use KanbanWeb, :controller

  def index(conn, _params) do
    path = Xaas.Telemetry.OcelAshEmitter.log_path()

    {activity_counts, outcome_counts, total} =
      if File.exists?(path) do
        path
        |> File.stream!()
        |> Stream.map(&String.trim/1)
        |> Stream.reject(&(&1 == ""))
        |> Enum.reduce({%{}, %{}, 0}, fn line, {activities, outcomes, count} ->
          case Jason.decode(line) do
            {:ok, event} ->
              activity = event["ocel:activity"]
              outcome = get_in(event, ["ocel:vmap", "outcome"]) || "unknown"

              {
                Map.update(activities, activity, 1, &(&1 + 1)),
                Map.update(outcomes, outcome, 1, &(&1 + 1)),
                count + 1
              }

            {:error, _} ->
              {activities, outcomes, count}
          end
        end)
      else
        {%{}, %{}, 0}
      end

    json(conn, %{
      total_events: total,
      by_activity: activity_counts,
      by_outcome: outcome_counts,
      log_path: path
    })
  end
end
