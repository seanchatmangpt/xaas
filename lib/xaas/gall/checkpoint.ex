defmodule Xaas.Gall.Checkpoint do
  @moduledoc """
  Canonical GALL semantic checkpoint (v26.9.18 GALL Semantic Work Fabric,
  PRD section 43.1): admission validation and projection of the
  `gall:CodingCheckpoint` class.

  A checkpoint is the authority-scoped unit of work a Run/Epoch layer may
  later lease against. This module is the **admission layer only**: a pure
  struct, deterministic validation, typed refusals, and a content-addressed
  graph digest. It performs no actuation, holds no lease, grants no
  authority, and touches no database (Run/Epoch DB integration is a
  separate, later slice -- see `Xaas.Gall.CheckpointBinding` for the pure
  binding struct those layers are expected to reference).

  ## TTL <-> JSON field mapping

  Namespace: `https://semantic-a2a.dev/gall#` (prefix `gall:`).
  The canonical JSON map form below is the primary admission surface;
  `Xaas.Gall.Turtle` parses the TTL form into exactly this map (via the
  real `RDF.Turtle` parser when the `:rdf` application is loadable --
  it is present transitively via `ggen_igniter`, which is dev/test-only,
  so the TTL path degrades to a typed error rather than breaking
  `MIX_ENV=prod` compilation) and then reuses `new/1`, so TTL and JSON
  admission share ONE validation path and produce identical digests.

  | TTL predicate (gall:)      | JSON map key (atom)      | struct field            |
  |----------------------------|--------------------------|-------------------------|
  | (subject IRI)              | `:identity`              | `identity`              |
  | `rdf:type` object          | `:class`                 | `class`                 |
  | `repository` (IRI)         | `:repository`            | `repository`            |
  | `baseSha` (string)         | `:base_sha`              | `base_sha`              |
  | `dependency` (IRI, multi)  | `:dependencies`          | `dependencies`          |
  | `goal` (IRI or string)     | `:goal`                  | `goal`                  |
  | `allowedPath` (str, multi) | `:allowed_paths`         | `allowed_paths`         |
  | `requiresCapability` (mul) | `:requires_capabilities` | `requires_capabilities` |
  | `forbidsCapability` (mul)  | `:forbids_capabilities`  | `forbids_capabilities`  |
  | `acceptance` (str, multi)  | `:acceptance`            | `acceptance`            |
  | `falsifier` (str, multi)   | `:falsifiers`            | `falsifiers`            |
  | `requiresVerifier` (IRI)   | `:verifier`              | `verifier`              |
  | `requiredEvidence` (multi) | `:required_evidence`     | `required_evidence`     |
  | `executionPolicy` (JSON)   | `:execution_policy`      | `execution_policy`      |
  | `standing` (IRI/atom)      | `:standing`              | `standing`              |

  Capability and standing objects are carried as their namespace-local
  names (`gall:Read` -> `"Read"` / `:Read`, `gall:UNKNOWN` -> `"UNKNOWN"`
  / `:UNKNOWN`); `goal` and `verifier` keep their full IRI strings.

  ## Admission rules and typed refusals (PRD section 36)

  Every invalid input returns `{:refused, reason}` -- this layer never
  raises for refusal cases. Refusal vocabulary (public via
  `refusal_reasons/0`):

  | reason                            | fired when |
  |-----------------------------------|------------|
  | `:refused_authority`              | a required field is missing/nil; a list/map field has the wrong shape; `identity` is not `urn:gall:checkpoint:<repo>:<id>`; `standing` is outside the standing vocabulary (a checkpoint claiming an unregistered standing asserts an evidence state it has no authority to claim) |
  | `:refused_subject_mismatch`       | `repository` is not `urn:repo:<owner>:<name>`; the `<repo>` segment of `identity` is not the trailing segment of `repository` (PRD canonical form: `urn:gall:checkpoint:xaas:<id>` binds `urn:repo:seanchatmangpt:xaas`); `base_sha` is not 40-hex |
  | `:refused_capability`             | any capability in `requires_capabilities`/`forbids_capabilities` is outside `capability_vocab/0`, or any capability appears in both lists |
  | `:refused_dependency`             | any dependency is not a `urn:gall:checkpoint:*` IRI, or a dependency equals the checkpoint's own `identity` |
  | `:refused_verifier_identity`      | `verifier` is not in `known_verifiers/0` |
  | `:refused_unregistered_actuation` | `class` is not `"CodingCheckpoint"` |
  | `:refused_stale_lease`            | defined for downstream Run/Epoch lease layers; NOT emitted by this admission layer (there is no lease machinery here to go stale) -- listed so the refusal vocabulary is complete and typeable at this boundary |

  ## Known verifier registry

  `known_verifiers/0` is an explicit, extensible registry (currently
  `XaasChicagoCourt`, the PRD reference verifier, as its absolute IRI)
  rather than free-form-string acceptance: an unverifiable verifier name
  must be refused at admission, not discovered missing at verification
  time.
  """

  @checkpoint_class "CodingCheckpoint"

  @capability_vocab [:Read, :Edit, :Commit, :Write, :Push, :Publish, :Deploy, :Merge]

  @standing_vocab [:UNKNOWN, :PARTIAL_ALIVE, :ALIVE, :BLOCKED, :BUILD_BROKEN, :UNSUPPORTED]

  @known_verifiers ["https://semantic-a2a.dev/gall#XaasChicagoCourt"]

  @required_fields [:identity, :class, :repository, :base_sha, :goal, :verifier, :standing]

  @enforce_keys @required_fields

  defstruct identity: nil,
            class: nil,
            repository: nil,
            base_sha: nil,
            dependencies: [],
            goal: nil,
            allowed_paths: [],
            requires_capabilities: [],
            forbids_capabilities: [],
            acceptance: [],
            falsifiers: [],
            verifier: nil,
            required_evidence: [],
            execution_policy: %{},
            standing: nil

  @type capability :: :Read | :Edit | :Commit | :Write | :Push | :Publish | :Deploy | :Merge

  @type standing :: :UNKNOWN | :PARTIAL_ALIVE | :ALIVE | :BLOCKED | :BUILD_BROKEN | :UNSUPPORTED

  @type refusal_reason ::
          :refused_authority
          | :refused_capability
          | :refused_dependency
          | :refused_stale_lease
          | :refused_subject_mismatch
          | :refused_verifier_identity
          | :refused_unregistered_actuation

  @type t :: %__MODULE__{
          identity: String.t(),
          class: String.t(),
          repository: String.t(),
          base_sha: String.t(),
          dependencies: [String.t()],
          goal: String.t(),
          allowed_paths: [String.t()],
          requires_capabilities: [capability()],
          forbids_capabilities: [capability()],
          acceptance: [String.t()],
          falsifiers: [String.t()],
          verifier: String.t(),
          required_evidence: [String.t()],
          execution_policy: map(),
          standing: standing()
        }

  @spec checkpoint_class() :: String.t()
  def checkpoint_class, do: @checkpoint_class

  @spec capability_vocab() :: [capability(), ...]
  def capability_vocab, do: @capability_vocab

  @spec standing_vocab() :: [standing(), ...]
  def standing_vocab, do: @standing_vocab

  @spec known_verifiers() :: [String.t(), ...]
  def known_verifiers, do: @known_verifiers

  @spec refusal_reasons() :: [refusal_reason(), ...]
  def refusal_reasons,
    do: [
      :refused_authority,
      :refused_capability,
      :refused_dependency,
      :refused_stale_lease,
      :refused_subject_mismatch,
      :refused_verifier_identity,
      :refused_unregistered_actuation
    ]

  @doc """
  Admit a checkpoint from the canonical JSON map/keyword form.

  Returns `{:ok, %Checkpoint{}}` or `{:refused, reason}` (see the
  moduledoc admission table). Never raises for refusal cases. Fields may
  be given as atoms or strings; capabilities/standing are normalized to
  atoms; `base_sha` is case-insensitively validated and normalized to
  lowercase.
  """
  @spec new(map() | keyword()) :: {:ok, t()} | {:refused, refusal_reason()}
  def new(fields) when is_map(fields) or is_list(fields) do
    fields =
      fields
      |> Map.new(fn {key, value} -> {normalize_key(key), value} end)

    with :ok <- require_fields(fields),
         {:ok, identity} <- validate_identity(Map.get(fields, :identity)),
         :ok <- validate_class(Map.get(fields, :class)),
         {:ok, repository} <- validate_repository(Map.get(fields, :repository), identity),
         {:ok, base_sha} <- validate_base_sha(Map.get(fields, :base_sha)),
         {:ok, dependencies} <- validate_dependencies(fields, identity),
         {:ok, requires} <- validate_capabilities(Map.get(fields, :requires_capabilities, [])),
         {:ok, forbids} <- validate_capabilities(Map.get(fields, :forbids_capabilities, [])),
         :ok <- validate_capability_disjointness(requires, forbids),
         {:ok, verifier} <- validate_verifier(Map.get(fields, :verifier)),
         {:ok, standing} <- validate_standing(Map.get(fields, :standing)),
         :ok <- validate_string_lists(fields),
         :ok <- validate_execution_policy(Map.get(fields, :execution_policy, %{})) do
      {:ok,
       struct(__MODULE__, %{
         identity: identity,
         class: @checkpoint_class,
         repository: repository,
         base_sha: base_sha,
         dependencies: strings_for(dependencies),
         goal: normalize_string(Map.get(fields, :goal)),
         allowed_paths: strings_for(Map.get(fields, :allowed_paths, [])),
         requires_capabilities: requires,
         forbids_capabilities: forbids,
         acceptance: strings_for(Map.get(fields, :acceptance, [])),
         falsifiers: strings_for(Map.get(fields, :falsifiers, [])),
         verifier: verifier,
         required_evidence: strings_for(Map.get(fields, :required_evidence, [])),
         execution_policy: Map.get(fields, :execution_policy) || %{},
         standing: standing
       })}
    end
  end

  def new(_other), do: {:refused, :refused_authority}

  @doc """
  Graph digest: `sha256` hex of the canonical serialization of this
  checkpoint (see `canonical_serialization/1`). Deterministic: object keys
  sorted at every level, set-like list fields (`dependencies`,
  `allowed_paths`, `requires_capabilities`, `forbids_capabilities`)
  sorted, declared sequence fields (`acceptance`, `falsifiers`,
  `required_evidence`) kept in declared order, and all whitespace in
  string values normalized (trimmed, internal runs collapsed to one
  space). Two checkpoints with the same semantic content -- regardless of
  key or list insertion order -- MUST produce the same digest.
  """
  @spec graph_digest(t() | map()) :: String.t()
  def graph_digest(%__MODULE__{} = checkpoint),
    do: graph_digest(Map.from_struct(checkpoint))

  def graph_digest(fields) when is_map(fields) do
    :crypto.hash(:sha256, canonical_serialization(fields))
    |> Base.encode16(case: :lower)
  end

  @doc """
  The exact canonical JSON serialization digested by `graph_digest/1`
  (single line, keys sorted at every level, no incidental whitespace).
  Exposed so receipts and reviewers can bind the digest to the bytes it
  was computed over.
  """
  @spec canonical_serialization(t() | map()) :: String.t()
  def canonical_serialization(%__MODULE__{} = checkpoint),
    do: canonical_serialization(Map.from_struct(checkpoint))

  def canonical_serialization(fields) when is_map(fields) do
    fields
    |> canonical_map()
    |> canonical_json()
  end

  @doc """
  Build the pure Run/Epoch binding struct for an admitted checkpoint
  (delegation to `Xaas.Gall.CheckpointBinding.from_checkpoint/1`).
  """
  @spec binding(t()) ::
          {:ok, Xaas.Gall.CheckpointBinding.t()}
          | {:refused, Xaas.Gall.CheckpointBinding.refusal_reason()}
  def binding(%__MODULE__{} = checkpoint),
    do: Xaas.Gall.CheckpointBinding.from_checkpoint(checkpoint)

  ## -- admission internals --

  # String keys are accepted and normalized to the canonical field atoms
  # (JSON admission surface). Unknown string keys pass through untouched
  # and are simply ignored by the field take.
  defp normalize_key(key) when is_atom(key), do: key

  defp normalize_key(key) when is_binary(key) do
    try do
      String.to_existing_atom(key)
    rescue
      ArgumentError -> key
    end
  end

  defp normalize_key(key), do: key

  defp require_fields(fields) do
    missing =
      Enum.filter(@required_fields, fn key ->
        not Map.has_key?(fields, key) or is_nil(Map.get(fields, key))
      end)

    if missing == [], do: :ok, else: {:refused, :refused_authority}
  end

  defp validate_identity(identity) when is_binary(identity) do
    case String.split(String.trim(identity), ":", parts: 4) do
      ["urn", "gall", "checkpoint", rest] ->
        case String.split(rest, ":", parts: 2) do
          [repo_segment, ckpt_id] when repo_segment != "" and ckpt_id != "" ->
            {:ok, String.trim(identity)}

          _ ->
            {:refused, :refused_authority}
        end

      _ ->
        {:refused, :refused_authority}
    end
  end

  defp validate_identity(_), do: {:refused, :refused_authority}

  defp validate_class(class) when is_binary(class) do
    if String.trim(class) == @checkpoint_class do
      :ok
    else
      {:refused, :refused_unregistered_actuation}
    end
  end

  defp validate_class(_), do: {:refused, :refused_unregistered_actuation}

  defp validate_repository(repository, identity) when is_binary(repository) do
    repository = String.trim(repository)

    case String.split(repository, ":", parts: 4) do
      ["urn", "repo", owner, name] when owner != "" and name != "" ->
        # PRD canonical binding: the identity's <repo> segment is the
        # repository's short name (trailing segment), e.g.
        # urn:gall:checkpoint:xaas:<id> <-> urn:repo:seanchatmangpt:xaas.
        identity_repo_segment =
          identity
          |> String.split(":", parts: 4)
          |> Enum.at(3)
          |> String.split(":", parts: 2)
          |> hd()

        if identity_repo_segment != "" and
             String.ends_with?(repository, ":" <> identity_repo_segment) do
          {:ok, repository}
        else
          {:refused, :refused_subject_mismatch}
        end

      _ ->
        {:refused, :refused_subject_mismatch}
    end
  end

  defp validate_repository(_, _), do: {:refused, :refused_subject_mismatch}

  defp validate_base_sha(base_sha) when is_binary(base_sha) do
    normalized = base_sha |> String.trim() |> String.downcase()

    if Regex.match?(~r/^[0-9a-f]{40}$/, normalized) do
      {:ok, normalized}
    else
      {:refused, :refused_subject_mismatch}
    end
  end

  defp validate_base_sha(_), do: {:refused, :refused_subject_mismatch}

  defp validate_dependencies(fields, identity) do
    deps = Map.get(fields, :dependencies, [])

    cond do
      not is_list(deps) ->
        {:refused, :refused_dependency}

      identity in deps ->
        {:refused, :refused_dependency}

      Enum.any?(deps, &(not checkpoint_iri?(&1))) ->
        {:refused, :refused_dependency}

      true ->
        {:ok, strings_for(deps)}
    end
  end

  defp checkpoint_iri?(value) when is_binary(value) do
    case String.split(String.trim(value), ":", parts: 4) do
      ["urn", "gall", "checkpoint", rest] -> rest != ""
      _ -> false
    end
  end

  defp checkpoint_iri?(_), do: false

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

  defp normalize_capability(cap) when cap in @capability_vocab, do: cap

  defp normalize_capability(cap) when is_binary(cap) do
    trimmed = String.trim(cap)
    Enum.find(@capability_vocab, &(Atom.to_string(&1) == trimmed))
  end

  defp normalize_capability(_), do: nil

  defp validate_capability_disjointness(requires, forbids) do
    if Enum.any?(requires, &(&1 in forbids)) do
      {:refused, :refused_capability}
    else
      :ok
    end
  end

  defp validate_verifier(verifier) when is_binary(verifier) do
    normalized = String.trim(verifier)

    if normalized in @known_verifiers do
      {:ok, normalized}
    else
      {:refused, :refused_verifier_identity}
    end
  end

  defp validate_verifier(_), do: {:refused, :refused_verifier_identity}

  defp validate_standing(standing) when standing in @standing_vocab, do: {:ok, standing}

  defp validate_standing(standing) when is_binary(standing) do
    trimmed = String.trim(standing)

    found =
      Enum.find(@standing_vocab, fn vocab_standing ->
        Atom.to_string(vocab_standing) == trimmed
      end)

    if found, do: {:ok, found}, else: {:refused, :refused_authority}
  end

  defp validate_standing(_), do: {:refused, :refused_authority}

  @string_list_fields [:allowed_paths, :acceptance, :falsifiers, :required_evidence]

  defp validate_string_lists(fields) do
    all_valid? =
      Enum.all?(@string_list_fields, fn key ->
        value = Map.get(fields, key, [])
        is_list(value) and Enum.all?(value, &is_binary/1)
      end)

    if all_valid?, do: :ok, else: {:refused, :refused_authority}
  end

  defp validate_execution_policy(policy) when is_map(policy), do: :ok

  defp validate_execution_policy(nil), do: :ok

  defp validate_execution_policy(_), do: {:refused, :refused_authority}

  defp strings_for(values) do
    values
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.uniq()
  end

  defp normalize_string(value) when is_binary(value), do: String.trim(value)
  defp normalize_string(value), do: to_string(value)

  ## -- canonical serialization --

  defp canonical_map(fields) do
    %{
      "identity" => normalize_ws(get_any(fields, :identity)),
      "class" => normalize_ws(get_any(fields, :class)),
      "repository" => normalize_ws(get_any(fields, :repository)),
      "base_sha" => normalize_ws(get_any(fields, :base_sha)),
      "dependencies" =>
        fields |> get_field(:dependencies) |> Enum.map(&normalize_ws/1) |> Enum.sort(),
      "goal" => normalize_ws(get_any(fields, :goal)),
      "allowed_paths" =>
        fields |> get_field(:allowed_paths) |> Enum.map(&normalize_ws/1) |> Enum.sort(),
      "requires_capabilities" =>
        fields
        |> get_field(:requires_capabilities)
        |> Enum.map(&capability_name/1)
        |> Enum.map(&normalize_ws/1)
        |> Enum.sort(),
      "forbids_capabilities" =>
        fields
        |> get_field(:forbids_capabilities)
        |> Enum.map(&capability_name/1)
        |> Enum.map(&normalize_ws/1)
        |> Enum.sort(),
      "acceptance" => fields |> get_field(:acceptance) |> Enum.map(&normalize_ws/1),
      "falsifiers" => fields |> get_field(:falsifiers) |> Enum.map(&normalize_ws/1),
      "verifier" => normalize_ws(get_any(fields, :verifier)),
      "required_evidence" => fields |> get_field(:required_evidence) |> Enum.map(&normalize_ws/1),
      "execution_policy" => policy_map(fields),
      "standing" => normalize_ws(standing_name(get_any(fields, :standing)))
    }
  end

  defp policy_map(fields) do
    policy =
      Map.get(fields, :execution_policy) || Map.get(fields, "execution_policy") || %{}

    if is_map(policy) do
      normalize_ws_deep(Map.new(policy, fn {k, v} -> {to_string(k), v} end))
    else
      %{}
    end
  end

  defp get_any(fields, key) when is_map(fields) do
    value = Map.get(fields, key)
    if is_nil(value), do: Map.get(fields, Atom.to_string(key), ""), else: value
  end

  defp get_field(fields, key) when is_map(fields) do
    value =
      Map.get(fields, key) ||
        Map.get(fields, Atom.to_string(key)) ||
        []

    if is_list(value), do: value, else: [value]
  end

  defp capability_name(cap) when is_atom(cap), do: Atom.to_string(cap)
  defp capability_name(cap) when is_binary(cap), do: cap
  defp capability_name(cap), do: to_string(cap)

  defp standing_name(standing) when is_atom(standing), do: Atom.to_string(standing)
  defp standing_name(standing) when is_binary(standing), do: standing
  defp standing_name(_), do: ""

  defp normalize_ws_deep(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {normalize_ws(to_string(key)), normalize_ws_value(value)} end)
  end

  defp normalize_ws_value(map) when is_map(map), do: normalize_ws_deep(map)

  defp normalize_ws_value(list) when is_list(list), do: Enum.map(list, &normalize_ws_value/1)

  defp normalize_ws_value(value) when is_binary(value), do: normalize_ws(value)

  defp normalize_ws_value(value), do: value

  defp normalize_ws(value) when is_binary(value) do
    value
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp normalize_ws(value), do: value

  # Deterministic JSON encoder: object keys sorted (as strings) at every
  # level, no incidental whitespace. Jason alone does not guarantee map key
  # order, which is exactly what the digest's determinism requirement needs.
  defp canonical_json(value) when is_binary(value), do: Jason.encode!(value)
  defp canonical_json(value) when is_integer(value), do: Integer.to_string(value)
  defp canonical_json(value) when is_float(value), do: Jason.encode!(value)
  defp canonical_json(true), do: "true"
  defp canonical_json(false), do: "false"
  defp canonical_json(nil), do: "null"
  defp canonical_json(value) when is_atom(value), do: Jason.encode!(Atom.to_string(value))

  defp canonical_json(value) when is_list(value),
    do: "[" <> Enum.map_join(value, ",", &canonical_json/1) <> "]"

  defp canonical_json(%Date{} = value), do: Jason.encode!(Date.to_iso8601(value))
  defp canonical_json(%DateTime{} = value), do: Jason.encode!(DateTime.to_iso8601(value))

  defp canonical_json(value) when is_map(value) do
    entries =
      value
      |> Enum.map(fn {key, encoded} -> {canonical_key(key), canonical_json(encoded)} end)
      |> Enum.sort_by(fn {key, _encoded} -> key end)

    "{" <>
      Enum.map_join(entries, ",", fn {key, encoded} -> Jason.encode!(key) <> ":" <> encoded end) <>
      "}"
  end

  defp canonical_key(key) when is_binary(key), do: key
  defp canonical_key(key) when is_atom(key), do: Atom.to_string(key)
  defp canonical_key(key) when is_integer(key), do: Integer.to_string(key)
  defp canonical_key(key), do: to_string(key)
end
