defmodule Xaas.Semantics.ComputationArtifact do
  @moduledoc """
  Runtime-neutral identity for a computation that may participate in SA2A.

  The artifact describes how to invoke a capability; it does not grant standing,
  authority, or permission to cross Xaas.Actuation.
  """

  alias Xaas.Semantics.Registry

  @runtimes ~w(ONNX NX AXON PYTORCH SCIKIT_LEARN LLM RULE SPARQL FOND HDDL NATIVE WASM HUMAN)

  @enforce_keys [
    :artifact_identity,
    :capability_iri,
    :runtime,
    :input_schema_identity,
    :output_schema_identity,
    :input_projection_identity,
    :deterministic
  ]
  defstruct @enforce_keys ++ [:training_corpus_identity, :calibration_identity]

  @type t :: %__MODULE__{
          artifact_identity: String.t(),
          capability_iri: String.t(),
          runtime: String.t(),
          input_schema_identity: String.t(),
          output_schema_identity: String.t(),
          input_projection_identity: String.t(),
          deterministic: boolean(),
          training_corpus_identity: String.t() | nil,
          calibration_identity: String.t() | nil
        }

  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_map(attrs) do
    with {:ok, artifact_identity} <- required_binary(attrs, :artifact_identity),
         {:ok, capability_iri} <- required_binary(attrs, :capability_iri),
         true <- Registry.public_iri?(capability_iri) || {:error, :non_public_capability_iri},
         {:ok, runtime} <- required_binary(attrs, :runtime),
         true <- runtime in @runtimes || {:error, {:unsupported_runtime, runtime}},
         {:ok, input_schema_identity} <- required_binary(attrs, :input_schema_identity),
         {:ok, output_schema_identity} <- required_binary(attrs, :output_schema_identity),
         {:ok, input_projection_identity} <- required_binary(attrs, :input_projection_identity),
         deterministic when is_boolean(deterministic) <- Map.get(attrs, :deterministic) do
      {:ok,
       %__MODULE__{
         artifact_identity: artifact_identity,
         capability_iri: capability_iri,
         runtime: runtime,
         input_schema_identity: input_schema_identity,
         output_schema_identity: output_schema_identity,
         input_projection_identity: input_projection_identity,
         deterministic: deterministic,
         training_corpus_identity: optional_binary(attrs, :training_corpus_identity),
         calibration_identity: optional_binary(attrs, :calibration_identity)
       }}
    else
      nil -> {:error, :deterministic_required}
      false -> {:error, :deterministic_must_be_boolean}
      {:error, _} = error -> error
      _ -> {:error, :invalid_computation_artifact}
    end
  end

  @spec hash(t()) :: String.t()
  def hash(%__MODULE__{} = artifact) do
    artifact
    |> Map.from_struct()
    |> Xaas.Semantics.ComputationHash.hash()
  end

  defp required_binary(attrs, key) do
    case Map.get(attrs, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, {:required_identity, key}}
    end
  end

  defp optional_binary(attrs, key) do
    case Map.get(attrs, key) do
      value when is_binary(value) and value != "" -> value
      _ -> nil
    end
  end
end

