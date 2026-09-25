defmodule Mix.Tasks.Xaas.Ultracode.ReconcileRuns do
  @shortdoc "Transitions stuck-pending ultracode item runs whose epochs are terminal"

  @moduledoc """
  One-shot sweep closing the wave-2 audit finding: item-level
  `ultracode_runs` rows that never transitioned (1043 rows `pending` on
  the 2026-09-21 dev DB) while their epochs/receipts carry the real
  terminality. Judged by `Xaas.Ultracode.ItemRuns`' classify law (the
  SAME court-grounded predicate the live Autonomic edge uses) and closed
  through the admitted, guarded `:transition_state` action -- never
  `authorize?: false`, never over live (non-terminal) epochs, never a
  standing-wave session row, never an epoch-less row.

      mix xaas.ultracode.reconcile_runs --dry-run   # census only, no writes
      mix xaas.ultracode.reconcile_runs             # live; idempotent re-run

  Prints the before/after GROUP BY state census, the transition counts,
  and every skipped run's reason (`no_epochs`, `epoch_not_terminal`,
  `stuck_classification`) -- still-pending rows are reported, never
  papered over.
  """

  use Mix.Task

  alias Xaas.Ultracode.RunReconciliation

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} = OptionParser.parse(args, strict: [dry_run: :boolean])
    Mix.Task.run("app.start")

    report = RunReconciliation.sweep(dry_run: Keyword.get(opts, :dry_run, false))
    shell = Mix.shell()

    shell.info(
      if report.dry_run do
        "reconcile_runs: DRY RUN (no writes)"
      else
        "reconcile_runs: LIVE"
      end
    )

    shell.info("considered:    #{report.considered} stuck non-session run(s)")
    shell.info("candidates:    #{report.candidates} evidence-terminal run(s)")

    shell.info(
      if report.dry_run do
        "would close:   #{report.would_transition}"
      else
        "closed:        #{report.transitions} (already terminal: #{report.already_terminal}, " <>
          "errors: #{length(report.errors)})"
      end
    )

    print_census(shell, "before", report.before)
    print_census(shell, "after ", report.after)

    Enum.each(Enum.sort(report.skipped), fn {reason, %{count: count, sample: sample}} ->
      shell.info("skipped #{reason}: #{count}")

      Enum.each(sample, fn {run_id, detail} ->
        shell.info("    #{run_id} #{inspect(detail)}")
      end)
    end)
  end

  defp print_census(shell, label, census) do
    entries =
      census
      |> Enum.sort_by(fn {state, _n} -> to_string(state) end)
      |> Enum.map_join(", ", fn {state, n} -> "#{state}: #{n}" end)

    shell.info("#{label} (GROUP BY state): #{entries}")
  end
end
