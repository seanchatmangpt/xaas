defmodule Mix.Tasks.Xaas.OcelValidate do
  @shortdoc "Validates an OCEL 2.0 event log (exit 0 valid / 1 invalid)"

  @moduledoc """
  Runs the OCEL 2.0 conformance court (`Xaas.Ultracode.Ocel.Validator` -- see
  that module's moduledoc for the full enforced law) over a real log file and
  turns the verdict into a real process exit code, so it is directly usable as
  a CI gate and as the fabric's independent judge of ultracode run results.

  Usage:

      mix xaas.ocel_validate <path> [--quiet]

  Exit behavior:

    * valid log   -- prints `"<path>: valid (N events, M objects)"` and exits 0.
    * invalid log -- prints one line per violation (exact JSON path + reason)
      to stderr and exits 1.
    * unreadable file / malformed JSON / bad usage -- the same fail-closed
      violations path (or a usage message) and exit 1.

  `--quiet` suppresses all output for CI use; the exit code alone carries the
  verdict.

  Deliberately does NOT run `app.start`: the court is a pure module (no repo,
  no config, no DB), so this task is fast and environment-independent.

  This task is proven by a real subprocess test
  (test/mix/tasks/xaas_ocel_validate_test.exs, tagged `:subprocess`) and by
  out-of-test witness runs; standing comes only from observed execution.
  """

  use Mix.Task

  alias Xaas.Ultracode.Ocel.Validator

  @impl Mix.Task
  def run(args) do
    {opts, argv, invalid} = OptionParser.parse(args, strict: [quiet: :boolean])

    cond do
      invalid != [] ->
        usage_error("unknown options: #{inspect(invalid)}")

      length(argv) != 1 ->
        usage_error("expected exactly one <path> argument")

      true ->
        court(argv, Keyword.get(opts, :quiet, false))
    end
  end

  defp court([path], quiet) do
    case Validator.validate_file(path) do
      {:ok, report} ->
        unless quiet do
          Mix.shell().info(
            "#{path}: valid (#{report["event_count"]} events, #{report["object_count"]} objects)"
          )
        end

      {:error, violations} ->
        unless quiet do
          Enum.each(violations, fn violation ->
            Mix.shell().error("#{violation.path} #{violation.reason}")
          end)
        end

        System.halt(1)
    end
  end

  defp usage_error(message) do
    Mix.shell().error(
      "mix xaas.ocel_validate: #{message}\n" <> "usage: mix xaas.ocel_validate <path> [--quiet]"
    )

    System.halt(1)
  end
end
