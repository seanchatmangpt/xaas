defmodule Xaas.CS2.SemanticJiraBridge do
  @moduledoc """
  Pure XaaS consumer for authority-free Semantic-Jira CS2 candidates.

  Input is the portable candidate shape produced by
  `GgenIgniter.SemanticJira.CS2Batch.projection_candidates/1`. XaaS does
  not depend on the producer at compile time: the cross-repository contract
  is the data shape itself.

  This boundary constructs an execution package and an *unissued* lease
  request candidate. It never calls `Xaas.Ultracode.Lease.claim_next/3`,
  never creates a lease token, and never performs consequential DO.
  """

  @sha ~r/\A[0-9a-f]{40}\z/
  @repo ~r/\A[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\z/
  @semantic_digest ~r/\Asha256:[0-9a-f]{64}\z/
  @source_digest ~r/\A[0-9a-f]{64}\z/

  @required ~w(
    batch_id batch_digest layer identity work_order_digest definition_digest
    subject repository base_sha source_digest authority
  )

  @spec admit_candidate(map()) :: {:ok, map()} | {:error, term()}
  def admit_candidate(raw) when is_map(raw) do
    candidate = strings(raw)

    with :ok <- required(candidate),
         :ok <- authority_none(candidate),
         :ok <- repository(candidate["repository"]),
         :ok <- sha(candidate["base_sha"]),
         :ok <- semantic_digest(:batch_digest, candidate["batch_digest"]),
         :ok <- semantic_digest(:work_order_digest, candidate["work_order_digest"]),
         :ok <- semantic_digest(:definition_digest, candidate["definition_digest"]),
         :ok <- source_digest(candidate["source_digest"]),
         :ok <- layer(candidate["layer"]),
         :ok <- scope(candidate["path_scope"] || []) do
      {:ok,
       candidate
       |> Map.put("path_scope", candidate["path_scope"] || [])
       |> Map.put("authority", "NONE")
       |> Map.put("admitted_by", "Xaas.CS2.SemanticJiraBridge")}
    else
      {:error, reason} -> {:error, {:refused_cs2_candidate, reason}}
    end
  end

  def admit_candidate(_), do: {:error, {:refused_cs2_candidate, :expected_map}}

  @spec execution_package(map(), String.t()) :: {:ok, map()} | {:error, term()}
  def execution_package(raw, provider) when is_binary(provider) and provider != "" do
    with {:ok, candidate} <- admit_candidate(raw) do
      lease_request = %{
        "kind" => "cs2.lease_request_candidate",
        "provider" => provider,
        "work_order_id" => candidate["identity"],
        "work_order_digest" => candidate["work_order_digest"],
        "repository" => candidate["repository"],
        "base_sha" => candidate["base_sha"],
        "scope" => candidate["path_scope"],
        "authority" => "NONE",
        "issued" => false
      }

      {:ok,
       %{
         "kind" => "cs2.execution_package",
         "batch_id" => candidate["batch_id"],
         "batch_digest" => candidate["batch_digest"],
         "layer" => candidate["layer"],
         "subject" => candidate["subject"],
         "repository" => candidate["repository"],
         "base_sha" => candidate["base_sha"],
         "source_digest" => candidate["source_digest"],
         "work_order_id" => candidate["identity"],
         "work_order_digest" => candidate["work_order_digest"],
         "definition_digest" => candidate["definition_digest"],
         "next_edge" => candidate["next_edge"],
         "provider" => provider,
         "scope" => candidate["path_scope"],
         "lease_request" => lease_request,
         "authority" => "NONE"
       }}
    end
  end

  def execution_package(_raw, provider),
    do: {:error, {:refused_cs2_candidate, {:invalid_provider, provider}}}

  @spec execution_batch([map()], String.t()) :: {:ok, [map()]} | {:error, term()}
  def execution_batch(candidates, provider) when is_list(candidates) do
    candidates
    |> Enum.reduce_while({:ok, []}, fn candidate, {:ok, acc} ->
      case execution_package(candidate, provider) do
        {:ok, package} -> {:cont, {:ok, [package | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, packages} ->
        {:ok, packages |> Enum.reverse() |> Enum.sort_by(&{&1["layer"], &1["work_order_id"]})}

      error ->
        error
    end
  end

  def execution_batch(_candidates, _provider),
    do: {:error, {:refused_cs2_candidate, :expected_candidate_list}}

  defp required(candidate) do
    case Enum.find(@required, &(candidate[&1] in [nil, ""])) do
      nil -> :ok
      field -> {:error, {:missing_required_field, field}}
    end
  end

  defp authority_none(%{"authority" => "NONE"}), do: :ok
  defp authority_none(_), do: {:error, :authority_must_be_none}

  defp repository(value) when is_binary(value) do
    if Regex.match?(@repo, value), do: :ok, else: {:error, {:invalid_repository, value}}
  end

  defp repository(value), do: {:error, {:invalid_repository, value}}

  defp sha(value) when is_binary(value) do
    if Regex.match?(@sha, value), do: :ok, else: {:error, {:invalid_base_sha, value}}
  end

  defp sha(value), do: {:error, {:invalid_base_sha, value}}

  defp semantic_digest(field, value) when is_binary(value) do
    if Regex.match?(@semantic_digest, value),
      do: :ok,
      else: {:error, {:invalid_semantic_digest, field, value}}
  end

  defp semantic_digest(field, value),
    do: {:error, {:invalid_semantic_digest, field, value}}

  defp source_digest(value) when is_binary(value) do
    if Regex.match?(@source_digest, value),
      do: :ok,
      else: {:error, {:invalid_source_digest, value}}
  end

  defp source_digest(value), do: {:error, {:invalid_source_digest, value}}

  defp layer(value) when is_integer(value) and value >= 0, do: :ok
  defp layer(value), do: {:error, {:invalid_layer, value}}

  defp scope(values) when is_list(values) do
    if Enum.all?(values, &(is_binary(&1) and &1 != "" and not String.starts_with?(&1, "/"))),
      do: :ok,
      else: {:error, {:invalid_scope, values}}
  end

  defp scope(value), do: {:error, {:invalid_scope, value}}

  defp strings(v) when is_map(v) and not is_struct(v),
    do: Map.new(v, fn {k, x} -> {to_string(k), strings(x)} end)

  defp strings(v) when is_list(v), do: Enum.map(v, &strings/1)
  defp strings(v), do: v
end
