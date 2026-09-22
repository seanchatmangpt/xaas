defmodule Mix.Tasks.Xaas.Ultracode.OcelConformance do
  @shortdoc "Batch OCEL 2.0 conformance court over a whole campaign's runs"

  @moduledoc """
  Validates the OCEL 2.0 log of EVERY run a campaign ledger names (each
  `attempt_start` run, plus the campaign row itself), through the real
  production pair (`Xaas.Ultracode.OcelEgress.export_run/2` then
  `Xaas.Ultracode.Ocel.Validator.validate_file/1`) into throwaway
  tmpdirs. The standing-capability form of the run-by-run
  `export_ocel` -> `ocel_validate` pair. See
  `Xaas.Ultracode.OcelConformance` for the court discipline (judged
  violations vs refusal-to-judge, bounded tmpdir, deterministic
  `:max_runs` prefix order).

  Usage:

      mix xaas.ultracode.ocel_conformance --campaign <ID> [--max-runs N]
      mix xaas.ultracode.ocel_conformance --run <run-id>

  Output: one line per judged run (`valid (events=N objects=M)` or the
  named violations) and one summary line `N/N valid`, then
  `conformance: CONFORMANT` or `conformance: VIOLATIONS (...)`.

  Exit codes (fail-closed): 0 only when EVERY judged run is valid; 1
  when at least one run is judged invalid; 2 when the court could not
  judge at all (unknown/non-campaign id, missing or malformed ledger,
  export failure) -- an infrastructure error, never a verdict.
  """

  use Mix.Task

  alias Xaas.Ultracode.OcelConformance

  @impl Mix.Task
  def run(args) do
    {opts, _rest, invalid} =
      OptionParser.parse(args, strict: [campaign: :string, run: :string, max_runs: :integer])

    Mix.Task.run("app.start")

    campaign = opts[:campaign]
    run_id = opts[:run]

    cond do
      # Exactly one mode is required; unknown switches are refused.
      invalid != [] or (campaign != nil and run_id != nil) or (campaign == nil and run_id == nil) ->
        Mix.raise(
          "usage: mix xaas.ultracode.ocel_conformance --campaign <ID> [--max-runs N] " <>
            "| --run <run-id>"
        )

      run_id != nil ->
        judge_single(run_id)

      true ->
        judge_campaign(campaign, opts[:max_runs])
    end
  end

  # The exit-code mapping is a pure function so the tests can pin the
  # full contract without halting the test VM (this repo's
  # `Mix.Tasks.Xaas.RunValidateTaskTest` precedent: halt paths are
  # observed out-of-test against the real command).
  @doc false
  def exit_status({:ok, :conformant}), do: 0
  def exit_status({:ok, :violations}), do: 1
  def exit_status({:error, _reason}), do: 2

  # ------------------------------------------------------------------
  # Campaign mode
  # ------------------------------------------------------------------

  defp judge_campaign(campaign_id, max_runs) do
    opts = if(max_runs, do: [max_runs: max_runs], else: [])

    case OcelConformance.campaign(campaign_id, opts) do
      {:ok, report} ->
        print_report(report)
        System.halt(exit_status({:ok, report.status}))

      {:error, reason} ->
        Mix.shell().error("conformance: BLOCKED (#{format_error(reason)})")
        System.halt(2)
    end
  end

  # ------------------------------------------------------------------
  # Single-run mode
  # ------------------------------------------------------------------

  defp judge_single(run_id) do
    case OcelConformance.run(run_id) do
      {:ok, result} ->
        print_runs([result])
        Mix.shell().info(summary_line(valid_count([result]), 1))
        System.halt(exit_status({:ok, single_status(result)}))

      {:error, reason} ->
        Mix.shell().error("conformance: BLOCKED (#{format_error(reason)})")
        System.halt(2)
    end
  end

  defp single_status(%{status: :valid}), do: :conformant
  defp single_status(%{status: :violations}), do: :violations

  # ------------------------------------------------------------------
  # Printing
  # ------------------------------------------------------------------

  defp print_report(report) do
    shell = Mix.shell()

    shell.info(
      "campaign: #{report.campaign_id} (named #{report.named}, ledger " <>
        "#{if(report.ledger_present, do: "present", else: "ABSENT")})"
    )

    print_runs(report.runs)

    bounded =
      if report.total < report.named,
        do: " (judged a bounded prefix of #{report.named})",
        else: ""

    shell.info(summary_line(report.valid, report.total) <> bounded)
    shell.info("conformance: #{report.status |> Atom.to_string() |> String.upcase()}")
  end

  defp print_runs(runs) do
    Enum.each(runs, fn
      %{run_id: run_id, status: :valid, events: events, objects: objects} ->
        Mix.shell().info("run #{run_id}: valid (events=#{events} objects=#{objects})")

      %{run_id: run_id, status: :violations, violations: violations} ->
        Mix.shell().info("run #{run_id}: VIOLATIONS (#{length(violations)})")

        Enum.each(violations, fn %{path: path, reason: reason} ->
          Mix.shell().info("  - #{path}: #{reason}")
        end)
    end)
  end

  defp summary_line(valid, total) do
    "#{valid}/#{total} valid" <>
      if(valid == total, do: "", else: " (#{total - valid} run(s) with violations)")
  end

  defp valid_count(runs), do: Enum.count(runs, &(&1.status == :valid))

  defp format_error({:run_export_failed, run_id, reason}),
    do: "OCEL export failed for run #{run_id}: #{inspect(reason)}"

  defp format_error({:not_a_campaign, id}), do: "run #{id} is not a campaign row"
  defp format_error(:campaign_not_found), do: "campaign_not_found"
  defp format_error({:ledger_not_found, path}), do: "ledger not found: #{path}"

  defp format_error({:malformed_ledger, path, line, reason}),
    do: "malformed ledger #{path} line #{line}: #{inspect(reason)}"

  defp format_error({:malformed_ledger_event, event, data}),
    do: "malformed ledger #{event} event: #{inspect(data)}"

  defp format_error({:bad_opt, opt, value}), do: "bad opt #{opt}: #{inspect(value)}"
  defp format_error(reason), do: inspect(reason)
end
