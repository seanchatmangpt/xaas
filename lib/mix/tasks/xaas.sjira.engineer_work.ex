defmodule Mix.Tasks.Xaas.Sjira.EngineerWork do
  use Mix.Task
  alias Xaas.Sjira.EngineerWorkflow
  alias Xaas.Sjira.EngineerWorkflow.Codec

  @shortdoc "Project admitted semantic work into provider-neutral engineer work"
  @switches [output: :string, provider: :string, project: :string, queue: :string,
             assignee: :string, label: :keep, commands: :boolean, pretty: :boolean,
             max_attempts: :integer, backoff_ms: :integer, max_backoff_ms: :integer]

  @impl Mix.Task
  def run(args) do
    {opts, files, invalid} = OptionParser.parse(args, strict: @switches)

    cond do
      invalid != [] -> Mix.raise("invalid options: #{inspect(invalid)}")
      length(files) != 1 -> Mix.raise("usage: mix xaas.sjira.engineer_work INPUT [options]")
      true ->
        [input] = files
        with {:ok, bytes} <- File.read(input),
             {:ok, rows} <- decode_input(bytes),
             {:ok, envelopes} <- EngineerWorkflow.project_many(rows, projection_opts(opts)) do
          rows = if opts[:commands], do: Enum.map(envelopes, &EngineerWorkflow.upsert_command/1), else: envelopes
          write(encode_output(rows, opts), opts[:output])
        else
          {:error, reason} -> Mix.raise("cannot read #{input}: #{inspect(reason)}")
          {:refused, reason, detail} -> Mix.raise("REFUSED(#{reason}): #{inspect(detail)}")
        end
    end
  end

  defp decode_input(bytes) do
    case Jason.decode(bytes) do
      {:ok, list} when is_list(list) -> {:ok, list}
      {:ok, %{} = map} -> {:ok, [map]}
      {:ok, other} -> {:refused, :input_not_work_collection, other}
      {:error, _} -> decode_jsonl(bytes)
    end
  end

  defp decode_jsonl(bytes) do
    bytes
    |> String.split("\n", trim: true)
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, []}, fn {line, number}, {:ok, acc} ->
      case Jason.decode(line) do
        {:ok, %{} = row} -> {:cont, {:ok, [row | acc]}}
        {:ok, other} -> {:halt, {:refused, :jsonl_row_not_object, %{line: number, value: other}}}
        {:error, error} -> {:halt, {:refused, :invalid_jsonl, %{line: number, error: Exception.message(error)}}}
      end
    end)
    |> case do
      {:ok, rows} -> {:ok, Enum.reverse(rows)}
      refusal -> refusal
    end
  end

  defp projection_opts(opts), do: [
    provider: opts[:provider], project: opts[:project], queue: opts[:queue],
    assignee: opts[:assignee], labels: Keyword.get_values(opts, :label),
    max_attempts: opts[:max_attempts], backoff_ms: opts[:backoff_ms],
    max_backoff_ms: opts[:max_backoff_ms]
  ]

  defp encode_output(rows, opts) do
    if opts[:pretty], do: Codec.encode_pretty(rows),
      else: IO.iodata_to_binary(Enum.map(rows, &[Codec.encode(&1), "\n"]))
  end

  defp write(bytes, nil), do: IO.write(bytes)
  defp write(bytes, path) do
    path = Path.expand(path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, bytes)
  end
end
