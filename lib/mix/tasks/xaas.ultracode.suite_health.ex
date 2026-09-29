defmodule Mix.Tasks.Xaas.Ultracode.SuiteHealth do
  @shortdoc "Runs the verifier-suite health court (green passes, red fails) and quarantines drift"

  @moduledoc """
  On-demand / cron surface of the suite health court
  (`Xaas.Ultracode.SuiteHealth`).

      mix xaas.ultracode.suite_health                 # re-check quarantined / soon-stale suites
      mix xaas.ultracode.suite_health --force         # re-check every managed suite now
      mix xaas.ultracode.suite_health --suite NAME    # only NAME (repeatable)
      mix xaas.ultracode.suite_health --status        # read-only: report standing, run nothing
      mix xaas.ultracode.suite_health --json          # one JSON object per suite on stdout
      mix xaas.ultracode.suite_health --strict        # also fail on unmanaged suites

  For every registered suite that declares a `health` block, the court runs the
  suite against its known-green fixture (must pass) and its known-red fixture
  (must fail) and records a sealed receipt in
  `config :xaas, :ultracode_suite_health_dir`. A suite whose latest receipt is
  stale, red, or bound to a different definition is QUARANTINED: Run admission
  and `Verifier.run/2` refuse it with typed `suite_unhealthy` until this court
  records a healthy result. There is no unquarantine command; re-running this
  task (or the next `Autonomic` wave, which sweeps first) is the only way out.

  Exit status is non-zero when any managed suite is quarantined after the run
  (and, with `--strict`, when any suite is unmanaged), so a cron/launchd
  wrapper pages on drift without parsing output.

  Loads configuration and code but never starts the application (no Repo, no
  Oban): the court is filesystem, git and subprocesses only.
  """

  use Mix.Task

  alias Xaas.Ultracode.{SuiteHealth, Verifier}

  @impl Mix.Task
  def run(args) do
    {opts, _rest, invalid} =
      OptionParser.parse(args,
        strict: [
          suite: :keep,
          force: :boolean,
          status: :boolean,
          json: :boolean,
          strict: :boolean
        ]
      )

    unless invalid == [], do: Mix.raise("invalid arguments: #{inspect(invalid)}")

    # Config + compile + code path, WITHOUT app.start.
    Mix.Task.run("app.config")

    names = Keyword.get_values(opts, :suite)
    names = if names == [], do: nil, else: names

    rows =
      if opts[:status] do
        report(names)
      else
        SuiteHealth.sweep(suites: names, force: opts[:force] || false)
      end

    Enum.each(rows, &emit(&1, opts[:json] || false))

    quarantined = for %{status: {:quarantined, _}, suite: suite} <- rows, do: suite
    unmanaged = for %{status: :unmanaged, suite: suite} <- rows, do: suite

    cond do
      quarantined != [] ->
        Mix.raise("quarantined suites: #{Enum.join(quarantined, ", ")}")

      opts[:strict] && unmanaged != [] ->
        Mix.raise("unmanaged suites (no health declaration): #{Enum.join(unmanaged, ", ")}")

      true ->
        :ok
    end
  end

  defp report(names) do
    Enum.map(names || Verifier.suite_names(), fn name ->
      case Verifier.suite(name) do
        {:ok, suite} ->
          %{suite: name, action: :status, status: SuiteHealth.status(name, suite), verdict: nil}

        :error ->
          %{suite: name, action: :unknown, status: {:quarantined, :unknown_suite}, verdict: nil}
      end
    end)
  end

  defp emit(row, true) do
    Mix.shell().info(
      Jason.encode!(%{
        suite: row.suite,
        action: row.action,
        status: status_string(row.status),
        verdict: row.verdict
      })
    )
  end

  defp emit(row, false) do
    verdict = if row.verdict, do: "  verdict=#{row.verdict}", else: ""

    Mix.shell().info(
      "#{row.suite}  [#{status_string(row.status)}]  action=#{row.action}#{verdict}"
    )
  end

  defp status_string(:healthy), do: "healthy"
  defp status_string(:unmanaged), do: "unmanaged"
  defp status_string({:quarantined, reason}), do: "quarantined:" <> inspect(reason)
end
