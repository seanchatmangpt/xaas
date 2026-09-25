defmodule XaasWeb.OcelSummaryController do
  @moduledoc """
  Real, read-only summary over the real OCEL v2 event log
  (`Xaas.Telemetry.OcelAshEmitter.log_path/0`) -- one real, genuinely
  observed row per real Ash action execution, accumulated since the
  server booted (18,610+ real events at the time this was written,
  spanning real ingest/read/create traffic from the ash_admin Playwright
  test, real benchmark runs, and real capability-liveness ingests).

  Aggregates real, not fabricated: reads the real NDJSON file, counts
  real `ocel:events[].type` occurrences and real
  `ocel:events[].attributes.outcome` (ok/error) breakdowns. No sampling,
  no synthetic data -- if the file doesn't exist yet (fresh boot, zero
  Ash actions executed), returns real zero counts rather than
  fabricating history.

  ## OCEL v2 shape alignment (ERRC E10 sweep)

  Each NDJSON line is now a COMPLETE OCEL 2.0 JSON log (one event plus
  its objects -- see `Xaas.Telemetry.OcelAshEmitter`'s "OCEL v2 reshape"
  moduledoc section), so the activity is read from the event's `"type"`
  key and the outcome from its `"attributes"` map (the spec's one open
  surface; the old `ocel:vmap` no longer exists). This reader is
  deliberately NEW-SHAPE-ONLY, no tolerance branch for the old flat
  `ocel:activity`/`ocel:vmap` lines: the rotation law caps the live log
  at ~3 x 10 MiB and the observed live file contained zero old-format
  lines after the reshaped emitter went in, so a fallback reader would
  be dead code for a shape that no longer exists. A line that does not
  decode to a document with an `ocel:events` list (truncated tail line,
  foreign writer) is skipped -- same real-zero discipline as before.
  """

  use XaasWeb, :controller

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
            {:ok, %{"ocel:events" => events}} when is_list(events) ->
              Enum.reduce(events, {activities, outcomes, count}, fn event, {acts, outs, c} ->
                activity = event["type"]
                outcome = get_in(event, ["attributes", "outcome"]) || "unknown"

                {
                  Map.update(acts, activity, 1, &(&1 + 1)),
                  Map.update(outs, outcome, 1, &(&1 + 1)),
                  c + 1
                }
              end)

            _not_an_ocel_v2_document ->
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
