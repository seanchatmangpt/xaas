defmodule Xaas.Ultracode.SemanticWorkTest do
  # SemanticCase, not bare DataCase: these tests touch Xaas.Repo Ash
  # resources, so they need the scoped shared Xaas.Repo sandbox owner the
  # template establishes (DataCase only owns Xaas.LegacyRepo) -- the root
  # fix for the 5 DBConnection.OwnershipError reds at
  # SemanticWork.materialize/2.
  use Xaas.Ultracode.SemanticCase, async: false

  alias Xaas.Ultracode.SemanticWork

  test "admits a typed execution descriptor with exact upstream receipt evidence", %{sha: sha} do
    assert {:ok, admitted} = SemanticWork.admit(checkpoint(sha))
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
             SemanticWork.admit(input)
  end

  test "dependency without exact receipt digest is refused", %{sha: sha} do
    input =
      update_in(checkpoint(sha), [:dependencies, Access.at(0)], fn dependency ->
        %{dependency | receipt_digest: "main"}
      end)

    assert {:error, {:refused_dependency, {:invalid, :receipt_digest}}} =
             SemanticWork.admit(input)
  end

  test "duplicate dependency identity is refused", %{sha: sha} do
    [dependency] = checkpoint(sha).dependencies
    input = %{checkpoint(sha) | dependencies: [dependency, dependency]}

    assert {:error, {:refused_dependency, :duplicate_work_order_identity}} =
             SemanticWork.admit(input)
  end

  test "branch names cannot stand in for exact base identity", %{sha: sha} do
    assert {:error, {:refused_semantic_work, {:invalid, :base_sha}}} =
             SemanticWork.admit(%{checkpoint(sha) | base_sha: "main"})
  end

  test "runtime does not own a second semantic frontier selector" do
    refute function_exported?(SemanticWork, :frontier, 1)
  end

  test "continuous policy uses Run.start and leaves the exact-worktree Epoch expected", %{
    sha: sha
  } do
    assert {:ok, %{run: run, epoch: epoch, worktree: worktree}} =
             SemanticWork.materialize(checkpoint(sha))

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

    assert {:ok, %{run: run, epoch: epoch}} = SemanticWork.materialize(input)

    assert run.state == :running
    assert run.execution_policy == :autonomic_wave_attempt
    assert epoch.state == :running
    assert epoch.exact_subject =~ "urn:gall:work-order:xaas:wave@"
  end

  test "two work orders in the same canonical graph manufacture distinct worktrees", %{sha: sha} do
    a = checkpoint(sha, work_order_iri: "urn:gall:work-order:xaas:a")
    b = checkpoint(sha, work_order_iri: "urn:gall:work-order:xaas:b")

    assert {:ok, %{worktree: path_a}} = SemanticWork.materialize(a)
    assert {:ok, %{worktree: path_b}} = SemanticWork.materialize(b)

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
end
