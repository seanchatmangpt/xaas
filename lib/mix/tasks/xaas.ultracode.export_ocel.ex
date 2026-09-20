defmodule Mix.Tasks.Xaas.Ultracode.ExportOcel do
  @shortdoc "Exports Ultracode Runs as OCEL 2.0 JSON logs (one document per Run)"

  @moduledoc """
  Derives OCEL 2.0 object-centric event logs from the persisted Ultracode
  state (`Xaas.Ultracode.Run` / `Epoch` / `Receipt`) and writes one JSON
  document per Run. See `Xaas.Ultracode.OcelEgress`'s moduledoc for the
  full design (derivation hook point, object/event model, determinism
  guarantees, and the honest gap list of declared-but-not-emitted event
  types).

  Usage:

      mix xaas.ultracode.export_ocel <run_id>
      mix xaas.ultracode.export_ocel <run_id> --out /tmp/ocel
      mix xaas.ultracode.export_ocel --all

  Output: `<out-dir>/<run_id>.ocel.json` (default out dir
  `priv/ocel/ultracode`, matching the existing `priv/ocel/` convention
  used by `Xaas.Telemetry.OcelAshEmitter`).

  Exit behavior (this repo's typed-refusal convention, matching
  `mix xaas.ultracode.tick_health`): an unknown Run id raises (non-zero
  exit) with a typed `:run_not_found` message; a successful export prints
  each written path.
  """

  use Mix.Task

  alias Xaas.Ultracode.OcelEgress

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, positional} = OptionParser.parse!(args, strict: [out: :string, all: :boolean])

    out_dir = opts[:out] || OcelEgress.default_out_dir()

    cond do
      opts[:all] ->
        case OcelEgress.export_all(out_dir) do
          {:ok, paths} ->
            Enum.each(paths, fn path -> Mix.shell().info(path) end)

            Mix.shell().info("exported #{length(paths)} OCEL 2.0 document(s) to #{out_dir}")

          {:error, reason} ->
            Mix.raise("OCEL export failed: #{inspect(reason)}")
        end

      [run_id] = positional ->
        case OcelEgress.export_run(run_id, out_dir) do
          {:ok, path} ->
            Mix.shell().info(path)

          {:error, :run_not_found} ->
            Mix.raise(
              "OCEL export refused: :run_not_found -- no Xaas.Ultracode.Run with id " <>
                "#{inspect(run_id)} exists (run `mix xaas.ultracode.export_ocel --all` to export every Run)."
            )

          {:error, reason} ->
            Mix.raise("OCEL export failed: #{inspect(reason)}")
        end

      true ->
        Mix.raise(
          "usage: mix xaas.ultracode.export_ocel <run_id> [--out DIR] | --all [--out DIR]"
        )
    end
  end
end
