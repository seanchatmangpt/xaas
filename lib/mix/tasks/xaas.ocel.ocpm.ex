defmodule Mix.Tasks.Xaas.Ocel.Ocpm do
  @shortdoc "OCPM object-type interactions and activity frequency over an OCEL 2.0 JSON file"

  @moduledoc """
  Computes OCPM object-type interactions and per-object-type activity
  frequency over one OCEL 2.0 JSON log -- e.g. a document exported by
  `mix xaas.ultracode.export_ocel` -- and prints a deterministic JSON
  report. See `Xaas.Ocel.Ocpm`'s moduledoc for the primitives, the
  document shape, and the honest bound (interaction/frequency analysis
  only; no object-centric Petri net synthesis).

  Usage:

      mix xaas.ocel.ocpm <path.ocel.json>

  Output: one JSON document on stdout:

      {"object_type_activity_frequency": [...],
       "object_type_interactions": [...]}

  Exit behavior (the `mix xaas.ocel_validate` fail-closed convention):
  exits 0 on success; exits 1 on an unreadable file, malformed JSON, a
  decoded body that is not a JSON object, or bad usage.

  Deliberately does NOT run `app.start`: the computation is a pure module
  (no repo, no config, no DB), so this task is fast and
  environment-independent.
  """

  use Mix.Task

  alias Xaas.Ocel.Ocpm

  @impl Mix.Task
  def run(args) do
    case args do
      [path] -> report(path)
      _ -> usage_error("expected exactly one <path> argument")
    end
  end

  defp report(path) do
    case File.read(path) do
      {:ok, body} ->
        case JSON.decode(body) do
          {:ok, %{} = document} ->
            Mix.shell().info(JSON.encode!(Ocpm.report(document)))

          {:ok, _other} ->
            fail("not an OCEL 2.0 document: #{path} is valid JSON but not a JSON object")

          {:error, reason} ->
            fail("malformed JSON in #{path}: #{inspect(reason)}")
        end

      {:error, reason} ->
        fail("cannot read file #{path}: #{inspect(reason)}")
    end
  end

  defp fail(message) do
    Mix.shell().error("mix xaas.ocel.ocpm: #{message}")
    System.halt(1)
  end

  defp usage_error(message) do
    Mix.shell().error(
      "mix xaas.ocel.ocpm: #{message}\n" <> "usage: mix xaas.ocel.ocpm <path.ocel.json>"
    )

    System.halt(1)
  end
end
