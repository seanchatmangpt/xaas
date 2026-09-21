defmodule Xaas.Gall.SemanticReceipt do
  @moduledoc """
  Semantic receipt for one GALL checkpoint execution (v26.9.18 GALL
  Semantic Work Fabric, PRD section 17 minimum field set).

  A receipt is the evidence artifact that binds WHO executed WHAT against
  WHICH admitted checkpoint content, with WHICH verifier result. It is a
  pure struct: construction-time validation only, no database, no
  actuation, no standing GRANTING -- standing is carried as a field and
  validated against the standing vocabulary; whether that standing is
  true is decided by the verifier that produced this receipt, never by
  this module (`inspection != execution`).

  Construction is fail-closed: a receipt with any missing required field,
  any identity-shape violation, any out-of-vocabulary capability or
  standing, a non-chronological time interval, or an unparseable timestamp
  is refused with a typed reason and never materializes as a struct --
  an incomplete receipt must not be able to pass later as evidence.

  Field notes (PRD section 17 minimum set, all required):

    * `receipt_id` -- issuer-assigned unique receipt identity
    * `checkpoint_iri` / `checkpoint_digest` -- the exact admitted
      checkpoint identity and its `Xaas.Gall.Checkpoint.graph_digest/1`
      content digest (64-hex), so the receipt binds content, not just name
    * `repository` -- `urn:repo:<owner>:<name>`
    * `base_sha` / `candidate_sha` -- 40-hex base and candidate commits
    * `run_id` / `epoch_id` -- the Run/Epoch this execution belonged to
    * `lease_fingerprint` -- fingerprint of the lease under which the
      worker actuated
    * `provider` / `worker_id` / `runtime_version` / `model_identity` --
      who/what actually executed
    * `started_at` / `finished_at` -- `DateTime` (ISO8601 strings are
      accepted and parsed at construction)
    * `admitted_capabilities` -- subset of
      `Xaas.Gall.Checkpoint.capability_vocab/0` actually admitted
    * `observed_tool_classes` -- tool classes the worker actually invoked
    * `claimed_outcome` / `verified_outcome` -- provider-claimed vs
      verifier-checked outcome (free-form strings; the distinction is the
      point)
    * `verifier_id` / `verifier_result` -- which verifier ran and what it
      returned
    * `standing` -- one of `Xaas.Gall.Checkpoint.standing_vocab/0`
    * `replay_identity` -- identity of the replay path that can reproduce
      this execution

  The struct is directly JSON-projectable (`Jason.encode!/1` on
  `Map.from_struct/1`); capability/standing atoms encode as their names.
  """

  @enforce_keys [
    :receipt_id,
    :checkpoint_iri,
    :checkpoint_digest,
    :repository,
    :base_sha,
    :candidate_sha,
    :run_id,
    :epoch_id,
    :lease_fingerprint,
    :provider,
    :worker_id,
    :runtime_version,
    :model_identity,
    :started_at,
    :finished_at,
    :admitted_capabilities,
    :observed_tool_classes,
    :claimed_outcome,
    :verified_outcome,
    :verifier_id,
    :verifier_result,
    :standing,
    :replay_identity
  ]

  defstruct @enforce_keys

  @type refusal_reason :: :refused_authority | :refused_capability | :refused_subject_mismatch

  @type t :: %__MODULE__{
          receipt_id: String.t(),
          checkpoint_iri: String.t(),
          checkpoint_digest: String.t(),
          repository: String.t(),
          base_sha: String.t(),
          candidate_sha: String.t(),
          run_id: String.t(),
          epoch_id: String.t(),
          lease_fingerprint: String.t(),
          provider: String.t(),
          worker_id: String.t(),
          runtime_version: String.t(),
          model_identity: String.t(),
          started_at: DateTime.t(),
          finished_at: DateTime.t(),
          admitted_capabilities: [Xaas.Gall.Checkpoint.capability()],
          observed_tool_classes: [String.t()],
          claimed_outcome: String.t(),
          verified_outcome: String.t(),
          verifier_id: String.t(),
          verifier_result: String.t(),
          standing: Xaas.Gall.Checkpoint.standing(),
          replay_identity: String.t()
        }

  @doc """
  Build (seal the shape of) a semantic receipt from a map/keyword of the
  PRD section 17 minimum fields.

  Returns `{:ok, %SemanticReceipt{}}` or `{:refused, reason}`:

    * `:refused_authority` -- any required field missing/empty; a
      timestamp unparseable or non-chronological (`finished_at` before
      `started_at`); `standing` outside the standing vocabulary
    * `:refused_subject_mismatch` -- `checkpoint_iri` is not a
      `urn:gall:checkpoint:*` IRI; `repository` is not `urn:repo:*`;
      `base_sha`/`candidate_sha` are not 40-hex; `checkpoint_digest` is
      not 64-hex
    * `:refused_capability` -- `admitted_capabilities` is not a list, or
      any entry is outside `Xaas.Gall.Checkpoint.capability_vocab/0`
  """
  @spec new(map() | keyword()) :: {:ok, t()} | {:refused, refusal_reason()}
  def new(fields) when is_map(fields) or is_list(fields) do
    fields = Map.new(fields)

    with :ok <- require_all(fields),
         {:ok, checkpoint_iri} <-
           require_urn_prefix(fields, :checkpoint_iri, "urn:gall:checkpoint:"),
         {:ok, repository} <- require_urn_prefix(fields, :repository, "urn:repo:"),
         {:ok, base_sha} <- require_hex(fields, :base_sha, 40),
         {:ok, candidate_sha} <- require_hex(fields, :candidate_sha, 40),
         {:ok, checkpoint_digest} <- require_hex(fields, :checkpoint_digest, 64),
         {:ok, capabilities} <- validate_capabilities(Map.get(fields, :admitted_capabilities)),
         {:ok, standing} <- validate_standing(Map.get(fields, :standing)),
         {:ok, started_at} <- validate_datetime(fields, :started_at),
         {:ok, finished_at} <- validate_datetime(fields, :finished_at),
         :ok <- validate_chronology(started_at, finished_at) do
      {:ok,
       struct(__MODULE__, %{
         receipt_id: string_field(fields, :receipt_id),
         checkpoint_iri: checkpoint_iri,
         checkpoint_digest: checkpoint_digest,
         repository: repository,
         base_sha: base_sha,
         candidate_sha: candidate_sha,
         run_id: string_field(fields, :run_id),
         epoch_id: string_field(fields, :epoch_id),
         lease_fingerprint: string_field(fields, :lease_fingerprint),
         provider: string_field(fields, :provider),
         worker_id: string_field(fields, :worker_id),
         runtime_version: string_field(fields, :runtime_version),
         model_identity: string_field(fields, :model_identity),
         started_at: started_at,
         finished_at: finished_at,
         admitted_capabilities: capabilities,
         observed_tool_classes: string_list_field(fields, :observed_tool_classes),
         claimed_outcome: string_field(fields, :claimed_outcome),
         verified_outcome: string_field(fields, :verified_outcome),
         verifier_id: string_field(fields, :verifier_id),
         verifier_result: string_field(fields, :verifier_result),
         standing: standing,
         replay_identity: string_field(fields, :replay_identity)
       })}
    end
  end

  def new(_other), do: {:refused, :refused_authority}

  ## -- internals --

  defp require_all(fields) do
    missing =
      Enum.reject(@enforce_keys, fn key ->
        case Map.get(fields, key) do
          nil -> false
          [] -> false
          "" -> false
          _value -> true
        end
      end)

    if missing == [], do: :ok, else: {:refused, :refused_authority}
  end

  defp require_urn_prefix(fields, key, prefix) do
    case Map.get(fields, key) do
      value when is_binary(value) ->
        trimmed = String.trim(value)

        if String.starts_with?(trimmed, prefix) do
          {:ok, trimmed}
        else
          {:refused, :refused_subject_mismatch}
        end

      _ ->
        {:refused, :refused_subject_mismatch}
    end
  end

  defp require_hex(fields, key, length) do
    case Map.get(fields, key) do
      value when is_binary(value) ->
        normalized = value |> String.trim() |> String.downcase()

        if Regex.match?(~r/^[0-9a-f]{#{length}}$/, normalized) do
          {:ok, normalized}
        else
          {:refused, :refused_subject_mismatch}
        end

      _ ->
        {:refused, :refused_subject_mismatch}
    end
  end

  defp validate_capabilities(caps) do
    if is_list(caps) do
      normalized =
        for cap <- caps,
            normalized = normalize_capability(cap),
            not is_nil(normalized),
            do: normalized

      if length(normalized) == length(caps) do
        {:ok, Enum.uniq(normalized)}
      else
        {:refused, :refused_capability}
      end
    else
      {:refused, :refused_capability}
    end
  end

  defp normalize_capability(cap) when is_atom(cap) do
    if cap in Xaas.Gall.Checkpoint.capability_vocab() do
      cap
    else
      nil
    end
  end

  defp normalize_capability(cap) when is_binary(cap) do
    trimmed = String.trim(cap)
    Enum.find(Xaas.Gall.Checkpoint.capability_vocab(), &(Atom.to_string(&1) == trimmed))
  end

  defp normalize_capability(_), do: nil

  defp validate_standing(standing) when is_atom(standing) do
    if standing in Xaas.Gall.Checkpoint.standing_vocab() do
      {:ok, standing}
    else
      {:refused, :refused_authority}
    end
  end

  defp validate_standing(standing) when is_binary(standing) do
    trimmed = String.trim(standing)

    found =
      Enum.find(Xaas.Gall.Checkpoint.standing_vocab(), fn vocab_standing ->
        Atom.to_string(vocab_standing) == trimmed
      end)

    if found, do: {:ok, found}, else: {:refused, :refused_authority}
  end

  defp validate_standing(_), do: {:refused, :refused_authority}

  defp validate_datetime(fields, key) do
    case Map.get(fields, key) do
      %DateTime{} = datetime ->
        {:ok, datetime}

      value when is_binary(value) ->
        case DateTime.from_iso8601(String.trim(value)) do
          {:ok, datetime, _offset} -> {:ok, datetime}
          {:error, _reason} -> {:refused, :refused_authority}
        end

      _ ->
        {:refused, :refused_authority}
    end
  end

  defp validate_chronology(started_at, finished_at) do
    if DateTime.compare(finished_at, started_at) == :lt do
      {:refused, :refused_authority}
    else
      :ok
    end
  end

  defp string_field(fields, key) do
    fields
    |> Map.get(fields_key(fields, key))
    |> to_string()
    |> String.trim()
  end

  defp fields_key(fields, key) do
    if Map.has_key?(fields, key), do: key, else: Atom.to_string(key)
  end

  defp string_list_field(fields, key) do
    fields
    |> Map.get(fields_key(fields, key))
    |> case do
      values when is_list(values) -> values |> Enum.map(&to_string/1) |> Enum.map(&String.trim/1)
      value -> [to_string(value) |> String.trim()]
    end
  end
end
