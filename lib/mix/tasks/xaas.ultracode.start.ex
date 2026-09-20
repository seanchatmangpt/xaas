defmodule Mix.Tasks.Xaas.Ultracode.Start do
  @shortdoc "Starts the bounded ultracode wave campaign (8-hour capacity-5 standing wave)"

  @moduledoc """
  The single command that starts the operator-ordered ultracode run:
  a budget-law-governed campaign of serial autonomic waves. See
  `Xaas.Ultracode.Campaign` for the budget law and the campaign row
  lifecycle; every wave is one `Xaas.Ultracode.Autonomic.run/1` pass
  (sense -> dispatch -> fabric verify -> promote -> receipt).

      mix xaas.ultracode.start
      mix xaas.ultracode.start --capacity 5 --duration 8h --wave-interval 30m
      mix xaas.ultracode.start --capacity 2 --duration 10m --wave-interval 5m \\
        --max-waves 2 --only contract-standing

  Options (defaults are the operator's standing order):

    * `--capacity N` -- workers per wave (default 5)
    * `--duration D` -- wall-clock budget, `<n>h|m|s` (default 8h)
    * `--wave-interval D` -- slot grid for waves, `<n>h|m|s` (default 30m)
    * `--max-waves N` -- optional cap on the wave-count budget
      (default: ceil(duration / interval))
    * `--goal TEXT` -- campaign goal text (default: generated standing-order text)
    * `--repo SPEC` -- one registered alias (`aps`), a comma-separated
      list (`alpha,beta`), or `all` (every registered alias, sorted).
      Multi-repo campaigns draw each wave's items across the selected
      repos with the deterministic WavePlan rotation; per-repo wave caps
      via `config :xaas, :ultracode_wave_repo_caps` (default `aps`)
    * `--suite NAME` -- registered verifier suite (default `aps-dod`; the name
      is admission-validated against `config :xaas, :ultracode_verifier_suites`)
    * `--only a,b` -- restrict waves to these backlog item ids (bounded smokes)
    * `--max-attempts N` -- per-item repair attempts per wave (default 3)
    * `--base-sha SHA` -- pin the backlog/worktree base (default: repo HEAD)
    * `--run ID` -- resume an abandoned-slot campaign row (waves already
      discharged are not repeated; budgets are read from the row)

  Prints the campaign run id and its ledger path, then one line per wave as
  it completes, then the terminal summary. The command runs synchronously
  until a budget discharges or `mix xaas.ultracode.stop` lands.
  """

  use Mix.Task

  alias Xaas.Ultracode.Campaign

  @impl Mix.Task
  def run(args) do
    {opts, _rest, invalid} =
      OptionParser.parse(args,
        strict: [
          capacity: :integer,
          duration: :string,
          wave_interval: :string,
          max_waves: :integer,
          goal: :string,
          repo: :string,
          suite: :string,
          only: :string,
          max_attempts: :integer,
          base_sha: :string,
          run: :string
        ]
      )

    Mix.Task.run("app.start")

    unless invalid == [] do
      Mix.raise("invalid arguments: #{inspect(invalid)}")
    end

    campaign_opts =
      [
        capacity: opts[:capacity],
        duration: opts[:duration],
        wave_interval: opts[:wave_interval],
        max_waves: opts[:max_waves],
        goal: opts[:goal],
        repo: opts[:repo],
        suite: opts[:suite],
        only: opts[:only] && String.split(opts[:only], ",", trim: true),
        max_attempts: opts[:max_attempts],
        base_sha: opts[:base_sha],
        run_id: opts[:run]
      ]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    case Campaign.start(campaign_opts) do
      {:ok, summary} ->
        Mix.shell().info("campaign run: #{summary.run_id}")
        Mix.shell().info("ledger:      #{summary.ledger}")
        Mix.shell().info("status:      mix xaas.ultracode.status --run #{summary.run_id}")
        Mix.shell().info("stop:        mix xaas.ultracode.stop --run #{summary.run_id}")

        for wave <- Map.get(summary, :waves, []) do
          Mix.shell().info(
            "wave #{wave.wave}: #{wave.standing || "error"} #{wave.receipt || wave.error}"
          )
        end

        Mix.shell().info(
          "#{summary.status} after #{summary.waves_executed} wave(s); standing #{summary.standing || "n/a"}"
        )

      {:error, reason} ->
        Mix.raise("campaign refused: #{format_error(reason)}")
    end
  end

  defp format_error(reason) when is_tuple(reason) and is_atom(elem(reason, 0)) do
    Enum.map_join(Tuple.to_list(reason), " ", &to_string/1)
  end

  defp format_error(reason), do: inspect(reason)
end
