defmodule Mix.Tasks.Xaas.Semantic.Materialize do
  @shortdoc "Materialize one semantic-work descriptor into a Run and a leasable Epoch"

  @moduledoc """
  Reads a semantic-work descriptor (JSON, as printed by
  `mix semantic_jira.descriptor`) and materializes it through
  `Xaas.Ultracode.SemanticWork.materialize/2`: an exact-SHA worktree, one Run,
  one started Epoch. The descriptor's `bridge` object is stored on the Run and
  never interpreted.

      mix xaas.semantic.materialize --descriptor descriptor.json \\
        [--ticket-file ticket.json] [--binding auto|snapshot|graph]

  `--ticket-file` copies a definition-of-done ticket to
  `<ticket_dir>/<run_id>.json`, the location suites that use the `{ticket}`
  placeholder read from. Prints one JSON object: `run_id`, `epoch_id`,
  `worktree`. A refusal prints the typed reason and exits non-zero.

  `--binding` declares the producer's digest contract to
  `Xaas.Ultracode.SemanticWork.AdmissionBinding` (the operator declares it,
  never the descriptor): `snapshot` requires `graph_digest` to equal the
  admitted work-order snapshot digest XaaS recomputes/reads from the
  descriptor's own anchors and refuses a descriptor stripped of every anchor;
  `graph` declares `graph_digest` graph-wide (unbound); `auto` (default) binds
  when the descriptor carries an `admitted_work_order`.
  """

  use Mix.Task

  alias Xaas.Ultracode.SemanticWork

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [descriptor: :string, ticket_file: :string, binding: :string, help: :boolean]
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

    case SemanticWork.materialize(descriptor, binding: binding_mode(opts[:binding])) do
      {:ok, %{run: run, epoch: epoch, worktree: worktree}} ->
        if opts[:ticket_file], do: copy_ticket(opts[:ticket_file], run.id)

        Mix.shell().info(Jason.encode!(%{run_id: run.id, epoch_id: epoch.id, worktree: worktree}))

      {:error, reason} ->
        Mix.raise("materialize refused: #{inspect(reason)}")
    end
  end

  # Whitelisted, never String.to_atom/1 on operator input.
  defp binding_mode(nil), do: :auto
  defp binding_mode("auto"), do: :auto
  defp binding_mode("snapshot"), do: :snapshot
  defp binding_mode("graph"), do: :graph

  defp binding_mode(other),
    do: Mix.raise("--binding must be auto, snapshot or graph, got: #{other}")

  defp copy_ticket(source, run_id) do
    dir = Application.fetch_env!(:xaas, :ultracode_ticket_dir)
    File.mkdir_p!(dir)
    File.cp!(source, Path.join(dir, "#{run_id}.json"))
  end
end
