defmodule Mix.Tasks.Xaas.Autonomy.ExportOcel do
  @shortdoc "Exports an Ultracode episode as CONTRACT-vocabulary OCEL 2.0 ndjson"

  @moduledoc """
  Emits one episode (`Xaas.Ultracode.Run` + its Epochs/Receipts) as an OCEL
  2.0 ndjson log in the CONTRACT vocabulary (`Xaas.Ultracode.AutonomyEgress`:
  the aloop object/event/qualifier names, RECONSTRUCTED events marked), one
  complete OCEL 2.0 document per line.

      mix xaas.autonomy.export_ocel <run_id>
      mix xaas.autonomy.export_ocel <run_id> --out /tmp/ocel

  Default output DIR: `priv/ocel/autonomy` (file:
  `<dir>/<run_id>.ocel.ndjson`); `--out` names the output DIRECTORY, the
  same convention as `mix xaas.ultracode.export_ocel`. Unlike the
  per-Run JSON export (`mix xaas.ultracode.export_ocel`), this surface is the
  process-mining projection the CONTRACT names: episode-scoped, ndjson, and
  honest about which events are derived inferences.

  Exit behavior (the repo's typed-refusal convention): an unknown Run id
  raises with a typed `:run_not_found`.
  """

  use Mix.Task

  alias Xaas.Ultracode.AutonomyEgress

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, positional} = OptionParser.parse!(args, strict: [out: :string])

    case positional do
      [run_id] ->
        case AutonomyEgress.export_episode(run_id, opts[:out] || AutonomyEgress.default_out_dir()) do
          {:ok, path} ->
            Mix.shell().info(path)

          {:error, :run_not_found} ->
            Mix.raise(
              "episode OCEL export refused: :run_not_found -- no Xaas.Ultracode.Run #{inspect(run_id)}"
            )

          {:error, reason} ->
            Mix.raise("episode OCEL export failed: #{inspect(reason)}")
        end

      _ ->
        Mix.raise("usage: mix xaas.autonomy.export_ocel <run_id> [--out PATH]")
    end
  end
end
