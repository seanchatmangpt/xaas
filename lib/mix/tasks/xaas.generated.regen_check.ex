defmodule Mix.Tasks.Xaas.Generated.RegenCheck do
  @shortdoc "SPEC-34: regen-based drift check for generated surfaces (exit 0 clean, 4 drift)."
  @moduledoc """
  Runs `Xaas.Generated.RegenCheck.check/1`: re-runs each in-repo generator and
  compares fresh output against the tracked bytes; disclosed-skips surfaces
  whose regen toolchain lives outside the repo.

      mix xaas.generated.regen_check            # human report
      mix xaas.generated.regen_check --json     # machine report

  Exit codes follow the `GgenIgniter.TaskContract` drift vocabulary:
  0 = clean, 4 = drift (BLOCKED). Any `{:drift, detail}` prints the detail and
  the named repair regen command.
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: [json: :boolean])

    report = Xaas.Generated.RegenCheck.check()

    if opts[:json] do
      envelope = %{
        schema_version: 1,
        task: "xaas.generated.regen_check",
        ok: Xaas.Generated.RegenCheck.clean?(report),
        exit_code: Xaas.Generated.RegenCheck.exit_code(report),
        data: %{surfaces: report}
      }

      IO.puts(Jason.encode!(envelope))
    else
      Enum.each(Enum.sort(report), fn {path, verdict} ->
        case verdict do
          :ok -> IO.puts("OK       #{path}")
          {:skipped, reason} -> IO.puts("SKIP     #{path} — #{reason}")
          {:drift, detail} -> IO.puts("DRIFT    #{path}\n  #{detail}")
        end
      end)
    end

    exit_with(Xaas.Generated.RegenCheck.exit_code(report))
  end

  defp exit_with(0), do: :ok
  defp exit_with(code), do: System.halt(code)
end
