defmodule Xaas.Deployment.ReleaseSnapshot.Codec do
  @moduledoc """
  Canonical JSON transport for Xaas.Deployment.ReleaseSnapshot.

  Decode always reconstructs members and recomputes the closure digest through
  ReleaseSnapshot.freeze/2. A serialized digest is evidence to compare, never
  trusted as the source of truth.
  """

  alias Xaas.Deployment.ReleaseSnapshot
  alias Xaas.Deployment.ReleaseSnapshot.Snapshot

  @schema "xaas.release-snapshot/v1"

  @spec encode(Snapshot.t()) :: {:ok, String.t()} | {:error, term()}
  def encode(%Snapshot{} = snapshot) do
    with :ok <- ReleaseSnapshot.verify(snapshot) do
      Jason.encode(to_map(snapshot))
    end
  end

  @spec encode!(Snapshot.t()) :: String.t()
  def encode!(%Snapshot{} = snapshot) do
    case encode(snapshot) do
      {:ok, json} -> json
      {:error, reason} -> raise ArgumentError, "invalid release snapshot: #{inspect(reason)}"
    end
  end

  @spec decode(String.t()) :: {:ok, Snapshot.t()} | {:error, term()}
  def decode(json) when is_binary(json) do
    with {:ok, payload} <- Jason.decode(json),
         :ok <- schema(payload),
         {:ok, members} <- decode_members(Map.get(payload, "members")),
         {:ok, snapshot} <-
           ReleaseSnapshot.freeze(members,
             source_repository: Map.get(payload, "source_repository"),
             source_sha: Map.get(payload, "source_sha"),
             release_evidence_digest: Map.get(payload, "release_evidence_digest")
           ),
         :ok <- compare_digest("closure_digest", snapshot.closure_digest, payload),
         :ok <- compare_digest("snapshot_digest", snapshot.snapshot_digest, payload) do
      {:ok, snapshot}
    end
  end

  @spec to_map(Snapshot.t()) :: map()
  def to_map(%Snapshot{} = snapshot) do
    %{
      "schema" => @schema,
      "closure_digest" => snapshot.closure_digest,
      "snapshot_digest" => snapshot.snapshot_digest,
      "source_repository" => snapshot.source_repository,
      "source_sha" => snapshot.source_sha,
      "release_evidence_digest" => snapshot.release_evidence_digest,
      "authority" => "none",
      "members" =>
        snapshot.members
        |> Map.values()
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
    }
  end

  defp schema(%{"schema" => @schema, "authority" => "none"}), do: :ok
  defp schema(%{"schema" => other}), do: {:error, {:unsupported_release_snapshot_schema, other}}
  defp schema(_), do: {:error, :release_snapshot_schema_missing}

  defp decode_members(members) when is_list(members) and members != [] do
    members
    |> Enum.reduce_while({:ok, []}, fn attrs, {:ok, acc} ->
      case decode_member(attrs) do
        {:ok, member} -> {:cont, {:ok, [member | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, reversed} -> {:ok, Enum.reverse(reversed)}
      error -> error
    end
  end

  defp decode_members(_), do: {:error, :release_snapshot_members_invalid}

  defp decode_member(attrs) when is_map(attrs) do
    ReleaseSnapshot.member(
      capability_id: Map.get(attrs, "capability_id"),
      version: Map.get(attrs, "version"),
      capability_digest: Map.get(attrs, "capability_digest"),
      admission_digest: Map.get(attrs, "admission_digest"),
      release_digest: Map.get(attrs, "release_digest")
    )
  end

  defp decode_member(_), do: {:error, :release_snapshot_member_invalid}

  defp compare_digest(field, actual, payload) do
    case Map.get(payload, field) do
      ^actual -> :ok
      expected when is_binary(expected) -> {:error, {:serialized_digest_mismatch, field, expected, actual}}
      _ -> {:error, {:serialized_digest_missing, field}}
    end
  end
end
