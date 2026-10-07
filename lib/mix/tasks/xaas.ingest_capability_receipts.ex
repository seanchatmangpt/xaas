defmodule Mix.Tasks.Xaas.IngestCapabilityReceipts do
  @moduledoc """
  Real autonomic ingest step: reads a `weaver-live-matrix.sh`-produced
  `receipt.jsonl` (real OCEL v2 evidence, one JSON row per capability, real
  exit codes from an actually-executed shell command) and upserts each row
  into `Xaas.Operations.CapabilityLivenessReceipt` via its `:ingest` action.

  Usage:

      mix xaas.ingest_capability_receipts /path/to/receipt.jsonl

  Defaults to `../chatman-ecosystem/target/weaver-live/receipt.jsonl`
  relative to this app's working directory when no path is given.
  """
  use Mix.Task

  @shortdoc "Ingest a real weaver-live-matrix.sh receipt.jsonl into Ash"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    path =
      case args do
        [p | _] -> p
        [] -> Path.expand("../chatman-ecosystem/target/weaver-live/receipt.jsonl", File.cwd!())
      end

    unless File.exists?(path) do
      Mix.raise(
        "No receipt file at #{path} -- run weaver-live-matrix.sh first (real, not fabricated)."
      )
    end

    rows =
      path
      |> File.stream!()
      |> Stream.map(&String.trim/1)
      |> Stream.reject(&(&1 == ""))
      |> Stream.map(&Jason.decode!/1)
      |> Enum.to_list()

    results =
      Enum.map(rows, fn row ->
        Xaas.Operations.CapabilityLivenessReceipt
        |> Ash.Changeset.for_create(:ingest, %{
          capability: row["capability"],
          authority: row["authority"],
          status: row["status"],
          executed: row["executed"],
          exit_code: row["exit_code"],
          subject: row["subject"],
          detail: row["detail"]
        })
        # This is a system-internal autonomic ingest (real telemetry -> real
        # Ash state), not a user-facing action. It runs THROUGH authorization
        # as the same :oban_scheduler system authority the resource's own
        # AshOban schedule uses; the resource's scoped :ingest policy admits
        # exactly that actor and the deny-by-default floor refuses everyone
        # else. No authorize?: false bypass remains.
        |> Ash.create(
          actor: Xaas.SystemAuthority.new(:oban_scheduler),
          authorize?: true
        )
      end)

    ok = Enum.count(results, &match?({:ok, _}, &1))
    errors = Enum.filter(results, &match?({:error, _}, &1))

    Mix.shell().info("Ingested #{ok}/#{length(rows)} real capability-liveness rows from #{path}.")

    if errors != [] do
      Mix.shell().error("#{length(errors)} rows failed:")
      Enum.each(errors, fn {:error, e} -> Mix.shell().error(inspect(e)) end)
    end

    # Real autonomic "Analyze" step: after a real ingest, check for real
    # regressions against the real history already in the DB (see
    # Xaas.Operations.CapabilityLivenessRegressions moduledoc).
    case Xaas.Operations.CapabilityLivenessRegressions.detect() do
      [] ->
        Mix.shell().info("No capability regressions detected against prior real ingests.")

      regressions ->
        Mix.shell().error("#{length(regressions)} REAL capability regression(s) detected:")

        Enum.each(regressions, fn r ->
          Mix.shell().error(
            "  #{r.capability}: #{r.was.status} (#{r.was.subject}) -> #{r.now.status} (#{r.now.subject})"
          )
        end)
    end
  end
end
