defmodule Mix.Tasks.Xaas.Semantic.Crown do
  @shortdoc "Autonomics crown: receipts as the clock, end to end, with negative controls"

  @moduledoc """
  Runs `Xaas.Ultracode.SemanticCrown`: observation -> admitted WorkOrder ->
  frontier -> descriptor -> Run/Epoch -> worker -> fabric court -> receipt ->
  ledger transition -> newly eligible dependent, then a fresh-process replay.

      INTERNAL_API_TOKEN=... mix xaas.semantic.crown \\
        --ggen-igniter-dir /path/to/ggen_igniter [--live] [--controls]

    * default worker: the hardened dispatcher in directed `--epoch` mode
      (a real zcode/GLM worker). It needs the running XaaS server (endpoint
      below) with the `aps-dod` suite registered and the plugin installed.
    * `--controls`: closes a crafted vacuous-test candidate over the real HTTP
      MCP surface (needs `INTERNAL_API_TOKEN`) and requires the reconciler to
      refuse it.
    * `--endpoint URL` (default `http://localhost:4000/internal-api/execution/mcp`),
      `--work-dir DIR`, `--items A,B`, `--repo ALIAS`, `--base-sha SHA`,
      `--mix-env ENV` (env of the graph-side `mix` processes, default `test`),
      `--max-attempts N`.

  `--live` is accepted for readability; the real worker is the default. The
  token is read from the environment at run time and never written anywhere.
  Exits non-zero unless the crown standing is ALIVE.
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [
          ggen_igniter_dir: :string,
          work_dir: :string,
          items: :string,
          repo: :string,
          base_sha: :string,
          mix_env: :string,
          max_attempts: :integer,
          endpoint: :string,
          controls: :boolean,
          live: :boolean
        ]
      )

    dir = opts[:ggen_igniter_dir] || Mix.raise("--ggen-igniter-dir DIR is required")
    Mix.Task.run("app.start")
    {:ok, _} = Application.ensure_all_started(:inets)

    run_opts =
      [
        ggen_igniter_dir: dir,
        work_dir: opts[:work_dir],
        items: opts[:items] && String.split(opts[:items], ",", trim: true),
        repo: opts[:repo],
        base_sha: opts[:base_sha],
        mix_env: opts[:mix_env],
        max_attempts: opts[:max_attempts],
        controls: if(opts[:controls], do: http(opts))
      ]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)

    case Xaas.Ultracode.SemanticCrown.run(run_opts) do
      {:ok, report} ->
        Mix.shell().info("standing: #{report["standing"]}")

        for cycle <- report["cycles"] do
          Mix.shell().info(
            "  #{cycle["identity"]}: #{cycle["status"]} executor=#{cycle["executor"]} " <>
              "outcome=#{cycle["outcome"]} verifier=#{cycle["fabric_verifier"]}"
          )
        end

        Mix.shell().info("final standings: #{inspect(report["final_standings"])}")
        Mix.shell().info("replay equal: #{report["replay"]["equal"]}")
        if report["controls"], do: Mix.shell().info("control pass: #{report["controls"]["pass"]}")
        Mix.shell().info("report: #{report["report_path"]}")
        if report["standing"] != "ALIVE", do: Mix.raise("crown standing #{report["standing"]}")

      {:error, reason} ->
        Mix.raise("crown failed: #{inspect(reason)}")
    end
  end

  defp http(opts) do
    token = System.get_env("INTERNAL_API_TOKEN") || Mix.raise("INTERNAL_API_TOKEN is required")

    %{
      transport: :http,
      endpoint: opts[:endpoint] || "http://localhost:4000/internal-api/execution/mcp",
      token: token
    }
  end
end
