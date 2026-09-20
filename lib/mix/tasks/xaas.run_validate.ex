defmodule Mix.Tasks.Xaas.RunValidate do
  @shortdoc "Validates a run's RESULTS via its OCEL 2.0 log (the results-validation law)"

  @moduledoc """
  The operator's results-validation law, on the command line: a run's
  RESULTS are validated iff its OCEL 2.0 log (a) passes structural
  conformance and (b) accounts for every epoch with terminal,
  receipt-backed evidence (exactly one `epoch_claimed`, exactly one
  `receipt_closed` with verification passed/failed/refused, and the
  worker capacity law respected at every instant). See
  `Xaas.Ultracode.RunValidation` for the full contract.

  Usage:

      mix xaas.run_validate <path/to/log.ocel.json> [--run-id <id>] [--capacity 5]

      mix xaas.run_validate <run_id>

  The first form validates a log file (a path). The second resolves the
  log through the configured OCEL emitter module
  (`config :xaas, :ultracode_ocel_log_emitter`, exporting `emit/1`) --
  the deterministic run-to-log projection is the emitter's owned
  mutation and is deliberately NOT re-derived here; with no emitter on
  the branch this form refuses with a typed message instead of
  fabricating a log. `--run-id` on the path form enforces that the log
  is for that exact run (`:wrong_run` otherwise).

  Exit behavior (typed-refusal convention, matching
  `mix xaas.ultracode.tick_health`):

    * `:validated`    -- prints the verdict + per-epoch accounting, exit 0.
    * `:not_validated` -- prints every violation naming the offending
      epoch ids to stderr, exit 1. Real CI/court material: a red verdict
      is always traceable to named events, never an unexplained boolean.
    * usage/refusal errors raise (non-zero exit).
  """

  use Mix.Task

  alias Xaas.Ultracode.RunValidation

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, positional, _invalid} =
      OptionParser.parse(args, strict: [run_id: :string, capacity: :integer])

    case positional do
      [subject] ->
        if File.regular?(subject) do
          validate_log_file(subject, opts)
        else
          validate_via_emitter(subject, opts)
        end

      _other ->
        Mix.raise(
          "usage: mix xaas.run_validate <log_path | run_id> [--run-id <id>] [--capacity <n>]"
        )
    end
  end

  defp validate_log_file(path, opts) do
    run_id = opts[:run_id]
    capacity_opts = if opts[:capacity], do: [capacity: opts[:capacity]], else: []

    result =
      if run_id do
        RunValidation.validate_run(run_id, path, capacity_opts)
      else
        RunValidation.validate(path, capacity_opts)
      end

    report(result)
  end

  defp validate_via_emitter(run_id, opts) do
    capacity_opts = if opts[:capacity], do: [capacity: opts[:capacity]], else: []

    case RunValidation.emit_log(run_id) do
      {:ok, log} ->
        report(RunValidation.validate_run(run_id, log, capacity_opts))

      {:error, :no_emitter} ->
        Mix.raise(
          "REFUSED_NO_EMITTER: no OCEL log emitter is configured for run-id input " <>
            "(config :xaas, :ultracode_ocel_log_emitter; expected a module exporting emit/1). " <>
            "The run-to-log projection is the OCEL emitter's owned mutation and is not re-derived " <>
            "here. Pass the log path instead: mix xaas.run_validate <log_path> --run-id #{run_id}"
        )

      {:error, reason} ->
        Mix.raise("emitter failed for run #{run_id}: #{inspect(reason)}")
    end
  end

  defp report(%{verdict: :validated} = result) do
    Mix.shell().info("run validation: VALIDATED#{run_suffix(result)}")
    Mix.shell().info(accounting(result))
  end

  defp report(%{verdict: :not_validated} = result) do
    Mix.shell().error("run validation: NOT_VALIDATED#{run_suffix(result)}")

    Enum.each(result.violations, fn v ->
      Mix.shell().error("  [#{v.code}] #{v.message}")
    end)

    Mix.shell().error(accounting(result))

    System.halt(1)
  end

  defp run_suffix(%{run_id: run_id}) when is_binary(run_id), do: " (run #{run_id})"
  defp run_suffix(_), do: ""

  defp accounting(result) do
    in_flight =
      case result.max_in_flight do
        nil -> "no claims in log"
        n -> "#{n} (capacity #{result.capacity})"
      end

    epochs =
      result.epochs
      |> Enum.sort_by(fn {_id, acc} -> acc.claimed_at || "~" end)
      |> Enum.map_join("\n", fn {id, acc} ->
        terminal =
          case acc.terminal do
            nil -> "NO TERMINAL"
            t -> "#{t.verification} (#{t.event_id})"
          end

        "  epoch #{id}: claimed_at=#{acc.claimed_at || "NEVER"} terminal=#{terminal}"
      end)

    "epochs: #{map_size(result.epochs)}\n#{epochs}\nmax workers in flight: #{in_flight}"
  end
end
