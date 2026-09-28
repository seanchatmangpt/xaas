defmodule Xaas.Deployment.ReleaseSnapshot do
  @moduledoc """
  Immutable deployment-plane projection of an admitted capability release closure.

  This module is deliberately dependency-neutral: it consumes the public release
  facts emitted by SA2A but does not require an unreleased ash_a2a source tree.
  The closure digest uses the same deterministic tuple projection as
  AshA2A.CapabilityRelease, so the deployment plane can independently recompute
  and verify the exact executable set.

  A snapshot, diff, or rollback candidate is CONSTRUCT-only evidence. None of
  them grants BRCE authority or performs deployment DO.
  """

  @digest ~r/^(?:sha256|blake3):[0-9a-f]{64}$/
  @git_sha ~r/^[0-9a-f]{40}$/

  defmodule Member do
    @moduledoc false
    @enforce_keys [
      :capability_id,
      :version,
      :capability_digest,
      :admission_digest,
      :release_digest
    ]
    defstruct [
      :capability_id,
      :version,
      :capability_digest,
      :admission_digest,
      :release_digest
    ]

    @type t :: %__MODULE__{
            capability_id: String.t(),
            version: String.t(),
            capability_digest: String.t(),
            admission_digest: String.t(),
            release_digest: String.t()
          }
  end

  defmodule Snapshot do
    @moduledoc false
    @enforce_keys [
      :closure_digest,
      :portable_closure_digest,
      :snapshot_digest,
      :members,
      :authority
    ]
    defstruct [
      :closure_digest,
      :portable_closure_digest,
      :snapshot_digest,
      :members,
      :source_repository,
      :source_sha,
      :release_evidence_digest,
      authority: :none
    ]

    @type t :: %__MODULE__{
            closure_digest: String.t(),
            portable_closure_digest: String.t(),
            snapshot_digest: String.t(),
            members: %{required(String.t()) => Member.t()},
            source_repository: String.t() | nil,
            source_sha: String.t() | nil,
            release_evidence_digest: String.t() | nil,
            authority: :none
          }
  end

  defmodule Diff do
    @moduledoc false
    @enforce_keys [:from_closure, :to_closure, :added, :removed, :changed, :digest]
    defstruct [:from_closure, :to_closure, :added, :removed, :changed, :digest]

    @type t :: %__MODULE__{
            from_closure: String.t(),
            to_closure: String.t(),
            added: [String.t()],
            removed: [String.t()],
            changed: [String.t()],
            digest: String.t()
          }
  end

  defmodule RollbackCandidate do
    @moduledoc false
    @enforce_keys [:from_closure, :to_closure, :target_snapshot_digest, :candidate_digest]
    defstruct [
      :from_closure,
      :to_closure,
      :target_snapshot_digest,
      :candidate_digest,
      authority: :none
    ]

    @type t :: %__MODULE__{
            from_closure: String.t(),
            to_closure: String.t(),
            target_snapshot_digest: String.t(),
            candidate_digest: String.t(),
            authority: :none
          }
  end

  alias __MODULE__.{Diff, Member, RollbackCandidate, Snapshot}

  @spec member(keyword()) :: {:ok, Member.t()} | {:error, term()}
  def member(attrs) when is_list(attrs) do
    candidate = %Member{
      capability_id: Keyword.get(attrs, :capability_id),
      version: Keyword.get(attrs, :version),
      capability_digest: Keyword.get(attrs, :capability_digest),
      admission_digest: Keyword.get(attrs, :admission_digest),
      release_digest: Keyword.get(attrs, :release_digest)
    }

    case validate_member(candidate) do
      :ok -> {:ok, candidate}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Translate the neutral attribute projection emitted by
  AshA2A.CapabilityRelease.attributes/1 without importing that module.
  """
  @spec member_from_release_attributes(map()) :: {:ok, Member.t()} | {:error, term()}
  def member_from_release_attributes(attrs) when is_map(attrs) do
    member(
      capability_id: fetch(attrs, :release_capability_id),
      version: fetch(attrs, :release_capability_version),
      capability_digest: fetch(attrs, :release_capability_digest),
      admission_digest: fetch(attrs, :release_admission_digest),
      release_digest: fetch(attrs, :release_evidence_digest)
    )
  end

  @spec freeze([Member.t()], keyword()) :: {:ok, Snapshot.t()} | {:error, term()}
  def freeze(members, opts \\ []) when is_list(members) and is_list(opts) do
    with :ok <- validate_members(members),
         :ok <- unique_ids(members),
         :ok <- validate_provenance(opts) do
      ordered = Enum.sort_by(members, &{&1.capability_id, &1.version, &1.capability_digest})
      closure_digest = digest_term(Enum.map(ordered, &closure_projection/1))
      portable_closure_digest = portable_digest(ordered)
      member_map = Map.new(ordered, &{&1.capability_id, &1})

      snapshot_payload = {
        closure_digest,
        portable_closure_digest,
        Keyword.get(opts, :source_repository),
        Keyword.get(opts, :source_sha),
        Keyword.get(opts, :release_evidence_digest),
        Enum.map(ordered, &closure_projection/1)
      }

      {:ok,
       %Snapshot{
         closure_digest: closure_digest,
         portable_closure_digest: portable_closure_digest,
         snapshot_digest: digest_term(snapshot_payload),
         members: member_map,
         source_repository: Keyword.get(opts, :source_repository),
         source_sha: Keyword.get(opts, :source_sha),
         release_evidence_digest: Keyword.get(opts, :release_evidence_digest)
       }}
    end
  end

  @spec select(Snapshot.t(), String.t()) :: {:ok, Member.t()} | {:error, term()}
  def select(%Snapshot{} = snapshot, capability_id) when is_binary(capability_id) do
    case Map.fetch(snapshot.members, capability_id) do
      {:ok, member} -> {:ok, member}
      :error -> {:error, {:capability_outside_snapshot, capability_id, snapshot.closure_digest}}
    end
  end

  @spec verify(Snapshot.t()) :: :ok | {:error, term()}
  def verify(%Snapshot{} = snapshot) do
    members = Map.values(snapshot.members)

    with :ok <- validate_members(members),
         :ok <- unique_ids(members) do
      ordered = Enum.sort_by(members, &{&1.capability_id, &1.version, &1.capability_digest})
      actual = digest_term(Enum.map(ordered, &closure_projection/1))
      portable_actual = portable_digest(ordered)

      cond do
        actual != snapshot.closure_digest ->
          {:error, {:closure_digest_mismatch, snapshot.closure_digest, actual}}

        portable_actual != snapshot.portable_closure_digest ->
          {:error,
           {:portable_closure_digest_mismatch,
            snapshot.portable_closure_digest,
            portable_actual}}

        true ->
          :ok
      end
    end
  end

  @spec diff(Snapshot.t(), Snapshot.t()) :: Diff.t()
  def diff(%Snapshot{} = from, %Snapshot{} = to) do
    from_ids = MapSet.new(Map.keys(from.members))
    to_ids = MapSet.new(Map.keys(to.members))

    added = to_ids |> MapSet.difference(from_ids) |> MapSet.to_list() |> Enum.sort()
    removed = from_ids |> MapSet.difference(to_ids) |> MapSet.to_list() |> Enum.sort()

    changed =
      from_ids
      |> MapSet.intersection(to_ids)
      |> Enum.filter(fn id -> Map.fetch!(from.members, id) != Map.fetch!(to.members, id) end)
      |> Enum.sort()

    payload = {from.closure_digest, to.closure_digest, added, removed, changed}

    %Diff{
      from_closure: from.closure_digest,
      to_closure: to.closure_digest,
      added: added,
      removed: removed,
      changed: changed,
      digest: digest_term(payload)
    }
  end

  @doc """
  Manufacture a rollback candidate to a previously verified snapshot.

  This does not deploy the target snapshot. The caller must send the candidate
  through the normal authority/admission/actuation boundary.
  """
  @spec rollback_candidate(Snapshot.t(), Snapshot.t()) ::
          {:ok, RollbackCandidate.t()} | {:error, term()}
  def rollback_candidate(%Snapshot{} = current, %Snapshot{} = target) do
    with :ok <- verify(current),
         :ok <- verify(target) do
      payload = {
        current.closure_digest,
        target.closure_digest,
        target.snapshot_digest
      }

      {:ok,
       %RollbackCandidate{
         from_closure: current.closure_digest,
         to_closure: target.closure_digest,
         target_snapshot_digest: target.snapshot_digest,
         candidate_digest: digest_term(payload)
       }}
    end
  end

  defp validate_members([]), do: {:error, :empty_release_snapshot}

  defp validate_members(members) do
    case Enum.find_value(members, fn
           %Member{} = member ->
             case validate_member(member) do
               :ok -> nil
               {:error, reason} -> reason
             end

           other ->
             {:invalid_member, other}
         end) do
      nil -> :ok
      reason -> {:error, reason}
    end
  end

  defp validate_member(%Member{} = member) do
    cond do
      not nonempty?(member.capability_id) -> {:error, :capability_id_required}
      not nonempty?(member.version) -> {:error, :capability_version_required}
      not digest?(member.capability_digest) -> {:error, :capability_digest_invalid}
      not digest?(member.admission_digest) -> {:error, :admission_digest_invalid}
      not digest?(member.release_digest) -> {:error, :release_digest_invalid}
      true -> :ok
    end
  end

  defp unique_ids(members) do
    ids = Enum.map(members, & &1.capability_id)

    case ids -- Enum.uniq(ids) do
      [] -> :ok
      [duplicate | _] -> {:error, {:duplicate_capability_id, duplicate}}
    end
  end

  defp validate_provenance(opts) do
    source_repository = Keyword.get(opts, :source_repository)
    source_sha = Keyword.get(opts, :source_sha)
    evidence = Keyword.get(opts, :release_evidence_digest)

    cond do
      not is_nil(source_repository) and not nonempty?(source_repository) ->
        {:error, :source_repository_invalid}

      not is_nil(source_sha) and not (is_binary(source_sha) and Regex.match?(@git_sha, source_sha)) ->
        {:error, :source_sha_invalid}

      not is_nil(evidence) and not digest?(evidence) ->
        {:error, :release_evidence_digest_invalid}

      true ->
        :ok
    end
  end

  defp closure_projection(%Member{} = member) do
    {
      member.capability_id,
      member.version,
      member.capability_digest,
      member.admission_digest,
      member.release_digest
    }
  end

  @doc """
  RFC 8785/JCS closure identity shared with AshA2A.CapabilityRelease.

  This is additive to the compatibility closure digest and is intended for
  independent recomputation by non-BEAM tooling.
  """
  @spec portable_digest([Member.t()]) :: String.t()
  def portable_digest(members) when is_list(members) do
    canonical_members =
      members
      |> Enum.sort_by(&{&1.capability_id, &1.version, &1.capability_digest})
      |> Enum.map(fn member ->
        %{
          "capability_id" => member.capability_id,
          "version" => member.version,
          "capability_digest" => member.capability_digest,
          "admission_digest" => member.admission_digest,
          "release_digest" => member.release_digest
        }
      end)

    payload = %{
      "schema" => "chatman.release-closure/v1",
      "members" => canonical_members
    }

    "sha256:" <>
      (:crypto.hash(:sha256, Jcs.encode(payload))
       |> Base.encode16(case: :lower))
  end

  defp fetch(map, key), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
  defp nonempty?(value), do: is_binary(value) and String.trim(value) != ""
  defp digest?(value), do: is_binary(value) and Regex.match?(@digest, value)

  defp digest_term(term) do
    "sha256:" <>
      (:crypto.hash(:sha256, :erlang.term_to_binary(term, [:deterministic]))
       |> Base.encode16(case: :lower))
  end
end
