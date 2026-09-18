defmodule Mix.Tasks.Xaas.Autonomic.Run do
  @shortdoc "Runs the autonomic Chicago-TDD definition-of-done loop over a registered repository"

  @moduledoc """
  The single trigger for `Xaas.Ultracode.Autonomic`: sense a backlog at an exact
  sha, dispatch leased workers, let the fabric's verifier decide done, repair,
  promote into a local integration branch, verify it, and write the terminal
  receipt. Nothing is pushed; there are no prompts.

      mix xaas.autonomic.run --repo aps
      mix xaas.autonomic.run --repo aps --only contract-standing --capacity 2

  Options: `--repo ALIAS` (default `aps`), `--base-sha SHA`, `--only a,b`,
  `--capacity N`, `--max-attempts N`. Repos come from
  `config :xaas, :ultracode_repos`; suites from
  `config :xaas, :ultracode_verifier_suites`.
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [
          repo: :string,
          base_sha: :string,
          only: :string,
          capacity: :integer,
          max_attempts: :integer
        ]
      )

    Mix.Task.run("app.start")

    run_opts =
      [
        repo: Keyword.get(opts, :repo, "aps"),
        base_sha: opts[:base_sha],
        only: opts[:only] && String.split(opts[:only], ",", trim: true),
        capacity: opts[:capacity] || 6,
        max_attempts: opts[:max_attempts] || 3
      ]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    case Xaas.Ultracode.Autonomic.run(run_opts) do
      {:ok, report} ->
        Mix.shell().info("standing: #{report["standing"]}")

        for item <- report["items"] do
          Mix.shell().info("  #{item["item"]}: #{item["status"]} (attempts #{item["attempts"]})")
        end

        Mix.shell().info("integration: #{inspect(report["integration"])}")
        Mix.shell().info("canonical: #{report["canonical"]["status"]}")
        Mix.shell().info("receipt: #{report["receipt_path"]}")

      {:error, reason} ->
        Mix.raise("autonomic run failed: #{inspect(reason)}")
    end
  end
end
