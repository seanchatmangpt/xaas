defmodule Xaas.Zoe.PrivateMeetingInference do
  @moduledoc """
  Private, local-only transcript extraction for ZOE meeting observations.

  This module is a provider adapter, not an admission or actuation boundary.
  It uses Bumblebee/Nx against a `{:local, directory}` repository only and
  returns candidate observations with `CONSTRUCT_ONLY` authority. It never
  calls an external model provider and never dispatches a consequence.

  The resulting candidate is intended to flow into the existing AshA2A
  UNKNOWN/admission machinery and then, if separately authorized, through
  XaaS/BRCE. Model output is evidence-producing input, not policy or DO.
  """

  @statuses ~w(SATISFIED SATISFIED_DIFFERENT_VALID_PATH NOT_OBSERVED PARTIAL CONTRADICTS_MODEL)
  @novel_kinds ~w(
    NEW_REQUIRED_CAPABILITY
    NEW_POLICY_CANDIDATE
    NEW_EXCEPTION_CLASS
    NEW_SYSTEM_OR_CHANNEL
    NEW_ROLE_OR_RESPONSIBILITY
    OTHER_NOVELTY
  )
  @digest ~r/\A[0-9a-f]{64}\z/
  @requirement_id ~r/\A[a-zA-Z0-9_.:-]{1,128}\z/

  @type serving_bundle :: %{
          serving: Nx.Serving.t(),
          model_digest: String.t(),
          model_dir: String.t()
        }

  @doc "Returns the only admitted model repository shape: a local directory."
  @spec repository(String.t()) :: {:ok, {:local, String.t()}} | {:error, map()}
  def repository(model_dir) when is_binary(model_dir) do
    expanded = Path.expand(model_dir)

    cond do
      String.match?(model_dir, ~r/^https?:\/\//i) ->
        refusal(:external_model_repository_refused, model_dir)

      true ->
        case File.lstat(expanded) do
          {:ok, %File.Stat{type: :symlink}} ->
            refusal(:model_symlink_refused, ".")

          {:ok, %File.Stat{type: :directory}} ->
            {:ok, {:local, expanded}}

          {:ok, _stat} ->
            refusal(:local_model_directory_missing, expanded)

          {:error, _reason} ->
            refusal(:local_model_directory_missing, expanded)
        end
    end
  end

  def repository(other), do: refusal(:invalid_model_directory, inspect(other))

  @doc """
  Builds an in-process Bumblebee text-generation serving from local files.

  The model directory must contain `.model-manifest.sha256` in sha256sum form.
  Every listed local artifact is recomputed before the serving is built; the
  manifest digest becomes the model identity. No Hugging Face or HTTP
  repository form is accepted here.
  """
  @spec build_serving(String.t(), keyword()) :: {:ok, serving_bundle()} | {:error, term()}
  def build_serving(model_dir, opts \\ []) do
    with {:ok, repo = {:local, expanded}} <- repository(model_dir),
         {:ok, model_digest} <- verify_model_manifest(expanded),
         {:ok, model_info} <- Bumblebee.load_model(repo),
         {:ok, tokenizer} <- Bumblebee.load_tokenizer(repo),
         {:ok, generation_config} <- Bumblebee.load_generation_config(repo) do
      generation_config =
        Bumblebee.configure(generation_config,
          max_new_tokens: Keyword.get(opts, :max_new_tokens, 1_024)
        )

      serving_opts =
        if Keyword.get(opts, :exla?, true) do
          [defn_options: [compiler: EXLA]]
        else
          []
        end

      serving = Bumblebee.Text.generation(model_info, tokenizer, generation_config, serving_opts)

      {:ok, %{serving: serving, model_digest: model_digest, model_dir: expanded}}
    end
  end

  @doc """
  Executes local inference and returns a typed, authority-free observation.

  `requirements` is the independently sealed ideal requirement set. Model
  output may classify only those ids; novel observations use a separate list.
  Raw generated notes/quotes are deliberately discarded from the returned
  object to minimize transcript/PII propagation.
  """
  @spec extract(serving_bundle(), String.t(), [map()]) :: {:ok, map()} | {:error, term()}
  def extract(%{serving: serving, model_digest: digest} = bundle, transcript, requirements)
      when is_binary(transcript) and is_list(requirements) do
    with :ok <- validate_digest(digest),
         {:ok, requirement_ids} <- requirement_ids(requirements),
         prompt <- prompt(transcript, requirements),
         output <- Nx.Serving.run(serving, prompt),
         {:ok, generated} <- generated_text(output),
         {:ok, candidate} <- decode_output(generated, requirement_ids, digest, transcript) do
      {:ok,
       candidate
       |> Map.put("runtime", "NX_BUMBLEBEE")
       |> Map.put("model_dir_identity", sha256(bundle.model_dir))}
    end
  end

  def extract(_, _, _), do: refusal(:invalid_private_inference_request, "invalid arguments")

  @doc "Pure decoder/validator used by the narrow court and by `extract/3`."
  @spec decode_output(String.t(), [String.t()], String.t(), String.t()) ::
          {:ok, map()} | {:error, map()}
  def decode_output(text, requirement_ids, model_digest, transcript)
      when is_binary(text) and is_list(requirement_ids) and is_binary(transcript) do
    with :ok <- validate_digest(model_digest),
         {:ok, json} <- extract_json(text),
         {:ok, decoded} <- Jason.decode(json),
         {:ok, observations} <- observations(decoded, requirement_ids),
         {:ok, novel} <- novel_observations(decoded) do
      transcript_digest = sha256(transcript)

      observations =
        observations
        |> Enum.with_index(1)
        |> Enum.map(fn {observation, index} ->
          Map.put(
            observation,
            "evidence_ref",
            "sha256:#{transcript_digest}#observation:#{index}"
          )
        end)

      novel =
        novel
        |> Enum.with_index(1)
        |> Enum.map(fn {observation, index} ->
          observation
          |> Map.put("id", "novel:#{sha256({transcript_digest, index, observation}) |> binary_part(0, 24)}")
          |> Map.put("evidence_ref", "sha256:#{transcript_digest}#novel:#{index}")
        end)

      candidate = %{
        "schema" => "zoe.meeting.observation.v1",
        "source" => "PRIVATE_LOCAL_INFERENCE",
        "inference" => %{
          "mode" => "PRIVATE_LOCAL",
          "runtime" => "NX_BUMBLEBEE",
          "model_identity" => "sha256:#{model_digest}",
          "input_digest" => transcript_digest,
          "external_model_provider" => false
        },
        "authority" => "OBSERVE_CONSTRUCT_ONLY",
        "do_authority" => false,
        "observations" => observations,
        "novel_observations" => novel,
        "process_metrics" => %{"unnecessary_minutes" => process_waste(decoded)}
      }

      {:ok, Map.put(candidate, "digest", sha256(candidate))}
    else
      {:error, %Jason.DecodeError{} = error} ->
        refusal(:model_output_not_json, Exception.message(error))

      {:error, _} = error ->
        error
    end
  end

  def decode_output(_, _, _, _), do: refusal(:invalid_model_output, "invalid arguments")

  @doc "Verifies every artifact named by `.model-manifest.sha256` and returns the manifest digest."
  @spec verify_model_manifest(String.t()) :: {:ok, String.t()} | {:error, map()}
  def verify_model_manifest(model_dir) when is_binary(model_dir) do
    expanded = Path.expand(model_dir)
    manifest = Path.join(expanded, ".model-manifest.sha256")

    with {:ok, {:local, ^expanded}} <- repository(expanded),
         {:ok, content} <- read_manifest(manifest),
         {:ok, entries} <- parse_manifest(content),
         :ok <- verify_no_symlinks(expanded),
         :ok <- verify_manifest_complete(expanded, entries),
         :ok <- verify_manifest_entries(expanded, entries) do
      {:ok, sha256(content)}
    end
  end

  def verify_model_manifest(other), do: refusal(:invalid_model_directory, inspect(other))

  defp read_manifest(path) do
    case File.read(path) do
      {:ok, content} -> {:ok, content}
      {:error, reason} -> refusal(:model_manifest_missing, inspect(reason))
    end
  end

  defp parse_manifest(content) do
    entries =
      content
      |> String.split("\n", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    if entries == [] do
      refusal(:model_manifest_empty, "no artifacts")
    else
      entries
      |> Enum.reduce_while({:ok, []}, fn line, {:ok, acc} ->
        case Regex.run(~r/\A([0-9a-fA-F]{64})\s{2}(.+)\z/, line) do
          [_, digest, relative] ->
            relative = String.trim(relative)

            if safe_relative_path?(relative) do
              {:cont, {:ok, [{String.downcase(digest), relative} | acc]}}
            else
              {:halt, refusal(:unsafe_model_manifest_path, relative)}
            end

          _ ->
            {:halt, refusal(:invalid_model_manifest_line, line)}
        end
      end)
      |> reverse_ok()
      |> reject_duplicate_manifest_paths()
    end
  end

  defp reject_duplicate_manifest_paths({:ok, entries}) do
    paths = Enum.map(entries, &elem(&1, 1))

    if length(paths) == length(Enum.uniq(paths)) do
      {:ok, entries}
    else
      refusal(:duplicate_model_manifest_path, inspect(paths))
    end
  end

  defp reject_duplicate_manifest_paths(error), do: error

  defp verify_no_symlinks(root) do
    root
    |> Path.join("**/*")
    |> Path.wildcard(match_dot: true)
    |> Enum.reduce_while(:ok, fn path, :ok ->
      case File.lstat(path) do
        {:ok, %File.Stat{type: :symlink}} ->
          {:halt, refusal(:model_symlink_refused, Path.relative_to(path, root))}

        {:ok, _stat} ->
          {:cont, :ok}

        {:error, reason} ->
          {:halt, refusal(:model_artifact_stat_failed, inspect(reason))}
      end
    end)
  end

  defp verify_manifest_complete(root, entries) do
    declared = entries |> Enum.map(&elem(&1, 1)) |> MapSet.new()

    actual =
      root
      |> Path.join("**/*")
      |> Path.wildcard(match_dot: true)
      |> Enum.filter(&File.regular?/1)
      |> Enum.map(&Path.relative_to(&1, root))
      |> Enum.reject(&(&1 == ".model-manifest.sha256"))
      |> MapSet.new()

    missing_from_manifest = MapSet.difference(actual, declared)
    missing_from_disk = MapSet.difference(declared, actual)

    if MapSet.size(missing_from_manifest) == 0 and MapSet.size(missing_from_disk) == 0 do
      :ok
    else
      refusal(
        :model_manifest_incomplete,
        inspect(%{
          unbound_files: missing_from_manifest |> MapSet.to_list() |> Enum.sort(),
          missing_files: missing_from_disk |> MapSet.to_list() |> Enum.sort()
        })
      )
    end
  end

  defp verify_manifest_entries(root, entries) do
    Enum.reduce_while(entries, :ok, fn {expected, relative}, :ok ->
      path = Path.join(root, relative)

      cond do
        not File.regular?(path) ->
          {:halt, refusal(:model_artifact_missing, relative)}

        sha256_file(path) != expected ->
          {:halt, refusal(:model_artifact_digest_mismatch, relative)}

        true ->
          {:cont, :ok}
      end
    end)
  end

  defp safe_relative_path?(relative) do
    relative != "" and Path.type(relative) == :relative and
      not Enum.member?(Path.split(relative), "..") and
      relative != ".model-manifest.sha256"
  end

  defp validate_digest(value) when is_binary(value) do
    if Regex.match?(@digest, value), do: :ok, else: refusal(:invalid_model_digest, value)
  end

  defp validate_digest(other), do: refusal(:invalid_model_digest, inspect(other))

  defp requirement_ids(requirements) do
    ids = Enum.map(requirements, &Map.get(&1, "id", Map.get(&1, :id)))

    cond do
      ids == [] -> refusal(:requirements_required, "empty")
      Enum.any?(ids, &(not is_binary(&1) or not Regex.match?(@requirement_id, &1))) ->
        refusal(:invalid_requirement_id, inspect(ids))
      length(ids) != length(Enum.uniq(ids)) -> refusal(:duplicate_requirement_id, inspect(ids))
      true -> {:ok, ids}
    end
  end

  defp prompt(transcript, requirements) do
    requirement_lines =
      Enum.map_join(requirements, "\n", fn requirement ->
        id = Map.get(requirement, "id", Map.get(requirement, :id))
        text = Map.get(requirement, "prompt", Map.get(requirement, :prompt, ""))
        "- #{id}: #{text}"
      end)

    """
    You are a private semantic extraction component. Return JSON only.
    You have no authority to make policy, assign unspoken decisions, or execute work.
    Classify only the sealed requirement ids below. If the meeting did not establish a requirement, use NOT_OBSERVED or PARTIAL. Never invent missing facts.
    Do not include names, phone numbers, email addresses, quotes, or other raw PII in output.

    Allowed statuses: #{Enum.join(@statuses, ", ")}

    Sealed requirements:
    #{requirement_lines}

    Allowed novel kinds: #{Enum.join(@novel_kinds, ", ")}

    Return exactly this shape:
    {"observations":[{"requirement_id":"...","status":"..."}],"novel_observations":[{"kind":"..."}],"process_metrics":{"unnecessary_minutes":0}}

    Transcript:
    <transcript>
    #{transcript}
    </transcript>
    """
  end

  defp generated_text(%{results: [%{text: text} | _]}) when is_binary(text), do: {:ok, text}
  defp generated_text(%{"results" => [%{"text" => text} | _]}) when is_binary(text), do: {:ok, text}
  defp generated_text(other), do: refusal(:unexpected_bumblebee_output, inspect(other))

  defp extract_json(text) do
    trimmed = String.trim(text)

    with {start, 1} <- :binary.match(trimmed, "{"),
         matches when matches != [] <- :binary.matches(trimmed, "}") do
      {final, 1} = List.last(matches)
      {:ok, binary_part(trimmed, start, final - start + 1)}
    else
      _ -> refusal(:model_output_not_json, "no JSON object found")
    end
  end

  defp observations(decoded, requirement_ids) do
    allowed = MapSet.new(requirement_ids)

    case Map.get(decoded, "observations") do
      list when is_list(list) ->
        Enum.reduce_while(list, {:ok, []}, fn observation, {:ok, acc} ->
          id = Map.get(observation, "requirement_id")
          status = Map.get(observation, "status")

          cond do
            not MapSet.member?(allowed, id) ->
              {:halt, refusal(:unknown_requirement_id, inspect(id))}

            status not in @statuses ->
              {:halt, refusal(:invalid_requirement_status, inspect(status))}

            true ->
              {:cont, {:ok, [%{"requirement_id" => id, "status" => status} | acc]}}
          end
        end)
        |> reverse_ok()

      _ ->
        refusal(:observations_required, "model output must include observations")
    end
  end

  defp novel_observations(decoded) do
    case Map.get(decoded, "novel_observations", []) do
      list when is_list(list) ->
        Enum.reduce_while(list, {:ok, []}, fn observation, {:ok, acc} ->
          case Map.get(observation, "kind") do
            kind when kind in @novel_kinds ->
              {:cont, {:ok, [%{"kind" => kind} | acc]}}

            _ ->
              {:halt, refusal(:invalid_novel_observation, inspect(observation))}
          end
        end)
        |> reverse_ok()

      other ->
        refusal(:invalid_novel_observations, inspect(other))
    end
  end

  defp process_waste(decoded) do
    case get_in(decoded, ["process_metrics", "unnecessary_minutes"]) do
      value when is_integer(value) and value >= 0 -> value
      _ -> 0
    end
  end

  defp reverse_ok({:ok, values}), do: {:ok, Enum.reverse(values)}
  defp reverse_ok(error), do: error

  defp sha256(value) when is_binary(value) do
    :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
  end

  defp sha256(value), do: value |> :erlang.term_to_binary([:deterministic]) |> sha256()

  defp sha256_file(path) do
    context = :crypto.hash_init(:sha256)

    context =
      path
      |> File.stream!([], 1_048_576)
      |> Enum.reduce(context, fn chunk, acc -> :crypto.hash_update(acc, chunk) end)

    context |> :crypto.hash_final() |> Base.encode16(case: :lower)
  end

  defp refusal(code, detail), do: {:error, %{code: code, detail: detail}}
end
