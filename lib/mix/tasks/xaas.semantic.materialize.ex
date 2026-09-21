defmodule Mix.Tasks.Xaas.Semantic.Materialize do
  @shortdoc "Materialize one semantic-work descriptor into a Run and a leasable Epoch"

  @moduledoc """
  Reads a semantic-work descriptor (JSON, as printed by
  `mix semantic_jira.descriptor`) and materializes it through
  `Xaas.Ultracode.SemanticWork.materialize/2`: an exact-SHA worktree, one Run,
  one started Epoch. The descriptor's `bridge` object is stored on the Run and
  never interpreted.

      mix xaas.semantic.materialize --descriptor descriptor.json [--ticket-file ticket.json]

  `--ticket-file` copies a definition-of-done ticket to
  `<ticket_dir>/<run_id>.json`, the location suites that use the `{ticket}`
  placeholder read from. Prints one JSON object: `run_id`, `epoch_id`,
  `worktree`. A refusal prints the typed reason and exits non-zero.
  """

  use Mix.Task

  alias Xaas.Ultracode.SemanticWork

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [descriptor: :string, ticket_file: :string, help: :boolean]
      )

    if opts[:help] do
      Mix.shell().info(Mix.Task.moduledoc(__MODULE__))
    else
      materialize(opts)
    end
  end

  defp materialize(opts) do
    path = opts[:descriptor] || Mix.raise("--descriptor PATH is required")
    Mix.Task.run("app.start")

    descriptor = path |> File.read!() |> Jason.decode!()

    case SemanticWork.materialize(descriptor) do
      {:ok, %{run: run, epoch: epoch, worktree: worktree}} ->
        if opts[:ticket_file], do: copy_ticket(opts[:ticket_file], run.id)

        Mix.shell().info(Jason.encode!(%{run_id: run.id, epoch_id: epoch.id, worktree: worktree}))

      {:error, reason} ->
        Mix.raise("materialize refused: #{inspect(reason)}")
    end
  end

  defp copy_ticket(source, run_id) do
    dir = Application.fetch_env!(:xaas, :ultracode_ticket_dir)
    File.mkdir_p!(dir)
    File.cp!(source, Path.join(dir, "#{run_id}.json"))
  end
end
