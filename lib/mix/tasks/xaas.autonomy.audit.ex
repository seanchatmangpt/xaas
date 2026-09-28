defmodule Mix.Tasks.Xaas.Autonomy.Audit do
  @shortdoc "Audits UAR=0 + DCR=0 over a window (unreceipted actuations, duplicate consequences)"

  @moduledoc """
  The standing-window tripwire (`Xaas.Ultracode.AutonomyAudit`): checks that
  over a window

    * **UAR = 0** -- no terminal epoch acted without a sealed STANDING
      receipt (an unreceipted actuation), and
    * **DCR = 0** -- no epoch recorded its consequence twice (duplicate
      standing receipts).

      mix xaas.autonomy.audit                          # last 24 hours
      mix xaas.autonomy.audit --window-minutes 120     # explicit window
      mix xaas.autonomy.audit --since 2026-09-25T00:00:00Z

  Standing: `ALIVE` (both zero, vacuously including an empty window -- the
  counts say so), `PARTIAL_ALIVE (UAR=n ..., DCR=m ...)` naming every
  offending epoch id. Exit: 0 when ALIVE; 1 when violated or BLOCKED -- this
  task IS a check, and a check that exits 0 on its own violation is a check
  with no bits.
  """

  use Mix.Task

  alias Xaas.Ultracode.AutonomyAudit

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [window_minutes: :integer, since: :string]
      )

    Mix.Task.run("app.start")

    with :ok <- validate_opts(opts),
         {:ok, since} <- resolve_since(opts),
         {:ok, report} <- AutonomyAudit.audit(since: since) do
      print_report(report)

      case report.standing do
        :alive -> :ok
        {:partial_alive, _} -> System.halt(1)
      end
    else
      {:error, reason} ->
        Mix.shell().error("standing: BLOCKED (#{inspect(reason)})")
        System.halt(1)
    end
  end

  defp validate_opts(opts) do
    if opts[:window_minutes] && opts[:since] do
      {:error, :pick_one_window_shape}
    else
      :ok
    end
  end

  defp resolve_since(opts) do
    cond do
      iso = opts[:since] ->
        case DateTime.from_iso8601(iso) do
          {:ok, dt, _offset} -> {:ok, dt}
          {:error, reason} -> {:error, {:bad_since, iso, reason}}
        end

      minutes = opts[:window_minutes] ->
        {:ok, DateTime.add(DateTime.utc_now(), -minutes * 60, :second)}

      true ->
        {:ok,
         DateTime.add(DateTime.utc_now(), -AutonomyAudit.default_window_minutes() * 60, :second)}
    end
  end

  defp print_report(report) do
    shell = Mix.shell()

    shell.info(
      "window: #{DateTime.to_iso8601(report.since)} .. #{DateTime.to_iso8601(report.until)} " <>
        "(#{report.epochs_audited} terminal epoch(s) audited)"
    )

    shell.info("UAR:    #{length(report.uar)}#{ids(report.uar)}")
    shell.info("DCR:    #{length(report.dcr)}#{ids(report.dcr)}")

    case report.standing do
      :alive ->
        shell.info("standing: ALIVE (UAR=0, DCR=0)")

      {:partial_alive, missing} ->
        shell.info("standing: PARTIAL_ALIVE (#{Enum.join(missing, "; ")})")
    end
  end

  defp ids([]), do: ""
  defp ids(list), do: " -- " <> Enum.join(list, ", ")
end
