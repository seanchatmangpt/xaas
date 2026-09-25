defmodule Mix.Tasks.Xaas.Ultracode.Status do
  @shortdoc "Reports an ultracode campaign's budget, waves, and in-flight epochs"

  @moduledoc """
  Real status for an ultracode wave campaign -- see `Xaas.Ultracode.Campaign
  .status/1`. With no `--run`, defaults to the most recent campaign row.

      mix xaas.ultracode.status
      mix xaas.ultracode.status --run <campaign-run-id>

  Prints the campaign row's state/standing, the remaining budget (waves and
  wall clock), the per-wave digest from the campaign ledger, and the
  fabric-wide in-flight epoch counts (`total`/`leased`/`unleased`) -- the
  number a keep-alive top-up compares against the capacity setpoint.
  """

  use Mix.Task

  alias Xaas.Ultracode.Campaign

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} = OptionParser.parse(args, strict: [run: :string])
    Mix.Task.run("app.start")

    case Campaign.status(opts[:run]) do
      {:ok, s} ->
        Mix.shell().info("campaign:      #{s.run_id}")
        Mix.shell().info("state:         #{s.state} (standing #{s.standing})")

        Mix.shell().info(
          "budget:        #{s.waves_executed}/#{s.wave_budget} waves, " <>
            "#{s.seconds_remaining}s of wall clock remaining"
        )

        Mix.shell().info("deadline_at:   #{s.deadline_at && DateTime.to_iso8601(s.deadline_at)}")

        Mix.shell().info(
          "in-flight:     #{s.in_flight.total} running epoch(s) " <>
            "(#{s.in_flight.leased} leased, #{s.in_flight.unleased} unleased)"
        )

        Mix.shell().info(
          "ledger:        #{s.ledger}#{if s.ledger_present, do: "", else: " (absent)"}"
        )

        case s.waves do
          [] ->
            Mix.shell().info("waves:         none recorded")

          waves ->
            Enum.each(waves, fn w ->
              Mix.shell().info("wave #{w.wave}: #{w.standing || "error #{w.error}"}")
            end)
        end

      {:error, reason} ->
        Mix.raise("campaign status failed: #{inspect(reason)}")
    end
  end
end
