defmodule Xaas.Deployment.ReleaseSnapshotTest do
  use ExUnit.Case, async: true

  alias Xaas.Deployment.ReleaseSnapshot
  alias Xaas.Deployment.ReleaseSnapshot.Member

  defp digest(char), do: "sha256:" <> String.duplicate(char, 64)

  defp member(id, version \\ "1", char \\ "a") do
    %Member{
      capability_id: id,
      version: version,
      capability_digest: digest(char),
      admission_digest: digest("b"),
      release_digest: digest("c")
    }
  end

  test "freeze is deterministic under member ordering" do
    a = member("a")
    b = member("b", "2", "d")

    assert {:ok, first} = ReleaseSnapshot.freeze([a, b])
    assert {:ok, second} = ReleaseSnapshot.freeze([b, a])

    assert first.closure_digest == second.closure_digest
    assert first.snapshot_digest == second.snapshot_digest
    assert :ok = ReleaseSnapshot.verify(first)
  end

  test "snapshot identity includes provenance while closure identity does not" do
    members = [member("a")]

    assert {:ok, first} =
             ReleaseSnapshot.freeze(members,
               source_repository: "seanchatmangpt/ash_a2a",
               source_sha: String.duplicate("1", 40)
             )

    assert {:ok, second} =
             ReleaseSnapshot.freeze(members,
               source_repository: "seanchatmangpt/ash_a2a",
               source_sha: String.duplicate("2", 40)
             )

    assert first.closure_digest == second.closure_digest
    refute first.snapshot_digest == second.snapshot_digest
  end

  test "neutral SA2A attribute projection round trips into a member" do
    attrs = %{
      release_capability_id: "MyApp.Resource.create",
      release_capability_version: "26.9.26",
      release_capability_digest: digest("a"),
      release_admission_digest: digest("b"),
      release_evidence_digest: digest("c")
    }

    assert {:ok, member} = ReleaseSnapshot.member_from_release_attributes(attrs)
    assert member.capability_id == "MyApp.Resource.create"
    assert member.version == "26.9.26"
  end

  test "duplicate ids refuse even when versions differ" do
    assert {:error, {:duplicate_capability_id, "cap"}} =
             ReleaseSnapshot.freeze([
               member("cap", "1"),
               member("cap", "2", "d")
             ])
  end

  test "select refuses capability outside frozen deployment snapshot" do
    assert {:ok, snapshot} = ReleaseSnapshot.freeze([member("inside")])

    assert {:ok, %Member{capability_id: "inside"}} =
             ReleaseSnapshot.select(snapshot, "inside")

    assert {:error, {:capability_outside_snapshot, "outside", closure}} =
             ReleaseSnapshot.select(snapshot, "outside")

    assert closure == snapshot.closure_digest
  end

  test "diff reports additions removals and version changes separately" do
    assert {:ok, before} =
             ReleaseSnapshot.freeze([
               member("removed"),
               member("changed", "1"),
               member("stable", "1")
             ])

    assert {:ok, after_snapshot} =
             ReleaseSnapshot.freeze([
               member("added"),
               member("changed", "2", "d"),
               member("stable", "1")
             ])

    diff = ReleaseSnapshot.diff(before, after_snapshot)

    assert diff.added == ["added"]
    assert diff.removed == ["removed"]
    assert diff.changed == ["changed"]
    assert String.starts_with?(diff.digest, "sha256:")
  end

  test "rollback manufacture is authority-free and points to verified target" do
    assert {:ok, old_snapshot} = ReleaseSnapshot.freeze([member("cap", "1")])
    assert {:ok, current} = ReleaseSnapshot.freeze([member("cap", "2", "d")])

    assert {:ok, rollback} =
             ReleaseSnapshot.rollback_candidate(current, old_snapshot)

    assert rollback.from_closure == current.closure_digest
    assert rollback.to_closure == old_snapshot.closure_digest
    assert rollback.target_snapshot_digest == old_snapshot.snapshot_digest
    assert rollback.authority == :none
    assert String.starts_with?(rollback.candidate_digest, "sha256:")
  end

  test "invalid evidence and source sha refuse before snapshot manufacture" do
    assert {:error, :release_evidence_digest_invalid} =
             ReleaseSnapshot.freeze([member("cap")],
               release_evidence_digest: "not-a-digest"
             )

    assert {:error, :source_sha_invalid} =
             ReleaseSnapshot.freeze([member("cap")], source_sha: "head")
  end
end
