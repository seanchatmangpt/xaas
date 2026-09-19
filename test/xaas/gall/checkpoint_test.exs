defmodule Xaas.Gall.CheckpointTest do
  use ExUnit.Case, async: true

  alias Xaas.Gall.Checkpoint

  @base_sha "6d5fca8cff223eb30ef19e237574d54f21cbfc15"

  @valid_fields [
    identity: "urn:gall:checkpoint:xaas:semantic-worker-001",
    class: "CodingCheckpoint",
    repository: "urn:repo:seanchatmangpt:xaas",
    base_sha: @base_sha,
    goal: "https://semantic-a2a.dev/gall#SemanticWorkerIntegration",
    requires_capabilities: [:Read, :Edit, :Commit],
    forbids_capabilities: [:Push, :Publish],
    verifier: "https://semantic-a2a.dev/gall#XaasChicagoCourt",
    standing: :UNKNOWN,
    allowed_paths: ["lib/xaas/**", "test/xaas/**"],
    acceptance: ["mix test test/xaas/gall"],
    falsifiers: ["admit a checkpoint with an unregistered capability"],
    required_evidence: ["focused mix test exit 0"],
    execution_policy: %{"max_parallel" => 4, "on_refusal" => "halt"}
  ]

  defp valid_fields(overrides) do
    @valid_fields |> Keyword.merge(overrides) |> Map.new()
  end

  describe "vocabularies" do
    test "capability vocabulary is exactly the PRD set" do
      assert Checkpoint.capability_vocab() == [
               :Read,
               :Edit,
               :Commit,
               :Write,
               :Push,
               :Publish,
               :Deploy,
               :Merge
             ]
    end

    test "standing vocabulary is exactly the repo standing set" do
      assert Checkpoint.standing_vocab() == [
               :UNKNOWN,
               :PARTIAL_ALIVE,
               :ALIVE,
               :BLOCKED,
               :BUILD_BROKEN,
               :UNSUPPORTED
             ]
    end

    test "refusal vocabulary exposes all seven typed refusals" do
      assert Enum.sort(Checkpoint.refusal_reasons()) ==
               Enum.sort([
                 :refused_authority,
                 :refused_capability,
                 :refused_dependency,
                 :refused_stale_lease,
                 :refused_subject_mismatch,
                 :refused_verifier_identity,
                 :refused_unregistered_actuation
               ])
    end
  end

  describe "new/1 (admission)" do
    test "admits the canonical PRD reference checkpoint" do
      assert {:ok, checkpoint} = Checkpoint.new(valid_fields([]))

      assert checkpoint.identity == "urn:gall:checkpoint:xaas:semantic-worker-001"
      assert checkpoint.class == "CodingCheckpoint"
      assert checkpoint.repository == "urn:repo:seanchatmangpt:xaas"
      assert checkpoint.base_sha == @base_sha
      assert checkpoint.requires_capabilities == [:Read, :Edit, :Commit]
      assert checkpoint.forbids_capabilities == [:Push, :Publish]
      assert checkpoint.standing == :UNKNOWN
      assert checkpoint.dependencies == []
      assert checkpoint.execution_policy == %{"max_parallel" => 4, "on_refusal" => "halt"}
    end

    test "accepts string keys, string capabilities, and uppercase base SHA (normalized)" do
      fields =
        valid_fields([])
        |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
        |> Map.put("requires_capabilities", ["Read", "Edit", "Commit"])
        |> Map.put("standing", "UNKNOWN")
        |> Map.put("base_sha", String.upcase(@base_sha))

      assert {:ok, checkpoint} = Checkpoint.new(fields)
      assert checkpoint.requires_capabilities == [:Read, :Edit, :Commit]
      assert checkpoint.standing == :UNKNOWN
      assert checkpoint.base_sha == @base_sha
    end

    test "refuses a missing required field with :refused_authority (never raises)" do
      fields = valid_fields([]) |> Map.delete(:standing)
      assert Checkpoint.new(fields) == {:refused, :refused_authority}
    end

    test "refuses non-map input with :refused_authority" do
      assert Checkpoint.new("not-a-checkpoint") == {:refused, :refused_authority}
      assert Checkpoint.new(nil) == {:refused, :refused_authority}
    end

    test "refuses a malformed identity URN with :refused_authority" do
      for bad_identity <- [
            "urn:gall:checkpoint:xaas",
            "gall:checkpoint:xaas:worker-1",
            "urn:checkpoint:xaas:worker-1",
            "just-a-string"
          ] do
        assert Checkpoint.new(valid_fields(identity: bad_identity)) ==
                 {:refused, :refused_authority}
      end
    end

    test "refuses a non-CodingCheckpoint class with :refused_unregistered_actuation" do
      assert Checkpoint.new(valid_fields(class: "GenericTask")) ==
               {:refused, :refused_unregistered_actuation}
    end

    test "refuses a repository whose shape is not urn:repo:<owner>:<name>" do
      assert Checkpoint.new(valid_fields(repository: "https://github.com/seanchatmangpt/xaas")) ==
               {:refused, :refused_subject_mismatch}

      assert Checkpoint.new(valid_fields(repository: "urn:repo:xaas")) ==
               {:refused, :refused_subject_mismatch}
    end

    test "refuses an identity whose repo segment mismatches the repository subject" do
      assert Checkpoint.new(
               valid_fields(identity: "urn:gall:checkpoint:other-repo:semantic-worker-001")
             ) ==
               {:refused, :refused_subject_mismatch}
    end

    test "refuses a non-40-hex base SHA with :refused_subject_mismatch" do
      for bad_sha <- ["not-a-sha", String.duplicate("a", 39), String.duplicate("a", 41)] do
        assert Checkpoint.new(valid_fields(base_sha: bad_sha)) ==
                 {:refused, :refused_subject_mismatch}
      end
    end

    test "refuses a dependency that is not a checkpoint IRI with :refused_dependency" do
      assert Checkpoint.new(valid_fields(dependencies: ["urn:repo:other:thing"])) ==
               {:refused, :refused_dependency}
    end

    test "refuses a self-dependency with :refused_dependency" do
      self_identity = "urn:gall:checkpoint:xaas:semantic-worker-001"

      assert Checkpoint.new(valid_fields(dependencies: [self_identity])) ==
               {:refused, :refused_dependency}
    end

    test "admits a well-formed dependency list" do
      assert {:ok, checkpoint} =
               Checkpoint.new(
                 valid_fields(dependencies: ["urn:gall:checkpoint:xaas:foundation-001"])
               )

      assert checkpoint.dependencies == ["urn:gall:checkpoint:xaas:foundation-001"]
    end

    test "refuses an out-of-vocabulary capability with :refused_capability" do
      assert Checkpoint.new(valid_fields(requires_capabilities: [:Read, :Fly])) ==
               {:refused, :refused_capability}

      assert Checkpoint.new(valid_fields(forbids_capabilities: ["Delete"])) ==
               {:refused, :refused_capability}
    end

    test "refuses a capability both required and forbidden with :refused_capability" do
      assert Checkpoint.new(
               valid_fields(
                 requires_capabilities: [:Read, :Edit],
                 forbids_capabilities: [:Edit, :Publish]
               )
             ) ==
               {:refused, :refused_capability}
    end

    test "refuses an unregistered verifier with :refused_verifier_identity" do
      assert Checkpoint.new(valid_fields(verifier: "gall:SomeUnregisteredCourt")) ==
               {:refused, :refused_verifier_identity}
    end

    test "refuses an out-of-vocabulary standing with :refused_authority" do
      assert Checkpoint.new(valid_fields(standing: "GOLDEN")) ==
               {:refused, :refused_authority}
    end

    test "refuses malformed list fields with :refused_authority" do
      assert Checkpoint.new(valid_fields(allowed_paths: "lib/**")) ==
               {:refused, :refused_authority}

      assert Checkpoint.new(valid_fields(execution_policy: "not-a-map")) ==
               {:refused, :refused_authority}
    end
  end

  describe "graph_digest/1 + canonical_serialization/1" do
    test "digest is 64 lowercase hex characters" do
      {:ok, checkpoint} = Checkpoint.new(valid_fields([]))
      assert Regex.match?(~r/^[0-9a-f]{64}$/, Checkpoint.graph_digest(checkpoint))
    end

    test "digest is order-insensitive: key order and set order do not matter" do
      {:ok, a} =
        Checkpoint.new(valid_fields(requires_capabilities: [:Read, :Edit, :Commit]))

      {:ok, b} =
        Checkpoint.new(valid_fields(requires_capabilities: [:Commit, :Read, :Edit]))

      assert Checkpoint.graph_digest(a) == Checkpoint.graph_digest(b)

      # string-keyed map with same content, different insertion order
      string_keyed =
        valid_fields([])
        |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)

      assert Checkpoint.graph_digest(Map.new(string_keyed)) ==
               Checkpoint.graph_digest(Map.from_struct(a))
    end

    test "digest changes when semantically meaningful content changes" do
      {:ok, a} = Checkpoint.new(valid_fields([]))
      {:ok, b} = Checkpoint.new(valid_fields(base_sha: String.duplicate("0", 40)))
      {:ok, c} = Checkpoint.new(valid_fields(standing: :ALIVE))

      digest_a = Checkpoint.graph_digest(a)
      assert digest_a != Checkpoint.graph_digest(b)
      assert digest_a != Checkpoint.graph_digest(c)
    end

    test "canonical serialization is a single sorted-key JSON object line" do
      {:ok, checkpoint} = Checkpoint.new(valid_fields([]))
      serialization = Checkpoint.canonical_serialization(checkpoint)

      assert serialization =~ ~r/^\{/
      assert serialization =~ ~r/\}$/
      refute serialization =~ "\n"

      # top-level keys are sorted: "acceptance" is alphabetically first
      assert String.starts_with?(serialization, "{\"acceptance\":")

      # round-trips as real JSON
      assert %{"acceptance" => ["mix test test/xaas/gall"]} = Jason.decode!(serialization)
    end

    test "whitespace inside string values is normalized for digest purposes" do
      {:ok, a} = Checkpoint.new(valid_fields(goal: "integration goal"))
      {:ok, b} = Checkpoint.new(valid_fields(goal: "  integration\tgoal  "))

      assert Checkpoint.graph_digest(a) == Checkpoint.graph_digest(b)
    end
  end
end