defmodule Xaas.Semantics.ComputationHash do
  @moduledoc false

  @spec hash(term()) :: String.t()
  def hash(value) do
    value
    |> canonical()
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp canonical(%_{} = struct), do: struct |> Map.from_struct() |> canonical()

  defp canonical(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), canonical(value)} end)
    |> Enum.sort()
  end

  defp canonical(list) when is_list(list), do: Enum.map(list, &canonical/1)
  defp canonical(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> canonical()
  defp canonical(value), do: value
end

defmodule Xaas.Semantics.ComputationClaim do
  @moduledoc """
  Powerless typed output from any computation provider.

  A model score, planner result, rule result, or human assertion reaches this
  boundary as CANDIDATE only. The claim cannot authorize XaaS actuation.
  """

  alias Xaas.Semantics.{ComputationArtifact, ComputationHash, Registry}

  @evidence_classes ~w(OBSERVED DERIVED PROVEN INFERRED GENERATED HUMAN_ASSERTED)

  @enforce_keys [
    :subject_identity,
    :predicate_iri,
    :value,
    :artifact,
    :evidence_class,
    :standing,
    :authorizes_actuation
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          subject_identity: String.t(),
          predicate_iri: String.t(),
          value: term(),
          artifact: ComputationArtifact.t(),
          evidence_class: String.t(),
          standing: String.t(),
          authorizes_actuation: false
        }

  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_map(attrs) do
    with {:ok, subject_identity} <- required_binary(attrs, :subject_identity),
         {:ok, predicate_iri} <- required_binary(attrs, :predicate_iri),
         true <- Registry.public_iri?(predicate_iri) || {:error, :non_public_predicate_iri},
         %ComputationArtifact{} = artifact <- Map.get(attrs, :artifact),
         evidence_class when evidence_class in @evidence_classes <-
           Map.get(attrs, :evidence_class),
         "CANDIDATE" <- Map.get(attrs, :standing, "CANDIDATE"),
         false <- Map.get(attrs, :authorizes_actuation, false) do
      {:ok,
       %__MODULE__{
         subject_identity: subject_identity,
         predicate_iri: predicate_iri,
         value: Map.get(attrs, :value),
         artifact: artifact,
         evidence_class: evidence_class,
         standing: "CANDIDATE",
         authorizes_actuation: false
       }}
    else
      true -> {:error, :computation_claim_cannot_authorize_actuation}
      standing when is_binary(standing) -> {:error, {:computation_claim_standing_refused, standing}}
      {:error, _} = error -> error
      _ -> {:error, :invalid_computation_claim}
    end
  end

  @spec hash(t()) :: String.t()
  def hash(%__MODULE__{} = claim) do
    ComputationHash.hash(%{
      subject_identity: claim.subject_identity,
      predicate_iri: claim.predicate_iri,
      value: claim.value,
      artifact_hash: ComputationArtifact.hash(claim.artifact),
      evidence_class: claim.evidence_class,
      standing: claim.standing,
      authorizes_actuation: claim.authorizes_actuation
    })
  end

  defp required_binary(attrs, key) do
    case Map.get(attrs, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, {:required_identity, key}}
    end
  end
end

defmodule Xaas.Semantics.PlanningAdvice do
  @moduledoc """
  Exact-subject model guidance over a formal planner frontier.

  The formal candidate set is sovereign. Advice may reorder candidates that are
  already present; it cannot add a new applicable candidate or silently prune one.
  """

  alias Xaas.Semantics.{ComputationArtifact, ComputationHash}

  @kinds ~w(FRONTIER STATE_HEURISTIC ACTION_ORDER METHOD_ORDER BINDING_ORDER OUTCOME REPAIR CONSEQUENCE EXPERIENCE)

  @enforce_keys [
    :planning_subject_identity,
    :formal_projection_identity,
    :artifact,
    :kind,
    :candidates,
    :standing,
    :authorizes_actuation
  ]
  defstruct @enforce_keys

  @type candidate :: %{candidate_ref: String.t(), score: number()}

  @type t :: %__MODULE__{
          planning_subject_identity: String.t(),
          formal_projection_identity: String.t(),
          artifact: ComputationArtifact.t(),
          kind: String.t(),
          candidates: [candidate()],
          standing: String.t(),
          authorizes_actuation: false
        }

  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_map(attrs) do
    with {:ok, subject} <- required_binary(attrs, :planning_subject_identity),
         {:ok, projection} <- required_binary(attrs, :formal_projection_identity),
         %ComputationArtifact{} = artifact <- Map.get(attrs, :artifact),
         kind when kind in @kinds <- Map.get(attrs, :kind),
         candidates when is_list(candidates) <- Map.get(attrs, :candidates, []),
         {:ok, normalized} <- normalize_candidates(candidates),
         "CANDIDATE" <- Map.get(attrs, :standing, "CANDIDATE"),
         false <- Map.get(attrs, :authorizes_actuation, false) do
      {:ok,
       %__MODULE__{
         planning_subject_identity: subject,
         formal_projection_identity: projection,
         artifact: artifact,
         kind: kind,
         candidates: normalized,
         standing: "CANDIDATE",
         authorizes_actuation: false
       }}
    else
      true -> {:error, :planning_advice_cannot_authorize_actuation}
      standing when is_binary(standing) -> {:error, {:planning_advice_standing_refused, standing}}
      {:error, _} = error -> error
      _ -> {:error, :invalid_planning_advice}
    end
  end

  @spec order_formal(t(), [String.t()]) :: {:ok, [String.t()]} | {:error, term()}
  def order_formal(%__MODULE__{} = advice, formal_refs) when is_list(formal_refs) do
    if length(formal_refs) != length(Enum.uniq(formal_refs)) do
      {:error, :formal_candidate_refs_must_be_unique}
    else
      formal_set = MapSet.new(formal_refs)

      ranked =
        advice.candidates
        |> Enum.sort_by(fn %{candidate_ref: ref, score: score} -> {-score, ref} end)
        |> Enum.map(& &1.candidate_ref)
        |> Enum.filter(&MapSet.member?(formal_set, &1))

      ranked_set = MapSet.new(ranked)
      remainder = Enum.reject(formal_refs, &MapSet.member?(ranked_set, &1))
      {:ok, ranked ++ remainder}
    end
  end

  @spec hash(t()) :: String.t()
  def hash(%__MODULE__{} = advice) do
    ComputationHash.hash(%{
      planning_subject_identity: advice.planning_subject_identity,
      formal_projection_identity: advice.formal_projection_identity,
      artifact_hash: ComputationArtifact.hash(advice.artifact),
      kind: advice.kind,
      candidates: advice.candidates,
      standing: advice.standing,
      authorizes_actuation: advice.authorizes_actuation
    })
  end

  defp normalize_candidates(candidates) do
    with {:ok, normalized} <-
           Enum.reduce_while(candidates, {:ok, []}, fn candidate, {:ok, acc} ->
             case normalize_candidate(candidate) do
               {:ok, value} -> {:cont, {:ok, [value | acc]}}
               {:error, _} = error -> {:halt, error}
             end
           end) do
      normalized = Enum.reverse(normalized)
      refs = Enum.map(normalized, & &1.candidate_ref)

      if length(refs) == length(Enum.uniq(refs)) do
        {:ok, normalized}
      else
        {:error, :planning_advice_candidate_refs_must_be_unique}
      end
    end
  end

  defp normalize_candidate(%{candidate_ref: ref, score: score})
       when is_binary(ref) and ref != "" and is_number(score) do
    {:ok, %{candidate_ref: ref, score: score}}
  end

  defp normalize_candidate(_), do: {:error, :invalid_planning_advice_candidate}

  defp required_binary(attrs, key) do
    case Map.get(attrs, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, {:required_identity, key}}
    end
  end
end
