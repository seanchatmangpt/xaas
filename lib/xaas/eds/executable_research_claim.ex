defmodule Xaas.Eds.ExecutableResearchClaim do
  @moduledoc """
  The `ExecutableResearchClaim` (ERC), the fundamental Executable Design
  Science (EDS) unit, per `docs/research/executable-design-science.md`
  Section 6:

      ERC+ = <H, A, F, P, I, E, V, R>

  where `H` is a falsifiable hypothesis, `A` is the executable artifact,
  `F` is at least one `Xaas.Eds.Falsifier`, `P` is the declared protocol,
  `I` is exact execution identity, `E` is execution evidence, `V` is a
  verification procedure, and `R` is a reproduction package descriptor.

  ## What this module is

  A pure, deterministic data structure plus:

    * `new/1` -- construction that refuses to build a claim missing its
      minimum required components (a hypothesis, an artifact reference, and
      at least one real -- non-vacuous -- falsifier). Per the paper's
      Section 9, a claim with zero falsifiers has "limited executable
      standing" and this module will not silently mint one.
    * `evidence_state/1` -- delegates to `Xaas.Eds.EvidenceState.classify/1`
      over the claim's current evidence bundle.
    * `fingerprint/1` -- a deterministic identity binding the claim's
      hypothesis, artifact reference, protocol, and falsifier ids, reusing
      the repo's existing SHA-256 fingerprint convention
      (`Xaas.CausalReceipt.ProcessReceipt`, `Xaas.Actuation.fingerprint/1`).
    * `to_receipt_binding/1` -- projects the claim into the field shape
      `Xaas.CausalReceipt.ProcessReceipt` expects, so an ERC's standing can
      be chained into the repo's existing causal-receipt spine rather than
      inventing a second, competing receipt format.

  ## UNSUPPORTED (real, disclosed gaps)

  This module does not execute the artifact, does not run the protocol,
  and does not perform verification or reproduction itself -- those are
  owned by whatever subsystem produces the `evidence` map this module
  classifies. It is the claim's canonical shape and identity, not its
  execution engine. See `Xaas.Eds.EvidenceState` and `Xaas.Eds.Falsifier`
  for the adjacent, equally bounded pieces this module composes.
  """

  alias Xaas.Eds.{EvidenceState, Falsifier}

  @enforce_keys [:hypothesis, :artifact_ref, :falsifiers]
  defstruct [
    :hypothesis,
    :artifact_ref,
    :falsifiers,
    protocol: nil,
    execution_identity: nil,
    evidence: %{},
    verification: nil,
    reproduction: nil
  ]

  @type t :: %__MODULE__{
          hypothesis: String.t(),
          artifact_ref: String.t(),
          falsifiers: [Falsifier.t()],
          protocol: String.t() | nil,
          execution_identity: map() | nil,
          evidence: map(),
          verification: (map() -> boolean()) | nil,
          reproduction: map() | nil
        }

  @doc """
  Construct an `ExecutableResearchClaim`.

  Refuses (returns `{:error, reason}`) when:

    * `hypothesis` or `artifact_ref` is missing/blank
    * `falsifiers` is empty, or every falsifier is vacuous

  This is the mechanical half of Section 9's requirement; it cannot check
  semantic falsifiability (undecidable in general per Section 4.6), only
  that at least one non-degenerate falsifier was actually supplied.
  """
  @spec new(map()) :: {:ok, t()} | {:error, String.t()}
  def new(attrs) when is_map(attrs) do
    with {:ok, hypothesis} <- require_binary(attrs, :hypothesis),
         {:ok, artifact_ref} <- require_binary(attrs, :artifact_ref),
         {:ok, falsifiers} <- require_falsifiers(attrs) do
      {:ok,
       %__MODULE__{
         hypothesis: hypothesis,
         artifact_ref: artifact_ref,
         falsifiers: falsifiers,
         protocol: Map.get(attrs, :protocol),
         execution_identity: Map.get(attrs, :execution_identity),
         evidence: Map.get(attrs, :evidence, %{}),
         verification: Map.get(attrs, :verification),
         reproduction: Map.get(attrs, :reproduction)
       }}
    end
  end

  defp require_binary(attrs, key) do
    case Map.get(attrs, key) do
      v when is_binary(v) and byte_size(v) > 0 -> {:ok, v}
      _ -> {:error, "#{key} is required and must be a non-empty string"}
    end
  end

  defp require_falsifiers(attrs) do
    case Map.get(attrs, :falsifiers) do
      [_ | _] = list ->
        if Enum.all?(list, &match?(%Falsifier{}, &1)) do
          {:ok, list}
        else
          {:error, "falsifiers must be a non-empty list of %Xaas.Eds.Falsifier{} structs"}
        end

      _ ->
        {:error,
         "at least one real (non-vacuous) falsifier is required -- a claim with zero falsifiers has limited executable standing per the paper's Section 9"}
    end
  end

  @doc "Classify the claim's current evidence state. Delegates to `Xaas.Eds.EvidenceState.classify/1`."
  @spec evidence_state(t()) :: EvidenceState.t()
  def evidence_state(%__MODULE__{evidence: evidence}), do: EvidenceState.classify(evidence)

  @doc """
  Run every attached falsifier against the claim's current observed
  evidence. Returns the per-falsifier verdicts; does not itself decide
  claim standing (that's `evidence_state/1`'s job, fed by whatever the
  caller does with these verdicts).
  """
  @spec run_falsifiers(t()) :: [
          {Falsifier.t(), {:ok, Falsifier.verdict()} | {:error, String.t()}}
        ]
  def run_falsifiers(%__MODULE__{falsifiers: falsifiers, evidence: evidence}) do
    Enum.map(falsifiers, fn f -> {f, Falsifier.run(f, evidence)} end)
  end

  @doc """
  Deterministic identity for this claim, binding hypothesis, artifact
  reference, protocol, and falsifier ids. Same shape and hash function as
  `Xaas.CausalReceipt.ProcessReceipt`'s existing fingerprinting convention.
  """
  @spec fingerprint(t()) :: String.t()
  def fingerprint(%__MODULE__{} = claim) do
    %{
      hypothesis: claim.hypothesis,
      artifact_ref: claim.artifact_ref,
      protocol: claim.protocol,
      falsifier_ids: claim.falsifiers |> Enum.map(& &1.id) |> Enum.sort()
    }
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  @doc """
  Project this claim into the field shape `Xaas.CausalReceipt.ProcessReceipt.new/1`
  expects, so an ERC's standing can be chained into the repo's existing
  causal-receipt spine instead of a second, competing receipt format.

  Only fills fields this module actually knows about
  (`observation_ids` <- execution identity's observation refs if present,
  `admitted_observation_hash` <- this claim's fingerprint,
  `actuation_identity`/`consequence_identity` <- execution identity and
  evidence fingerprints). Every other `ProcessReceipt` field is left for
  the caller to supply from its owning subsystem -- this function does
  not fabricate provenance it was not given.
  """
  @spec to_receipt_binding(t()) :: map()
  def to_receipt_binding(%__MODULE__{} = claim) do
    %{
      observation_ids: observation_ids(claim),
      admitted_observation_hash: fingerprint(claim),
      ontology_hash: nil,
      actuation_identity: identity_fingerprint(claim.execution_identity),
      consequence_identity: identity_fingerprint(claim.evidence),
      valid_time: nil,
      observation_time: nil
    }
  end

  defp observation_ids(%__MODULE__{execution_identity: %{observation_ids: ids}})
       when is_list(ids), do: ids

  defp observation_ids(_), do: []

  defp identity_fingerprint(nil), do: nil

  defp identity_fingerprint(term) do
    term
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
