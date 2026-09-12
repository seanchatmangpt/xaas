defmodule Xaas.CausalReceipt.ProcessReceipt do
  @moduledoc """
  Canonical `ProcessReceipt` schema, signer, verifier, lineage traversal, and
  diffing for the unified causal receipt workstream
  (`docs/jira/v26.9.11/unified-causal-receipt.md`).

  ## What this module is

  This module extends the existing meta-receipt model already present in the
  repo (`Xaas.Operations.ActuationReceipt`, `Xaas.Actuation.fingerprint/1`) --
  `R = Merkle(Sigma, mu, H, substrate, R_prev)` -- into a chained
  `ProcessReceipt` struct that binds the full causal-episode identity chain
  described by the ticket:

      ID(O) -> ID(K) -> ID(P) -> ID(Intent) -> ID(DO) -> ID(Consequence) -> ID(R)

  It is the **receipt/binding layer** only: a canonical schema, a
  deterministic episode identity, Merkle chaining against a
  `predecessor_receipt`, a signer, a verifier, lineage traversal, and receipt
  diffing. It does not perform causal discovery, planning, or stability
  proof itself -- those identities/hashes are supplied by their owning
  subsystems (a causal admission engine, a planner, a stability verifier) and
  this module binds, chains, and verifies them. See `@unsupported` below for
  the parts of the ticket this slice does not implement.

  ## Canonical fields (verbatim from the ticket's field list)

  `episode_id`, `observation_ids`, `admitted_observation_hash`,
  `ontology_hash`, `semantic_projection_hash`, `causal_admission_hash`,
  `planning_problem_hash`, `planner_identity`, `policy_hash`,
  `coupling_result_hash`, `authority_receipt`, `actuation_identity`,
  `consequence_identity`, `valid_time`, `observation_time`,
  `stability_result`, `generator_identity`, `runtime_identity`,
  `predecessor_receipt`, `replay_descriptor`.

  ## Required (non-nullable) fields for incomplete-receipt refusal

  Per the ticket's falsifiers ("a receipt with a missing or malformed
  required field ... is accepted ... instead of being refused"), the
  following fields are required for `new/1` and `sign/1` to succeed:
  `observation_ids`, `admitted_observation_hash`, `ontology_hash`,
  `actuation_identity`, `consequence_identity`, `valid_time`,
  `observation_time`. `episode_id` is not caller-required: `new/1` derives
  it deterministically via `episode_identity/1` when not supplied (per the
  ticket's "deterministic episode identity" requirement), so callers cannot
  accidentally supply a colliding or non-deterministic identity. The
  remaining fields (`semantic_projection_hash`, `causal_admission_hash`,
  `planning_problem_hash`, `planner_identity`, `policy_hash`,
  `coupling_result_hash`, `authority_receipt`, `stability_result`,
  `generator_identity`, `runtime_identity`, `predecessor_receipt`,
  `replay_descriptor`) are optional and pass through as `nil` when the
  owning subsystem has not yet produced them -- an honest reflection of what
  has been admitted, not a fabricated value.

  ## UNSUPPORTED (real, disclosed gaps)

  - Causal identification / discovery: this module never computes
    `causal_admission_hash` from raw data; it only binds whatever opaque
    hash a real causal-admission engine supplies. No causal-discovery engine
    exists in this repo to call, and implementing one is out of scope for
    this slice -- see `docs/jira/v26.9.11/causal-admission-engine.md`.
  - Planning-regime routing / solver selection: `planning_problem_hash` and
    `planner_identity` are bound opaquely; no planner or regime router is
    implemented here.
  - Stability proof: `stability_result` is bound opaquely (whatever term the
    caller supplies, fingerprinted); no stability verifier/prover is
    implemented here. A real stability prover is a distinct, non-trivial
    piece of manufacturing this slice does not fabricate.
  - Receipt signer as cryptographic signature: "signer" here means
    deterministic Merkle-chain hashing (`sign/1` computes `receipt_hash`),
    not an asymmetric-key digital signature. No key management exists in
    this repo for that; a real signature scheme is a distinct follow-on.
  """

  @required_fields [
    :observation_ids,
    :admitted_observation_hash,
    :ontology_hash,
    :actuation_identity,
    :consequence_identity,
    :valid_time,
    :observation_time
  ]

  @optional_fields [
    :episode_id,
    :semantic_projection_hash,
    :causal_admission_hash,
    :planning_problem_hash,
    :planner_identity,
    :policy_hash,
    :coupling_result_hash,
    :authority_receipt,
    :stability_result,
    :generator_identity,
    :runtime_identity,
    :predecessor_receipt,
    :replay_descriptor
  ]

  @all_fields @required_fields ++ @optional_fields ++ [:receipt_hash]

  @enforce_keys @required_fields
  defstruct @all_fields

  @type t :: %__MODULE__{}

  @doc """
  Build an unsigned `ProcessReceipt` from a map/keyword of fields.

  Refuses (returns `{:error, {:incomplete_receipt, [missing_fields]}}`)
  when any required field per the module doc is missing or `nil` -- this is
  the "incomplete-receipt refusal" component named in the ticket's scope,
  enforced at construction time rather than deferred to `sign/1`.
  """
  @spec new(map() | keyword()) ::
          {:ok, t()} | {:error, {:incomplete_receipt, [atom()]}}
  def new(fields) do
    fields = Map.new(fields)

    missing =
      Enum.filter(@required_fields, fn key ->
        not Map.has_key?(fields, key) or is_nil(Map.get(fields, key))
      end)

    case missing do
      [] ->
        struct_fields =
          fields
          |> Map.take(@required_fields ++ @optional_fields)
          |> Map.put(:receipt_hash, nil)
          |> Map.put_new_lazy(:episode_id, fn -> episode_identity(fields) end)

        {:ok, struct(__MODULE__, struct_fields)}

      missing ->
        {:error, {:incomplete_receipt, missing}}
    end
  end

  @doc """
  Deterministic episode identity: a stable fingerprint of the fields that
  identify *this* causal episode (as opposed to the receipt hash, which also
  binds the chain position via `predecessor_receipt`).

  Deterministic and content-addressed: two receipts built from the same
  `observation_ids`/`admitted_observation_hash`/`actuation_identity`/
  `consequence_identity`/`valid_time`/`observation_time` produce the same
  `episode_id`; any real difference in those fields produces a different one
  (the ticket's uniqueness falsifier).
  """
  @spec episode_identity(t() | map()) :: binary()
  def episode_identity(%__MODULE__{} = receipt), do: episode_identity(Map.from_struct(receipt))

  def episode_identity(fields) when is_map(fields) do
    fingerprint(%{
      observation_ids: Map.get(fields, :observation_ids),
      admitted_observation_hash: Map.get(fields, :admitted_observation_hash),
      actuation_identity: Map.get(fields, :actuation_identity),
      consequence_identity: Map.get(fields, :consequence_identity),
      valid_time: json_safe(Map.get(fields, :valid_time)),
      observation_time: json_safe(Map.get(fields, :observation_time))
    })
  end

  @doc """
  Sign (Merkle-chain) a `ProcessReceipt`: computes and sets `receipt_hash` as
  `sha256(canonical(receipt_without_hash) <> (predecessor_receipt || ""))`,
  chaining against `predecessor_receipt` exactly as the existing meta-receipt
  model chains against `R_prev`.

  Refuses incomplete receipts (missing required fields) rather than signing
  a partial receipt -- re-validated here (not just in `new/1`) so a receipt
  mutated after construction cannot bypass refusal.
  """
  @spec sign(t()) :: {:ok, t()} | {:error, {:incomplete_receipt, [atom()]}}
  def sign(%__MODULE__{} = receipt) do
    missing =
      Enum.filter(@required_fields, fn key -> is_nil(Map.get(receipt, key)) end)

    case missing do
      [] ->
        unsigned = %{receipt | receipt_hash: nil}
        payload = unsigned |> Map.from_struct() |> Map.delete(:receipt_hash)
        chain_input = fingerprint(payload) <> (receipt.predecessor_receipt || "")
        receipt_hash = fingerprint(chain_input)
        {:ok, %{receipt | receipt_hash: receipt_hash}}

      missing ->
        {:error, {:incomplete_receipt, missing}}
    end
  end

  @doc """
  Verify a signed `ProcessReceipt`: recomputes `receipt_hash` from the
  receipt's current field values and checks it matches the stored
  `receipt_hash`, and that no required field is missing.

  Returns `:ok` only when both the schema is complete and the recomputed
  hash matches -- a receipt whose bound identities were mutated after
  signing (the ticket's tamper falsifier) fails verification because the
  recomputed hash will not match the stored one.
  """
  @spec verify(t()) ::
          :ok
          | {:error, {:incomplete_receipt, [atom()]}}
          | {:error, {:hash_mismatch, expected: binary(), actual: binary() | nil}}
  def verify(%__MODULE__{receipt_hash: nil}),
    do: {:error, {:hash_mismatch, expected: nil, actual: nil}}

  def verify(%__MODULE__{} = receipt) do
    stored_hash = receipt.receipt_hash

    case sign(%{receipt | receipt_hash: nil}) do
      {:ok, %{receipt_hash: recomputed}} when recomputed == stored_hash ->
        :ok

      {:ok, %{receipt_hash: recomputed}} ->
        {:error, {:hash_mismatch, expected: stored_hash, actual: recomputed}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Lineage traversal: reconstruct the ordered
  `ID(O) -> ID(K) -> ID(P) -> ID(Intent) -> ID(DO) -> ID(Consequence) -> ID(R)`
  chain from a signed receipt's bound fields, per the ticket's stage-to-field
  mapping. Each stage is `{stage, identity_value}`; a stage whose backing
  fields are all `nil` (an optional field the owning subsystem never
  supplied) surfaces as `{stage, nil}` rather than being silently omitted,
  so a caller can see exactly which lineage edges are actually
  reconstructable versus honestly absent.
  """
  @spec lineage(t()) :: [{atom(), binary() | nil}]
  def lineage(%__MODULE__{} = receipt) do
    [
      {:observation, receipt.admitted_observation_hash},
      {:knowledge,
       first_non_nil([
         receipt.causal_admission_hash,
         receipt.semantic_projection_hash,
         receipt.ontology_hash
       ])},
      {:planning, first_non_nil([receipt.planning_problem_hash, receipt.planner_identity])},
      {:intent,
       first_non_nil([
         receipt.policy_hash,
         receipt.coupling_result_hash,
         receipt.authority_receipt
       ])},
      {:do, receipt.actuation_identity},
      {:consequence, first_non_nil([receipt.consequence_identity, receipt.stability_result])},
      {:receipt, receipt.receipt_hash}
    ]
  end

  @doc """
  Receipt diffing: field-by-field structural diff between two receipts,
  returning the map of `field => {left_value, right_value}` for every field
  that differs. An empty map means no material difference. Detects genuine
  divergence between two receipts sharing the same `predecessor_receipt` --
  including the ticket's named falsifier case of differing
  `consequence_identity` or `stability_result` -- because every bound field
  is compared, not a subset.
  """
  @spec diff(t(), t()) :: %{atom() => {term(), term()}}
  def diff(%__MODULE__{} = left, %__MODULE__{} = right) do
    left_map = Map.from_struct(left)
    right_map = Map.from_struct(right)

    @all_fields
    |> Enum.reduce(%{}, fn field, acc ->
      left_value = Map.get(left_map, field)
      right_value = Map.get(right_map, field)

      if left_value == right_value do
        acc
      else
        Map.put(acc, field, {left_value, right_value})
      end
    end)
  end

  # -- deterministic fingerprinting, same canonicalization discipline as
  # Xaas.Actuation.fingerprint/1 (term_to_binary(:deterministic) + sha256),
  # duplicated intentionally rather than made a cross-module dependency:
  # this module must remain independently verifiable/auditable as a receipt
  # primitive without importing the actuation kernel's internals.

  defp fingerprint(term) when is_binary(term) do
    term |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
  end

  defp fingerprint(term) do
    term
    |> canonical_term()
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp canonical_term(%_{} = struct), do: struct |> Map.from_struct() |> canonical_term()

  defp canonical_term(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), canonical_term(value)} end)
    |> Enum.sort()
  end

  defp canonical_term(list) when is_list(list), do: Enum.map(list, &canonical_term/1)

  defp canonical_term(tuple) when is_tuple(tuple),
    do: tuple |> Tuple.to_list() |> Enum.map(&canonical_term/1)

  defp canonical_term(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp canonical_term(other), do: other

  defp json_safe(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp json_safe(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value)
  defp json_safe(value), do: value

  defp first_non_nil(values), do: Enum.find(values, &(not is_nil(&1)))
end
