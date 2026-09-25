defmodule Mix.Tasks.Xaas.Ultracode.TickHealth do
  @shortdoc "Reports whether Xaas.Ultracode.Run's AshOban :tick cron is still firing"

  @moduledoc """
  Real liveness check over `Xaas.Ultracode.TickHealth.check/1` -- see that
  module's moduledoc for the full contract (queries the real `Oban.Job`
  table for the most recent `Xaas.Ultracode.Run.Workers.Tick` activity,
  classifies `:healthy`/`:stale` against a real elapsed-time threshold).

  Usage:

      mix xaas.ultracode.tick_health
      mix xaas.ultracode.tick_health --stale-after-minutes 10

  Exit behavior (this repo's typed-refusal convention, matching
  `mix xaas.telemetry.check_ontology_staleness`):

    * `:healthy` -- prints the last-tick evidence, exits 0.
    * `:stale` -- prints the same evidence plus a remediation pointer and
      raises (non-zero exit), so this is real CI/cron-monitor material,
      not just an informational print.
  """

  use Mix.Task

  alias Xaas.Ultracode.TickHealth

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    opts = parse_args(args)

    case TickHealth.check(opts) do
      %{status: :healthy} = result ->
        Mix.shell().info(format(result))

      %{status: :stale} = result ->
        Mix.shell().error(format(result))

        Mix.raise(
          "ultracode :tick cron appears stale -- no #{result.worker} job has completed or " <>
            "started executing within the last #{result.stale_after_minutes} minute(s). " <>
            "Remediation: confirm the supervised Oban process is up (see Xaas.Application), " <>
            "that `config :xaas, Oban` still lists a `:default`-queue worker for this " <>
            "resource's `queue(:default)` `oban do schedule :tick, ...` block " <>
            "(lib/xaas/ultracode/run.ex), and that `Oban.Plugins.Cron`'s crontab (via " <>
            "`AshOban.config/2`, see lib/xaas/application.ex) actually includes this schedule."
        )
    end
  end

  defp parse_args(args) do
    {parsed, _rest, _invalid} =
      OptionParser.parse(args, strict: [stale_after_minutes: :integer])

    case Keyword.fetch(parsed, :stale_after_minutes) do
      {:ok, minutes} -> [stale_after_minutes: minutes]
      :error -> []
    end
  end

  defp format(%{
         status: status,
         worker: worker,
         last_tick_at: last_tick_at,
         elapsed_minutes: elapsed_minutes,
         stale_after_minutes: stale_after_minutes
       }) do
    """
    ultracode tick health: #{status}
      worker:               #{worker}
      last_tick_at:         #{format_datetime(last_tick_at)}
      elapsed_minutes:      #{format_minutes(elapsed_minutes)}
      stale_after_minutes:  #{stale_after_minutes}
    """
  end

  defp format_datetime(nil), do: "never (no completed or executing job found)"
  defp format_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

  defp format_minutes(nil), do: "n/a"
  defp format_minutes(minutes) when is_float(minutes), do: Float.round(minutes, 2)
end
