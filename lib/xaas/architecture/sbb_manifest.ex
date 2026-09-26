defmodule Xaas.Architecture.SBBManifest do
  @moduledoc """
  Admission boundary between SBB qualification and XaaS runtime realization.

  Qualification proves compatibility only. This module emits inert runtime
  realization descriptors. Consequential execution remains exclusively behind
  Xaas.Actuation/BRCE.
  """

  @levels %{none: 0, observe: 1, select: 2, construct: 3, do: 4}
  @required [
    :abb_digest,
    :contract_digest,
    :sbb_digest,
    :qualification_digest,
    :standing,
    :immutable_subject,
    :authority_ceiling,
    :allowed_behaviors
  ]

  @spec realize(map(), keyword()) :: {:ok, map()} | {:error, {:refused, term()}}
  def realize(manifest, opts \\ []) when is_map(manifest) do
    provider = Keyword.get(opts, :provider, :unspecified)
    transport = Keyword.get(opts, :transport, :unspecified)
    behavior = Keyword.get(opts, :behavior)
    requested_authority = Keyword.get(opts, :authority, :none)

    with :ok <- require_fields(manifest),
         :ok <- require_qualified(manifest),
         :ok <- require_immutable(manifest),
         :ok <- require_behavior(manifest, behavior),
         :ok <- require_authority(manifest.authority_ceiling, requested_authority) do
      semantic_identity = semantic_identity(manifest)

      body = %{
        schema: "xaas.sbb-runtime-realization.v1",
        semantic_identity: semantic_identity,
        abb_digest: manifest.abb_digest,
        contract_digest: manifest.contract_digest,
        sbb_digest: manifest.sbb_digest,
        qualification_digest: manifest.qualification_digest,
        provider: provider,
        transport: transport,
        behavior: behavior,
        authority_ceiling: manifest.authority_ceiling,
        execution_authority: :none,
        brce_required_for_do: true
      }

      {:ok, Map.put(body, :receipt_identity, digest(body))}
    end
  end

  @spec semantic_identity(map()) :: String.t()
  def semantic_identity(manifest) do
    digest({
      manifest.abb_digest,
      manifest.contract_digest,
      manifest.sbb_digest,
      manifest.qualification_digest
    })
  end

  defp require_fields(manifest) do
    case Enum.find(@required, &(not Map.has_key?(manifest, &1))) do
      nil -> :ok
      field -> {:error, {:refused, {:missing_field, field}}}
    end
  end

  defp require_qualified(%{standing: :qualified}), do: :ok
  defp require_qualified(%{standing: :unknown}), do: {:error, {:refused, :unknown_standing}}
  defp require_qualified(_), do: {:error, {:refused, :unqualified_sbb}}

  defp require_immutable(%{immutable_subject: true}), do: :ok
  defp require_immutable(_), do: {:error, {:refused, :mutable_subject}}

  defp require_behavior(_manifest, nil), do: :ok

  defp require_behavior(%{allowed_behaviors: allowed}, behavior) when is_list(allowed) do
    if behavior in allowed, do: :ok, else: {:error, {:refused, :contract_behavior_violation}}
  end

  defp require_authority(ceiling, requested) do
    with {:ok, ceiling_level} <- level(ceiling),
         {:ok, requested_level} <- level(requested),
         true <- requested != :do || {:error, {:refused, :brce_required}},
         true <- requested_level <= ceiling_level ||
                   {:error, {:refused, :authority_ceiling_exceeded}} do
      :ok
    end
  end

  defp level(authority) do
    case Map.fetch(@levels, authority) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, {:refused, :invalid_authority}}
    end
  end

  defp digest(term) do
    term
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> then(&("sha256:" <> &1))
  end
end
