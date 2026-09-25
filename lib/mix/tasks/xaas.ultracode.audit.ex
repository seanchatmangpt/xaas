defmodule Mix.Tasks.Xaas.Ultracode.Audit do
  @shortdoc "Judges an ultracode campaign's validation standing ((a)+(b)+(c), read-only)"

  @moduledoc """
  The one morning-after command for an overnight `Xaas.Ultracode.Campaign`:
  it prints, per wave, the (a)/(b)/(c) evidence lines of the validation law
  (`docs/ultracode/eight-hour-run.md` §5, "How the whole run is judged
  validated") and one final standing line. READ-ONLY: the task mutates no
  campaign state -- its only writes are the OCEL export files it owns under
  a throwaway tmpdir, removed before exit.

      mix xaas.ultracode.audit              # most recent campaign row
      mix xaas.ultracode.audit --run <campaign-run-id>

  THE JUDGMENT ITSELF LIVES IN `Xaas.Ultracode.Audit.judgment/2` -- the
  one law, shared with `Xaas.Ultracode.Campaign`'s `:running -> :completed`
  standing edge (which derives the campaign row's terminal standing from
  the same judgment instead of from the wave receipts' coarse standings).
  This task is that law's read-only print surface: `audit/1` is a pure
  delegation, and everything below only formats what the judgment returned.

  The law, per campaign and every wave it ran: (a) TERMINALITY (the
  campaign row and every wave epoch terminal, censused over the ledger's
  `attempt_start` runs), (b) ALIVE EVIDENCE (every delivered item's
  receipt carries `head_verified`; no exhausted-attempt item left
  behind), (c) OCEL CONFORMANCE (every wave Run's log passes the real
  `OcelEgress.export_run/2` + `Ocel.Validator.validate_file/1` court).
  See `Xaas.Ultracode.Audit` for the full statement.

  Standing:

    * `ALIVE` -- (a)+(b)+(c) hold for every wave.
    * `PARTIAL_ALIVE (missing: …)` -- judgeable, with every failing part
      named (the campaign row, named epochs, named items, named runs).
    * `BLOCKED (reason)` -- the audit could not judge at all (campaign row
      missing/not a campaign, malformed ledger, export or DB failure): an
      infrastructure/data error, never a verdict.

  Exit behavior: 0 when judged (`ALIVE`/`PARTIAL_ALIVE`); non-zero only on
  the `BLOCKED` path.
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} = OptionParser.parse(args, strict: [run: :string])
    Mix.Task.run("app.start")

    case audit(opts[:run]) do
      {:ok, report} ->
        # Judged: exit 0 by natural completion; the report is the verdict.
        print_report(report)

      {:error, reason} ->
        Mix.shell().error("standing: BLOCKED (#{format_reason(reason)})")
        System.halt(1)
    end
  end

  # Pure delegation: the task's historical judgment entry point is the
  # shared law module's `judgment/1` (its contract map carries the task's
  # historical `waves`/`verdict` names as projections of the same one
  # judgment, so this surface and its tests are shape-identical).
  defdelegate audit(campaign_id_or_nil), to: Xaas.Ultracode.Audit, as: :judgment

  # ------------------------------------------------------------------
  # Printing
  # ------------------------------------------------------------------

  defp print_report(report) do
    shell = Mix.shell()

    shell.info(
      "campaign:   #{report.run_id} (state #{report.state}, standing #{report.campaign_standing})"
    )

    shell.info(
      "ledger:     #{report.ledger}#{if report.ledger_present, do: "", else: " (absent)"}"
    )

    shell.info("waves:      #{length(report.per_wave)} (from the ledger's attempt census)")

    Enum.each(report.per_wave, fn wave ->
      shell.info("wave #{wave.wave}:     #{wave_line(wave)}")
    end)

    case report.verdict do
      :alive ->
        shell.info("standing:   ALIVE")

      {:partial_alive, missing} ->
        shell.info("standing:   PARTIAL_ALIVE (missing: #{Enum.join(missing, "; ")})")
    end
  end

  defp wave_line(wave) do
    "(a) terminality #{wave.epochs.terminal}/#{wave.epochs.total} #{wave.checks.a} " <>
      "(#{wave.runs} run(s)) | (b) alive #{wave.items.done} done, #{wave.items.blocked} " <>
      "blocked #{wave.checks.b} | (c) ocel court #{wave.ocel.pass}/#{wave.ocel.total} " <>
      "#{wave.checks.c}"
  end

  defp format_reason({:malformed_ledger, path, line, reason}),
    do: "malformed ledger #{path} line #{line}: #{inspect(reason)}"

  defp format_reason({:malformed_ledger_event, event, data}),
    do: "malformed ledger #{event} event: #{inspect(data)}"

  defp format_reason({:ledger_event_before_wave_start, event}),
    do: "ledger event #{event} appears before any campaign_wave_start"

  defp format_reason({:ocel_export_failed, run_id, reason}),
    do: "OCEL export failed for wave run #{run_id}: #{inspect(reason)}"

  defp format_reason({:not_a_campaign, id}), do: "run #{id} is not a campaign row"
  defp format_reason(:campaign_not_found), do: "campaign_not_found"
  defp format_reason(:no_campaign_found), do: "no campaign row exists"

  defp format_reason(reason), do: inspect(reason)
end
