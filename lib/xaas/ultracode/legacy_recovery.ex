defmodule Xaas.Ultracode.LegacyRecovery do
  @moduledoc """
  Adapter from a beam4pm legacy-equivalence court report into deterministic
  Ultracode work items.

  EQUIVALENT reports yield no repair work. COUNTEREXAMPLE reports yield one
  bounded work item per concrete counterexample. The adapter never upgrades
  standing and never performs actuation; it only makes semantic uncertainty
  schedulable by the existing XaaS fabric.
  """

  @schema "beam4pm-legacy-equivalence/1"
  @digest_re ~r/\A[0-9a-f]{64}\z/

  @spec items(String.t(), String.t(), [String.t()]) :: {:ok, [map()]} | {:error, term()}
  def items(root, report_file, allowed_paths)
      when is_binary(root) and is_binary(report_file) and is_list(allowed_paths) do
    with :ok <- safe_relative(report_file),
         {:ok, bytes} <- File.read(Path.join(root, report_file)),
         {:ok, report} <- Jason.decode(bytes),
         :ok <- admit_report(report) do
      {:ok, build_items(report, report_file, allowed_paths)}
    else
      {:error, %Jason.DecodeError{} = error} -> {:error, {:invalid_legacy_court_json, error}}
      {:error, reason} -> {:error, reason}
    end
  end

  def items(_root, _report_file, _allowed_paths), do: {:error, :invalid_legacy_recovery_args}

  defp admit_report(%{
         "schema" => @schema,
         "subject" => subject,
         "receipt_digest" => digest,
         "authority_ceiling" => "OBSERVE",
         "equivalent" => equivalent,
         "counterexamples" => counterexamples
       })
       when is_binary(subject) and is_binary(digest) and is_boolean(equivalent) and
              is_list(counterexamples) do
    cond do
      String.trim(subject) == "" -> {:error, :legacy_court_empty_subject}
      not Regex.match?(@digest_re, digest) -> {:error, :legacy_court_bad_receipt_digest}
      equivalent and counterexamples != [] -> {:error, :legacy_court_contradictory_equivalence}
      not equivalent and counterexamples == [] -> {:error, :legacy_court_missing_counterexample}
      true -> :ok
    end
  end

  defp admit_report(%{"schema" => schema}) when schema != @schema,
    do: {:error, {:unsupported_legacy_court_schema, schema}}

  defp admit_report(_report), do: {:error, :malformed_legacy_court_report}

  defp build_items(%{"equivalent" => true}, _file, _allowed_paths), do: []

  defp build_items(report, file, allowed_paths) do
    subject = report["subject"]
    receipt = report["receipt_digest"]

    report["counterexamples"]
    |> Enum.with_index()
    |> Enum.map(fn {counterexample, index} ->
      id = "legacy-#{index}-#{String.slice(receipt, 0, 12)}"
      encoded = counterexample |> canonicalize() |> Jason.encode!()

      %{
        "id" => id,
        "goal" =>
          [
            "Repair the exact legacy-equivalence counterexample for subject #{inspect(subject)}.",
            "Court receipt: #{receipt}.",
            "Counterexample index: #{index}.",
            "Do not weaken the court, delete the witness, or change admitted semantics merely to make the comparison pass.",
            "After repair, remanufacture and rerun the beam4pm equivalence court against the same legacy identity.",
            "Counterexample: #{encoded}"
          ]
          |> Enum.join("\n"),
        "allowed_paths" => allowed_paths,
        "min_new_tests" => 1,
        "min_kill_ratio" => nil,
        "mutants" => [],
        "source" => %{
          "file" => file,
          "line" => nil,
          "text" => encoded,
          "subject" => subject,
          "court_receipt" => receipt,
          "counterexample_index" => index
        }
      }
    end)
  end

  defp safe_relative(path) do
    parts = Path.split(path)

    if path == "" or Path.type(path) == :absolute or ".." in parts do
      {:error, {:legacy_report_path_must_be_relative, path}}
    else
      :ok
    end
  end

  defp canonicalize(value) when is_map(value) do
    value
    |> Enum.map(fn {k, v} -> {to_string(k), canonicalize(v)} end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Map.new()
  end

  defp canonicalize(value) when is_list(value), do: Enum.map(value, &canonicalize/1)
  defp canonicalize(value), do: value
end
