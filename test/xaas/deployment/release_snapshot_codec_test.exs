defmodule Xaas.Deployment.ReleaseSnapshotCodecTest do
  use ExUnit.Case, async: true

  alias Xaas.Deployment.ReleaseSnapshot
  alias Xaas.Deployment.ReleaseSnapshot.Codec
  alias Xaas.Deployment.ReleaseSnapshot.Member

  defp digest(char), do: "sha256:" <> String.duplicate(char, 64)

  defp snapshot do
    members = [
      %Member{
        capability_id: "cap.b",
        version: "2",
        capability_digest: digest("b"),
        admission_digest: digest("c"),
        release_digest: digest("d")
      },
      %Member{
        capability_id: "cap.a",
        version: "1",
        capability_digest: digest("a"),
        admission_digest: digest("c"),
        release_digest: digest("d")
      }
    ]

    {:ok, snapshot} =
      ReleaseSnapshot.freeze(members,
        source_repository: "seanchatmangpt/ash_a2a",
        source_sha: String.duplicate("1", 40),
        release_evidence_digest: digest("e")
      )

    snapshot
  end

  test "JSON round trip re-admits and preserves exact snapshot identity" do
    original = snapshot()
    json = Codec.encode!(original)

    assert {:ok, decoded} = Codec.decode(json)
    assert decoded == original

    payload = Jason.decode!(json)
    assert payload["authority"] == "none"
    assert Enum.map(payload["members"], & &1["capability_id"]) == ["cap.a", "cap.b"]
  end

  test "tampered closure digest is refused on decode" do
    payload =
      snapshot()
      |> Codec.to_map()
      |> Map.put("closure_digest", digest("f"))

    assert {:error, {:serialized_digest_mismatch, "closure_digest", _, _}} =
             payload |> Jason.encode!() |> Codec.decode()
  end

  test "tampered member changes recomputed identity and is refused" do
    payload = Codec.to_map(snapshot())

    [first | rest] = payload["members"]
    changed = Map.put(first, "version", "999")
    payload = Map.put(payload, "members", [changed | rest])

    assert {:error, {:serialized_digest_mismatch, field, _, _}} =
             payload |> Jason.encode!() |> Codec.decode()

    assert field in ["closure_digest", "snapshot_digest"]
  end

  test "serialized authority cannot be widened" do
    payload = snapshot() |> Codec.to_map() |> Map.put("authority", "admin")

    assert {:error, :release_snapshot_schema_missing} =
             payload |> Jason.encode!() |> Codec.decode()
  end
end
