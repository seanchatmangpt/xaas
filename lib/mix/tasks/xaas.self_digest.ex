defmodule Mix.Tasks.Xaas.SelfDigest do
  @shortdoc "Digests wave-loop telemetry and admits recurring frontier clusters as UltraCode self-work"

  @moduledoc """
  Runs `Xaas.Ultracode.SelfDigestWorker.run/1` (the same path the daily
  Oban cron takes) and prints the JSON self-digest receipt.

  Usage:

      mix xaas.self_digest
      mix xaas.self_digest --telemetry tmp/w8-loop/loop.ndjson --window 1440
      mix xaas.self_digest --out-dir tmp/self-digest --no-admit

  Exit behavior (this repo's typed-refusal convention): a digest refusal
  (unconfigured/unreadable telemetry, failed work-order admission) prints
  the typed reason and raises -- non-zero exit.
  """

  use Mix.Task

  alias Xaas.Ultracode.SelfDigestWorker

  @switches [telemetry: :string, out_dir: :string, window: :integer, admit: :boolean]

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")

    {parsed, _rest, _invalid} = OptionParser.parse(argv, strict: @switches)

    args =
      %{}
      |> put_arg("telemetry_path", parsed[:telemetry])
      |> put_arg("out_dir", parsed[:out_dir])
      |> put_arg("window_minutes", parsed[:window])
      |> put_arg("admit", parsed[:admit])

    case SelfDigestWorker.run(args) do
      {:ok, summary} ->
        Mix.shell().info(Jason.encode!(summary, pretty: true))

      {:error, reason} ->
        Mix.shell().error(refusal_json(reason))
        Mix.raise("xaas.self_digest refused: #{inspect(reason)}")
    end
  end

  defp refusal_json(reason) do
    render_refusal({:self_digest, %{reason: inspect(reason)}})
    |> then(&Jason.encode!(%{"refused" => inspect(reason), "refusal_code" => &1}))
  end

  @doc """
  Renders this task's typed-refusal line (Vector-2 §E): the machine-readable
  `REFUSED(<code>, detail: %{...})` form. Emitted as the additive JSON key
  `"refusal_code"` alongside the pre-existing `"refused"` shape, so existing
  consumers are unaffected.
  """
  def render_refusal({code, detail}) when is_atom(code) do
    "REFUSED(#{code}, detail: #{inspect(detail)})"
  end

  defp put_arg(args, _key, nil), do: args
  defp put_arg(args, key, value), do: Map.put(args, key, value)
end
