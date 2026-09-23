defmodule Xaas.Ultracode.SemanticWorkTest do
  # SemanticCase, not bare DataCase: these tests touch Xaas.Repo Ash
  # resources, so they need the scoped shared Xaas.Repo sandbox owner the
  # template establishes (DataCase only owns Xaas.LegacyRepo) -- the root
  # fix for the 5 DBConnection.OwnershipError reds at
  # SemanticWork.materialize/2.
  use Xaas.Ultracode.SemanticCase, async: false

  alias Xaas.Ultracode.SemanticWork

  test "admits a typed execution descriptor with exact upstream receipt evidence", %{sha: sha} do
    assert {:ok, admitted} = SemanticWork.admit(checkpoint(sha), binding: :graph)
    assert admitted.execution_policy == :continuous_epoch_run
    assert [dependency] = admitted.dependencies
    assert dependency.receipt_iri == "urn:gall:receipt:dep-1"
    assert dependency.receipt_digest == "sha256:" <> String.duplicate("c", 64)
  end

  test "UNKNOWN dependency is refused rather than treated as frontier eligibility", %{sha: sha} do
    input =
      update_in(checkpoint(sha), [:dependencies, Access.at(0)], fn dependency ->
        %{dependency | observed_standing: "UNKNOWN"}
      end)

    assert {:error, {:refused_dependency, {:standing, "urn:gall:work-order:dep-1"}}} =
             SemanticWork.admit(input, binding: :graph)
  end

  test "dependency without exact receipt digest is refused", %{sha: sha} do
    input =
      update_in(checkpoint(sha), [:dependencies, Access.at(0)], fn dependency ->
        %{dependency | receipt_digest: "main"}
      end)

    assert {:error, {:refused_dependency, {:invalid, :receipt_digest}}} =
             SemanticWork.admit(input, binding: :graph)
  end

  test "duplicate dependency identity is refused", %{sha: sha} do
    [dependency] = checkpoint(sha).dependencies
    input = %{checkpoint(sha) | dependencies: [dependency, dependency]}

    assert {:error, {:refused_dependency, :duplicate_work_order_identity}} =
             SemanticWork.admit(input, binding: :graph)
  end

  describe "admission_digest integrity envelope" do
    test "absent is today's behavior", %{sha: sha} do
      assert {:ok, admitted} = SemanticWork.admit(checkpoint(sha), binding: :graph)
      refute Map.get(admitted, :admission_digest)
    end

    test "equal to graph_digest is admitted", %{sha: sha} do
      digest = "sha256:" <> String.duplicate("a", 64)

      assert {:ok, admitted} =
               SemanticWork.admit(Map.put(checkpoint(sha), :admission_digest, digest),
                 binding: :graph
               )

      assert admitted.admission_digest == digest
    end

    test "a digest altered after admission is refused (falsifier: tamper accepted)", %{sha: sha} do
      altered = "sha256:" <> String.duplicate("b", 64)

      assert {:error, {:refused_semantic_work, {:admission_digest_mismatch, ^altered}}} =
               SemanticWork.admit(Map.put(checkpoint(sha), :admission_digest, altered),
                 binding: :graph
               )
    end

    test "a malformed admission digest is refused", %{sha: sha} do
      assert {:error, {:refused_semantic_work, {:invalid, :admission_digest}}} =
               SemanticWork.admit(Map.put(checkpoint(sha), :admission_digest, "main"),
                 binding: :graph
               )

      assert {:error, {:refused_semantic_work, {:invalid, :admission_digest}}} =
               SemanticWork.admit(Map.put(checkpoint(sha), :admission_digest, 42),
                 binding: :graph
               )
    end
  end

  test "branch names cannot stand in for exact base identity", %{sha: sha} do
    assert {:error, {:refused_semantic_work, {:invalid, :base_sha}}} =
             SemanticWork.admit(%{checkpoint(sha) | base_sha: "main"}, binding: :graph)
  end

  test "runtime does not own a second semantic frontier selector" do
    refute function_exported?(SemanticWork, :frontier, 1)
  end

  test "continuous policy uses Run.start and leaves the exact-worktree Epoch expected", %{
    sha: sha
  } do
    assert {:ok, %{run: run, epoch: epoch, worktree: worktree}} =
             SemanticWork.materialize(checkpoint(sha), binding: :graph)

    assert run.state == :running
    assert run.work_order_iri == "urn:gall:work-order:xaas:001"
    assert run.checkpoint_iri == "urn:gall:checkpoint:xaas:001"
    assert run.repository_identity == "seanchatmangpt/xaas"
    assert run.execution_repo_alias == "demo"
    assert run.execution_policy == :continuous_epoch_run

    assert run.dependency_evidence["urn:gall:work-order:dep-1"]["receipt_iri"] ==
             "urn:gall:receipt:dep-1"

    assert epoch.state == :expected
    assert epoch.worktree == worktree

    assert epoch.exact_subject ==
             "urn:gall:work-order:xaas:001@sha256:" <> String.duplicate("a", 64)

    assert git!(worktree, ["rev-parse", "HEAD"]) == sha
  end

  test "autonomic-wave policy uses the same first Epoch then starts it immediately", %{sha: sha} do
    input =
      checkpoint(sha,
        work_order_iri: "urn:gall:work-order:xaas:wave",
        checkpoint_iri: "urn:gall:checkpoint:xaas:wave",
        execution_policy: "autonomic_wave_attempt"
      )

    assert {:ok, %{run: run, epoch: epoch}} = SemanticWork.materialize(input, binding: :graph)

    assert run.state == :running
    assert run.execution_policy == :autonomic_wave_attempt
    assert epoch.state == :running
    assert epoch.exact_subject =~ "urn:gall:work-order:xaas:wave@"
  end

  test "two work orders in the same canonical graph manufacture distinct worktrees", %{sha: sha} do
    a = checkpoint(sha, work_order_iri: "urn:gall:work-order:xaas:a")
    b = checkpoint(sha, work_order_iri: "urn:gall:work-order:xaas:b")

    assert {:ok, %{worktree: path_a}} = SemanticWork.materialize(a, binding: :graph)
    assert {:ok, %{worktree: path_b}} = SemanticWork.materialize(b, binding: :graph)

    refute path_a == path_b
    assert File.dir?(path_a)
    assert File.dir?(path_b)
  end

  test "receipt Turtle binds work-order identity and upstream receipt provenance", %{sha: sha} do
    input = checkpoint(sha)
    run = %{id: "run-1"}
    epoch = %{id: "epoch-1", final_head: String.duplicate("d", 40)}
    receipt = %{id: "receipt-1", outcome: :alive}

    ttl = SemanticWork.receipt_turtle(input, run, epoch, receipt)

    assert ttl =~ "gall:workOrder <urn:gall:work-order:xaas:001>"
    assert ttl =~ "gall:repositoryIdentity \"seanchatmangpt/xaas\""
    assert ttl =~ "gall:executionRepoAlias \"demo\""
    assert ttl =~ "gall:executionPolicy \"continuous_epoch_run\""
    assert ttl =~ "prov:wasDerivedFrom <urn:gall:receipt:dep-1>"
    assert ttl =~ "<urn:gall:receipt:dep-1> a gall:Receipt, prov:Entity"
    assert ttl =~ "gall:receiptDigest \"sha256:#{String.duplicate("c", 64)}\""
    assert ttl =~ "gall:candidateSha \"#{epoch.final_head}\""
  end

  # SJ-001 falsifier 1: "materialize accepts a WorkOrder whose digest was
  # altered after admission". The descriptor under test is the REAL output of
  # GgenIgniter.SemanticJira.admit_work_order/1 + the graph-side projection
  # (docs/sjira/v26.9.21/e2e_project.exs), committed as evidence, so these
  # probes tamper with what the real producer emits, not with a hand-built map.
  describe "digest binding (falsifier: digest altered after admission)" do
    alias Xaas.Ultracode.SemanticWork.AdmissionBinding

    test "untampered real descriptor is admitted in every binding mode" do
      descriptor = real_descriptor()

      # :auto is refused by the landed binding law
      for mode <- [:snapshot, :graph] do
        assert {:ok, admitted} = SemanticWork.admit(descriptor, binding: mode)
        assert admitted.graph_digest == descriptor["graph_digest"]
      end

      assert {:ok, _} = SemanticWork.admit(descriptor)
    end

    test "XaaS recomputes exactly the digests the real graph admission produced" do
      descriptor = real_descriptor()
      snapshot = descriptor["admitted_work_order"]

      assert AdmissionBinding.snapshot_digest(snapshot) == snapshot["work_order_digest"]
      assert snapshot["work_order_digest"] == descriptor["graph_digest"]

      assert AdmissionBinding.definition_digest(snapshot) ==
               descriptor["bridge"]["definition_digest"]
    end

    test "probe A: graph_digest altered, envelope kept -> envelope mismatch" do
      altered = flip(real_descriptor()["graph_digest"])
      tampered = Map.put(real_descriptor(), "graph_digest", altered)

      # :auto is refused by the landed binding law
      for mode <- [:snapshot, :graph] do
        assert {:error, {:refused_semantic_work, {:admission_digest_mismatch, _}}} =
                 SemanticWork.admit(tampered, binding: mode)
      end
    end

    test "probe B: graph_digest altered, envelope OMITTED -> refused, not accepted" do
      descriptor = real_descriptor()
      digest = descriptor["graph_digest"]

      tampered =
        descriptor
        |> Map.put("graph_digest", flip(digest))
        |> Map.delete("admission_digest")

      # the snapshot the producer carried is the anchor XaaS recomputes from
      # :auto is refused by the landed binding law (guard WIP, see SemanticWork moduledoc)
      for mode <- [:snapshot] do
        assert {:error,
                {:refused_semantic_work, {:graph_digest_unbound, :admitted_work_order, ^digest}}} =
                 SemanticWork.admit(tampered, binding: mode)
      end

      # snapshot dropped too: the real bridge's own snapshot digest is the anchor
      bridge_only = Map.delete(tampered, "admitted_work_order")

      assert {:error,
              {:refused_semantic_work,
               {:graph_digest_unbound, :bridge_source_snapshot_digest, ^digest}}} =
               SemanticWork.admit(bridge_only, binding: :snapshot)
    end

    test "probe C: graph_digest and envelope altered consistently -> refused" do
      descriptor = real_descriptor()
      altered = flip(descriptor["graph_digest"])

      tampered =
        descriptor |> Map.put("graph_digest", altered) |> Map.put("admission_digest", altered)

      # the two in-band copies agree with each other; the recomputed snapshot does not
      # :auto is refused by the landed binding law
      for mode <- [:snapshot, :graph] do
        assert {:error,
                {:refused_semantic_work,
                 {:admission_anchor_disagree, :admitted_work_order, :admission_digest}}} =
                 SemanticWork.admit(tampered, binding: mode)
      end

      # without the snapshot, the bridge's copy disagrees with the altered pair
      assert {:error,
              {:refused_semantic_work,
               {:admission_anchor_disagree, :bridge_source_snapshot_digest, :admission_digest}}} =
               SemanticWork.admit(Map.delete(tampered, "admitted_work_order"), binding: :snapshot)
    end

    test "a snapshot edited after admission is refused as stale" do
      descriptor = real_descriptor()
      edited = put_in(descriptor, ["admitted_work_order", "title"], "altered after admission")

      assert {:error, {:refused_semantic_work, {:admitted_snapshot_stale, recomputed}}} =
               SemanticWork.admit(edited)

      assert recomputed =~ ~r/\Asha256:[0-9a-f]{64}\z/
      refute recomputed == descriptor["graph_digest"]
    end

    test "a re-sealed forged snapshot cannot agree with the bridge's copies" do
      descriptor = real_descriptor()

      # standing is part of the snapshot digest but not of the definition
      # digest: forging it and re-sealing leaves the bridge's definition digest
      # intact and only the snapshot digest moves, away from the bridge's copy
      resealed = reseal(descriptor["admitted_work_order"], "standing", "ALIVE")
      forged = Map.put(descriptor, "admitted_work_order", resealed)

      # the merged verify() orders field projection checks before digest
      # disagreement; either typed refusal proves the forgery is caught
      assert {:error, {:refused_semantic_work, {:admitted_snapshot_mismatch, _field}}} =
               SemanticWork.admit(forged)

      # a re-sealed definition edit is caught by the bridge's definition digest
      retitled = reseal(descriptor["admitted_work_order"], "title", "forged")

      assert {:error,
              {:refused_semantic_work, {:admitted_snapshot_mismatch, :bridge_definition_digest}}} =
               SemanticWork.admit(Map.put(descriptor, "admitted_work_order", retitled))
    end

    test "descriptor fields must be the snapshot's" do
      descriptor = real_descriptor()

      other_sha = String.duplicate("f", 40)

      assert {:error, {:refused_semantic_work, {:admitted_snapshot_mismatch, :base_sha}}} =
               SemanticWork.admit(Map.put(descriptor, "base_sha", other_sha))

      assert {:error,
              {:refused_semantic_work, {:admitted_snapshot_mismatch, :repository_identity}}} =
               SemanticWork.admit(Map.put(descriptor, "repository_identity", "someone/else"))

      assert {:error, {:refused_semantic_work, {:admitted_snapshot_mismatch, :work_order_iri}}} =
               SemanticWork.admit(
                 Map.put(descriptor, "work_order_iri", "urn:semantic-jira:work-order:SJ-999")
               )

      assert {:error,
              {:refused_semantic_work, {:admitted_snapshot_mismatch, :bridge_definition_digest}}} =
               SemanticWork.admit(
                 put_in(
                   descriptor["bridge"]["definition_digest"],
                   flip(descriptor["bridge"]["definition_digest"])
                 )
               )
    end

    test "snapshot mode refuses a descriptor stripped of every independent anchor" do
      descriptor = real_descriptor()
      digest = descriptor["graph_digest"]

      stripped =
        descriptor
        |> Map.delete("admitted_work_order")
        |> update_in(["bridge"], &Map.delete(&1, "source_snapshot_digest"))
        |> Map.put("graph_digest", flip(digest))
        |> Map.delete("admission_digest")

      assert {:error, {:refused_semantic_work, :admission_anchor_missing}} =
               SemanticWork.admit(stripped, binding: :snapshot)

      # the envelope alone is a second in-band copy, not an independent anchor
      altered = flip(digest)

      envelope_only =
        stripped |> Map.put("graph_digest", altered) |> Map.put("admission_digest", altered)

      assert {:error, {:refused_semantic_work, :admission_anchor_missing}} =
               SemanticWork.admit(envelope_only, binding: :snapshot)

      # Landed law: the DEFAULT binding is fail-closed :snapshot (an
      # anchor-less descriptor is refused — see the first assertion above).
      # "Today's behavior" survives as the explicit :graph opt-out.
      assert {:ok, _} = SemanticWork.admit(stripped, binding: :graph)
    end

    test "graph mode leaves a graph-wide graph_digest unbound (the real producer's contract)" do
      descriptor = real_descriptor()

      graph_wide =
        descriptor
        |> Map.delete("admitted_work_order")
        |> Map.delete("admission_digest")
        |> Map.put("graph_digest", "sha256:" <> String.duplicate("a", 64))

      assert {:ok, _} = SemanticWork.admit(graph_wide, binding: :graph)
      # the default (:snapshot) refuses a graph-wide digest: its remaining
      # bridge anchor is left unbound by design in this mode
      assert {:error,
              {:refused_semantic_work, {:graph_digest_unbound, :bridge_source_snapshot_digest, _}}} =
               SemanticWork.admit(graph_wide)

      assert {:error,
              {:refused_semantic_work, {:graph_digest_unbound, :bridge_source_snapshot_digest, _}}} =
               SemanticWork.admit(graph_wide, binding: :snapshot)
    end

    test "descriptors without any anchor keep today's behavior; snapshot mode refuses them", %{
      sha: sha
    } do
      # the landed default is fail-closed :snapshot; "today's behavior" is the
      # explicit :graph opt-out
      assert {:error, {:refused_semantic_work, :admission_anchor_missing}} =
               SemanticWork.admit(checkpoint(sha))

      assert {:ok, _} = SemanticWork.admit(checkpoint(sha), binding: :graph)

      assert {:error, {:refused_semantic_work, :admission_anchor_missing}} =
               SemanticWork.admit(checkpoint(sha), binding: :snapshot)
    end

    test "malformed anchors and options are typed refusals" do
      descriptor = real_descriptor()

      assert {:error, {:refused_semantic_work, {:invalid, :admitted_work_order}}} =
               SemanticWork.admit(Map.put(descriptor, "admitted_work_order", "not a map"))

      assert {:error, {:refused_semantic_work, {:invalid, :admitted_work_order}}} =
               SemanticWork.admit(
                 put_in(descriptor["admitted_work_order"]["work_order_digest"], "main")
               )

      assert {:error, {:refused_semantic_work, {:invalid, :bridge_source_snapshot_digest}}} =
               SemanticWork.admit(put_in(descriptor["bridge"]["source_snapshot_digest"], "main"))

      assert {:error, {:refused_semantic_work, {:invalid_binding_option, :bogus}}} =
               SemanticWork.admit(descriptor, binding: :bogus)
    end

    test "materialize refuses a tampered descriptor before any worktree or Run exists" do
      descriptor = real_descriptor()

      tampered =
        descriptor
        |> Map.put("graph_digest", flip(descriptor["graph_digest"]))
        |> Map.delete("admission_digest")

      assert {:error, {:refused_semantic_work, {:graph_digest_unbound, :admitted_work_order, _}}} =
               SemanticWork.materialize(tampered, binding: :snapshot)

      assert {:error, {:refused_semantic_work, {:graph_digest_unbound, :admitted_work_order, _}}} =
               SemanticWork.materialize(tampered)
    end
  end

  defp checkpoint(sha, overrides \\ []) do
    base = %{
      work_order_iri: "urn:gall:work-order:xaas:001",
      checkpoint_iri: "urn:gall:checkpoint:xaas:001",
      graph_digest: "sha256:" <> String.duplicate("a", 64),
      repository_identity: "seanchatmangpt/xaas",
      execution_repo_alias: "demo",
      base_sha: sha,
      goal: "Implement the admitted semantic-work subject.",
      provider: "zcode",
      verifier_suite: "semantic-test",
      execution_policy: "continuous_epoch_run",
      dependencies: [
        %{
          work_order_iri: "urn:gall:work-order:dep-1",
          required_standing: "ALIVE",
          observed_standing: "ALIVE",
          receipt_iri: "urn:gall:receipt:dep-1",
          receipt_digest: "sha256:" <> String.duplicate("c", 64)
        }
      ],
      standing: "UNKNOWN"
    }

    Enum.into(overrides, base)
  end

  # The committed evidence descriptor is the byte-for-byte output of the real
  # graph-side projection (GgenIgniter.SemanticJira.admit_work_order/1 run in
  # ~/ggen_igniter); it is regenerated by the e2e test via SJ001_EVIDENCE_DIR.
  @real_descriptor Path.expand(
                     "../../../docs/sjira/v26.9.21/receipts/sj-001/evidence/descriptor.json",
                     __DIR__
                   )
  @external_resource @real_descriptor

  defp real_descriptor, do: @real_descriptor |> File.read!() |> Jason.decode!()

  # A forger's best move against a snapshot: edit one field and recompute the
  # snapshot's own digest so the snapshot is internally self-consistent.
  defp reseal(snapshot, key, value) do
    edited = Map.put(snapshot, key, value)

    Map.put(
      edited,
      "work_order_digest",
      Xaas.Ultracode.SemanticWork.AdmissionBinding.snapshot_digest(edited)
    )
  end

  # Flip one hex digit: still a well-formed digest, so only the digest BINDING
  # (not the format check) can catch it.
  defp flip("sha256:" <> <<first, rest::binary>>) do
    flipped = if first == ?0, do: ?1, else: ?0
    "sha256:" <> <<flipped, rest::binary>>
  end
end
