defmodule Xaas.Actuation.Validations.CausalAdmission do
  @moduledoc """
  Admits structurally evidenced causal-intervention certificates before DO.

  The validation is intentionally narrow: it does not claim to perform causal
  discovery, do-calculus, d-separation, or placebo analysis itself. Those belong
  to dedicated causal verifiers. This boundary only admits a certificate when
  the caller explicitly marks causal identification as required and supplies
  the evidence identities needed to replay that external verification.

  A caller may additionally bind the certificate to a validated FrontierEvidence
  bundle. That bundle remains supporting evidence only: planning, observation,
  temporal receipts, and control-plane descriptors never substitute for the
  causal verifier, DAG proof, assumptions, placebo result, or falsifier.

  Existing deterministic domain actions remain unchanged when no `causal`
  declaration is present in the authority evidence envelope.
  """

  use Ash.Resource.Validation

  @strategies ~w(rct iv backdoor frontdoor observational_assumptions)
  @evidence_fields ~w(verifier dag_proof_hash assumptions_hash placebo_result_hash falsifier)

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    authority = Ash.Changeset.get_attribute(changeset, :authority) || %{}
    frontier = fetch(authority, "frontier_evidence")

    case fetch(authority, "causal") do
      nil ->
        :ok

      %{} = causal ->
        validate_causal(causal, frontier)

      _other ->
        refusal("causal admission declaration must be a map")
    end
  end

  defp validate_causal(causal, _frontier) when is_map(causal) and map_size(causal) == 0 do
    refusal("causal admission declaration must include boolean required")
  end

  defp validate_causal(causal, frontier) when is_map(causal) do
    case fetch(causal, "required") do
      false ->
        :ok

      true ->
        validate_required_causal(causal, frontier)

      _ ->
        refusal("causal admission declaration must include boolean required")
    end
  end

  defp validate_required_causal(causal, frontier) do
    missing =
      Enum.reject(@evidence_fields, fn field ->
        non_empty_string?(fetch(causal, field))
      end)

    cond do
      normalize_name(fetch(causal, "status")) != "admitted" ->
        refusal("causal admission required but certificate status is not admitted")

      normalize_name(fetch(causal, "strategy")) not in @strategies ->
        refusal(
          "unsupported causal identification strategy: #{inspect(fetch(causal, "strategy"))}"
        )

      missing != [] ->
        refusal("causal admission certificate missing evidence: #{Enum.join(missing, ", ")}")

      true ->
        validate_frontier_binding(causal, frontier)
    end
  end

  defp validate_frontier_binding(causal, nil) do
    case fetch(causal, "supporting_evidence_hash") do
      nil -> :ok
      _ -> refusal("causal supporting evidence hash requires a frontier evidence bundle")
    end
  end

  defp validate_frontier_binding(causal, %{} = frontier) do
    bundle_hash = fetch(frontier, "bundle_sha256")
    supporting_hash = fetch(causal, "supporting_evidence_hash")

    cond do
      not non_empty_string?(bundle_hash) ->
        refusal("frontier evidence bundle has no admitted bundle hash")

      is_nil(supporting_hash) ->
        refusal("causal certificate must bind the supplied frontier evidence bundle")

      supporting_hash != bundle_hash ->
        refusal("causal supporting evidence hash does not match frontier evidence bundle")

      true ->
        :ok
    end
  end

  defp validate_frontier_binding(_causal, _frontier) do
    refusal("frontier evidence bundle must be a map")
  end

  defp fetch(map, key) when is_map(map) do
    case Map.fetch(map, key) do
      {:ok, value} -> value
      :error -> fetch_atom_key(map, key)
    end
  end

  defp fetch(_, _), do: nil

  defp fetch_atom_key(map, key) do
    atom = String.to_existing_atom(key)
    Map.get(map, atom)
  rescue
    ArgumentError -> nil
  end

  defp normalize_name(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_name(value), do: value

  defp non_empty_string?(value), do: is_binary(value) and String.trim(value) != ""

  defp refusal(message), do: {:error, field: :authority, message: message}
end
