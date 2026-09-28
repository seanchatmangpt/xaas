defmodule Xaas.Ultracode.SubstitutionPolicy do
  @moduledoc """
  Executable consumer of the canonical interchangeable-parts qualification TTL.

  This is intentionally a tiny closed-world reader for the policy vocabulary,
  not a general RDF parser. Unknown/malformed policy terms fail closed. The TTL
  remains the semantic source; this module projects only the fields the runtime
  court must enforce.
  """

  @policy_path Path.expand("../../../priv/ontology/interchangeable-part-qualification.ttl", __DIR__)
  @external_resource @policy_path
  @policy File.read!(@policy_path)

  @required ~w(exactSubject verifierEvidenceDigest replayDigest standing)
  @booleans ~w(requiresExactSubject requiresDeterministicReplay requiresCryptographicBinding)

  @spec policy() :: map()
  def policy, do: parse!(@policy)

  @spec parse!(binary()) :: map()
  def parse!(ttl) when is_binary(ttl) do
    required =
      Regex.scan(~r/ce:requiredQualificationField\s+ce:([A-Za-z][A-Za-z0-9]*)\s*[;.]?/, ttl,
        capture: :all_but_first
      )
      |> List.flatten()
      |> MapSet.new()

    admitted = object(ttl, "admittedStanding")
    unknown = object(ttl, "unknownStanding")
    authority = object(ttl, "authorityBoundary")

    flags =
      Map.new(@booleans, fn predicate ->
        {predicate, Regex.match?(~r/ce:#{predicate}\s+true\s*[;.]?/, ttl)}
      end)

    cond do
      required != MapSet.new(@required) ->
        raise ArgumentError, "qualification policy required-field drift"

      admitted != "ALIVE" ->
        raise ArgumentError, "qualification policy admitted standing drift"

      unknown != "UNKNOWN" ->
        raise ArgumentError, "qualification policy must preserve UNKNOWN"

      authority != "NONE" ->
        raise ArgumentError, "qualification policy authority boundary drift"

      Enum.any?(flags, fn {_k, v} -> v != true end) ->
        raise ArgumentError, "qualification policy lost a mandatory invariant"

      true ->
        %{
          required_fields: required,
          admitted_standing: admitted,
          unknown_standing: unknown,
          authority_boundary: authority,
          flags: flags,
          ttl_sha256: sha256(ttl)
        }
    end
  end

  @spec admit_receipt(map()) :: :ok | {:error, atom()}
  def admit_receipt(receipt) when is_map(receipt) do
    p = policy()

    cond do
      blank?(receipt[:exact_subject]) -> {:error, :qualification_subject_missing}
      not exact_subject?(receipt[:exact_subject]) -> {:error, :qualification_subject_not_exact}
      receipt[:standing] == p.unknown_standing -> {:error, :qualification_unknown}
      receipt[:standing] != p.admitted_standing -> {:error, :qualification_not_alive}
      true -> :ok
    end
  end

  def admit_receipt(_), do: {:error, :qualification_receipt_missing}

  defp object(ttl, predicate) do
    case Regex.run(~r/ce:#{predicate}\s+ce:([A-Za-z][A-Za-z0-9]*)\s*[;.]?/, ttl,
           capture: :all_but_first
         ) do
      [value] -> value
      _ -> nil
    end
  end

  defp exact_subject?(value),
    do: is_binary(value) and Regex.match?(~r/^[^\s@]+\/[^\s@]+@[0-9a-f]{40}$/, value)

  defp blank?(value), do: not is_binary(value) or String.trim(value) == ""

  defp sha256(value),
    do: "sha256:" <> (:crypto.hash(:sha256, value) |> Base.encode16(case: :lower))
end
