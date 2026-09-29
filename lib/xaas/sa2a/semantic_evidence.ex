defmodule Xaas.Sa2a.SemanticEvidence do
  @moduledoc """
  XaaS runtime adapter for the portable SA2A semantic-evidence reference.

  AshA2A owns the portable reference contract. XaaS only admits that exact
  reference at its runtime boundary and can bind its canonical digest into
  receipts/candidates. Semantic evidence never substitutes for the independent
  authority evidence required by consequential bridge edges.
  """

  alias AshA2A.Semantic.EvidenceRef

  @spec admit_optional(nil | map()) :: {:ok, nil | map()} | {:error, map()}
  def admit_optional(ref), do: EvidenceRef.admit_optional(ref)

  @spec admit(map()) :: {:ok, map()} | {:error, map()}
  def admit(ref), do: EvidenceRef.admit(ref)

  @spec digest(map()) :: {:ok, String.t()} | {:error, map()}
  def digest(ref), do: EvidenceRef.digest(ref)

  @doc "Attach an admitted reference to an inert candidate map."
  @spec attach(map(), nil | map()) :: {:ok, map()} | {:error, map()}
  def attach(candidate, ref) when is_map(candidate) do
    with {:ok, admitted} <- admit_optional(ref) do
      {:ok, maybe_put(candidate, "semantic_evidence", admitted)}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
