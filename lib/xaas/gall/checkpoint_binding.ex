defmodule Xaas.Gall.CheckpointBinding do
  @moduledoc """
  Pure identity-binding struct tying a GALL checkpoint to the Run/Epoch
  layers that will later claim it (v26.9.18 GALL Semantic Work Fabric,
  PRD section 43.1, requirement 3).

  This is deliberately ONLY data plus construction-time shape validation:
  it does NOT modify `Xaas.Ultracode.Run` / `Xaas.Ultracode.Epoch`
  (those Ash resources and any migrations are explicitly out of scope for
  this slice). Run/Epoch code that adopts the binding later holds one of
  these structs alongside its own identity, so the checkpoint a run was
  authorized against is pinned by content, not by conversation:

      * `checkpoint_iri` -- the admitted checkpoint's identity
        (`urn:gall:checkpoint:<repo>:<id>`)
      * `repository`     -- the checkpoint's registered repository
        (`urn:repo:<owner>:<name>`)
      * `base_sha`       -- the 40-hex base commit the checkpoint admits
        against
      * `graph_digest`   -- `Xaas.Gall.Checkpoint.graph_digest/1` of the
        exact admitted checkpoint content (64-hex sha256)

  `matches_checkpoint?/2` lets a Run/Epoch layer falsify a binding against
  the checkpoint it claims to bind (subject mismatch, stale content, or
  drift between the bound digest and the current digest) -- the same
  checks an epoch-level verifier would apply before honoring a lease.
  """

  @enforce_keys [:checkpoint_iri, :repository, :base_sha, :graph_digest]

  defstruct [:checkpoint_iri, :repository, :base_sha, :graph_digest]

  @type refusal_reason :: :refused_authority | :refused_subject_mismatch

  @type t :: %__MODULE__{
          checkpoint_iri: String.t(),
          repository: String.t(),
          base_sha: String.t(),
          graph_digest: String.t()
        }

  @doc """
  Build a binding from raw fields.

  Returns `{:ok, %CheckpointBinding{}}` or
  `{:refused, :refused_authority}` when any field is missing, and
  `{:refused, :refused_subject_mismatch}` when any field fails its
  identity shape (`urn:gall:checkpoint:*` IRI, `urn:repo:*` repository,
  40-hex `base_sha`, 64-hex `graph_digest`).
  """
  @spec new(map() | keyword()) :: {:ok, t()} | {:refused, refusal_reason()}
  def new(fields) when is_map(fields) or is_list(fields) do
    fields = Map.new(fields)

    with {:ok, checkpoint_iri} <- require_iri(fields, :checkpoint_iri),
         {:ok, repository} <- require_iri(fields, :repository),
         {:ok, base_sha} <- require_hex(fields, :base_sha, 40),
         {:ok, graph_digest} <- require_hex(fields, :graph_digest, 64) do
      if String.starts_with?(checkpoint_iri, "urn:gall:checkpoint:") and
           String.starts_with?(repository, "urn:repo:") do
        {:ok,
         struct(__MODULE__, %{
           checkpoint_iri: checkpoint_iri,
           repository: repository,
           base_sha: base_sha,
           graph_digest: graph_digest
         })}
      else
        {:refused, :refused_subject_mismatch}
      end
    end
  end

  def new(_other), do: {:refused, :refused_authority}

  @doc """
  Bind an already-admitted checkpoint: derives every field from the
  checkpoint itself, including its content digest. Refuses (typed) when
  the checkpoint fails its own identity shapes -- which cannot happen for
  a value produced by `Xaas.Gall.Checkpoint.new/1`, so a refusal here
  means the caller passed something that was never admitted.
  """
  @spec from_checkpoint(Xaas.Gall.Checkpoint.t()) :: {:ok, t()} | {:refused, refusal_reason()}
  def from_checkpoint(%Xaas.Gall.Checkpoint{} = checkpoint) do
    new(%{
      checkpoint_iri: checkpoint.identity,
      repository: checkpoint.repository,
      base_sha: checkpoint.base_sha,
      graph_digest: Xaas.Gall.Checkpoint.graph_digest(checkpoint)
    })
  end

  def from_checkpoint(_other), do: {:refused, :refused_authority}

  @doc """
  `true` only when the binding still pins exactly this checkpoint: same
  identity, same repository, same base SHA, and the checkpoint's current
  content digest equals the bound digest. Any drift (edited checkpoint,
  wrong subject, moved base) returns `false` -- the caller's signal to
  refuse the lease, not to silently rebind.
  """
  @spec matches_checkpoint?(t(), Xaas.Gall.Checkpoint.t()) :: boolean()
  def matches_checkpoint?(%__MODULE__{} = binding, %Xaas.Gall.Checkpoint{} = checkpoint) do
    binding.checkpoint_iri == checkpoint.identity and
      binding.repository == checkpoint.repository and
      binding.base_sha == checkpoint.base_sha and
      binding.graph_digest == Xaas.Gall.Checkpoint.graph_digest(checkpoint)
  end

  ## -- internals --

  defp require_iri(fields, key) do
    case Map.get(fields, key) do
      value when is_binary(value) and value != "" ->
        {:ok, String.trim(value)}

      _ ->
        {:refused, :refused_authority}
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
end
