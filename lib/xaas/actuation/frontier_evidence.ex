defmodule Xaas.Actuation.FrontierEvidence do
  @moduledoc """
  Composition court for bounded evidence produced by adjacent Frontier repos.

  The bundle preserves each producer's authority ceiling. It does not reinterpret
  planning, observation, temporal receipts, or control-plane descriptors as causal
  proof or actuation authority. XaaS only validates identities, producer classes,
  authority ceilings, and deterministic bundle integrity before a caller may bind
  the bundle to a separate causal-admission certificate.
  """

  @schema "frontier-evidence-bundle/v1"
  @fragment_schema "frontier-evidence/v1"
  @expected %{
    "beam4pm" => "SELECT",
    "ash_r2rml" => "CONSTRUCT",
    "gitvan" => "OBSERVE",
    "ash_pplan" => "CONSTRUCT"
  }

  @type refusal :: {:error, term()}

  @spec bundle([map()] | map()) :: {:ok, map()} | refusal()
  def bundle(fragments) do
    with {:ok, indexed} <- index_fragments(fragments),
         :ok <- validate_fragments(indexed) do
      body = %{
        "schema" => @schema,
        "fragments" => indexed
      }

      {:ok, Map.put(body, "bundle_sha256", fingerprint(body))}
    end
  end

  @spec validate_bundle(map()) :: :ok | refusal()
  def validate_bundle(bundle) when is_map(bundle) do
    normalized = normalize_map(bundle)
    supplied_hash = Map.get(normalized, "bundle_sha256")

    with true <- Map.get(normalized, "schema") == @schema || {:error, :unsupported_bundle_schema},
         %{} = fragments <- Map.get(normalized, "fragments") || {:error, :fragments_required},
         :ok <- validate_fragments(fragments),
         true <- valid_hash?(supplied_hash) || {:error, :bundle_sha256_required},
         expected <- fingerprint(%{"schema" => @schema, "fragments" => fragments}),
         true <- supplied_hash == expected || {:error, {:bundle_hash_mismatch, supplied_hash, expected}} do
      :ok
    else
      {:error, _} = error -> error
      false -> {:error, :invalid_frontier_evidence_bundle}
      _ -> {:error, :invalid_frontier_evidence_bundle}
    end
  end

  def validate_bundle(_), do: {:error, :frontier_evidence_bundle_must_be_map}

  @spec bind_causal(map(), [map()] | map()) :: {:ok, map()} | refusal()
  def bind_causal(causal, fragments) when is_map(causal) do
    with {:ok, bundle} <- bundle(fragments) do
      causal =
        causal
        |> normalize_map()
        |> Map.put("supporting_evidence_hash", bundle["bundle_sha256"])

      {:ok, %{"causal" => causal, "frontier_evidence" => bundle}}
    end
  end

  def bind_causal(_, _), do: {:error, :causal_certificate_must_be_map}

  @spec expected_producers() :: map()
  def expected_producers, do: @expected

  defp index_fragments(fragments) when is_list(fragments) do
    Enum.reduce_while(fragments, {:ok, %{}}, fn fragment, {:ok, acc} ->
      normalized = normalize_map(fragment)
      producer = Map.get(normalized, "producer")

      cond do
        not is_binary(producer) or producer == "" ->
          {:halt, {:error, :fragment_producer_required}}

        Map.has_key?(acc, producer) ->
          {:halt, {:error, {:duplicate_fragment_producer, producer}}}

        true ->
          {:cont, {:ok, Map.put(acc, producer, normalized)}}
      end
    end)
  end

  defp index_fragments(fragments) when is_map(fragments) do
    normalized = normalize_map(fragments)

    Enum.reduce_while(normalized, {:ok, %{}}, fn {producer, fragment}, {:ok, acc} ->
      fragment = normalize_map(fragment)
      declared = Map.get(fragment, "producer")

      cond do
        declared != producer ->
          {:halt, {:error, {:producer_key_mismatch, producer, declared}}}

        true ->
          {:cont, {:ok, Map.put(acc, producer, fragment)}}
      end
    end)
  end

  defp index_fragments(_), do: {:error, :frontier_fragments_must_be_list_or_map}

  defp validate_fragments(fragments) when is_map(fragments) do
    expected = Map.keys(@expected) |> MapSet.new()
    actual = Map.keys(fragments) |> MapSet.new()
    missing = MapSet.difference(expected, actual) |> MapSet.to_list() |> Enum.sort()
    extras = MapSet.difference(actual, expected) |> MapSet.to_list() |> Enum.sort()

    cond do
      missing != [] ->
        {:error, {:missing_frontier_producers, missing}}

      extras != [] ->
        {:error, {:unsupported_frontier_producers, extras}}

      true ->
        Enum.reduce_while(@expected, :ok, fn {producer, ceiling}, :ok ->
          case validate_fragment(producer, ceiling, Map.fetch!(fragments, producer)) do
            :ok -> {:cont, :ok}
            {:error, _} = error -> {:halt, error}
          end
        end)
    end
  end

  defp validate_fragment(producer, ceiling, fragment) when is_map(fragment) do
    normalized = normalize_map(fragment)

    cond do
      Map.get(normalized, "schema") != @fragment_schema ->
        {:error, {:unsupported_fragment_schema, producer, Map.get(normalized, "schema")}}

      Map.get(normalized, "producer") != producer ->
        {:error, {:fragment_producer_mismatch, producer, Map.get(normalized, "producer")}}

      not non_empty_string?(Map.get(normalized, "producer_head")) ->
        {:error, {:producer_head_required, producer}}

      not non_empty_string?(Map.get(normalized, "standing")) ->
        {:error, {:standing_required, producer}}

      Map.get(normalized, "authority_ceiling") != ceiling ->
        {:error,
         {:authority_ceiling_mismatch, producer, Map.get(normalized, "authority_ceiling"), ceiling}}

      not valid_hash?(Map.get(normalized, "artifact_hash")) ->
        {:error, {:artifact_hash_required, producer}}

      not is_map(Map.get(normalized, "evidence")) ->
        {:error, {:fragment_evidence_required, producer}}

      true ->
        :ok
    end
  end

  defp normalize_map(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), normalize_value(value)} end)
  end

  defp normalize_map(_), do: %{}

  defp normalize_value(value) when is_map(value), do: normalize_map(value)
  defp normalize_value(value) when is_list(value), do: Enum.map(value, &normalize_value/1)
  defp normalize_value(value) when is_tuple(value), do: value |> Tuple.to_list() |> Enum.map(&normalize_value/1)
  defp normalize_value(value) when is_boolean(value) or is_nil(value), do: value
  defp normalize_value(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_value(value), do: value

  defp non_empty_string?(value), do: is_binary(value) and String.trim(value) != ""

  defp valid_hash?("sha256:" <> digest), do: String.match?(digest, ~r/\A[0-9a-f]{64}\z/)
  defp valid_hash?(_), do: false

  defp fingerprint(term) do
    term
    |> canonical_term()
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> then(&("sha256:" <> &1))
  end

  defp canonical_term(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), canonical_term(value)} end)
    |> Enum.sort()
  end

  defp canonical_term(list) when is_list(list), do: Enum.map(list, &canonical_term/1)

  defp canonical_term(tuple) when is_tuple(tuple),
    do: tuple |> Tuple.to_list() |> Enum.map(&canonical_term/1)

  defp canonical_term(value) when is_boolean(value) or is_nil(value), do: value
  defp canonical_term(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp canonical_term(other), do: other
end
