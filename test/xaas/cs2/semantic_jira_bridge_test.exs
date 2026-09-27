defmodule Xaas.CS2.SemanticJiraBridgeTest do
  use ExUnit.Case, async: true

  alias Xaas.CS2.{EngineerWorkflow, SemanticJiraBridge}

  @sha String.duplicate("a", 40)
  @source_digest String.duplicate("b", 64)
  @semantic_digest "sha256:" <> String.duplicate("c", 64)
  @definition_digest "sha256:" <> String.duplicate("d", 64)
  @batch_digest "sha256:" <> String.duplicate("e", 64)

  defp candidate(overrides \\ %{}) do
    Map.merge(
      %{
        "batch_id" => "cs2:fixture:1",
        "batch_digest" => @batch_digest,
        "layer" => 0,
        "identity" => "CS2-WRK-001",
        "work_order_digest" => @semantic_digest,
        "definition_digest" => @definition_digest,
        "subject" => "https://chatman.ai/cs2#RFC-CS2-001",
        "repository" => "seanchatmangpt/ggen-marketplace",
        "base_sha" => @sha,
        "source_digest" => @source_digest,
        "next_edge" => "CS2-WRK-002",
        "path_scope" => ["packs/cs2-semantic-work"],
        "authority" => "NONE"
      },
      overrides
    )
  end

  test "constructs an authority-free execution package without issuing a lease" do
    assert {:ok, package} = SemanticJiraBridge.execution_package(candidate(), "zcode")
    assert package["authority"] == "NONE"
    assert package["provider"] == "zcode"
    assert package["lease_request"]["authority"] == "NONE"
    assert package["lease_request"]["issued"] == false
    assert package["lease_request"]["work_order_id"] == "CS2-WRK-001"
  end

  test "refuses a different semantic subject" do
    other = "https://chatman.ai/cs2#OTHER"

    assert {:error, {:refused_cs2_candidate, {:subject_mismatch, ^other}}} =
             SemanticJiraBridge.execution_package(candidate(%{"subject" => other}), "zcode")
  end

  test "refuses candidate authority instead of laundering it" do
    assert {:error, {:refused_cs2_candidate, :authority_must_be_none}} =
             SemanticJiraBridge.execution_package(candidate(%{"authority" => "EXECUTE"}), "zcode")
  end

  test "refuses a moved or malformed base identity" do
    assert {:error, {:refused_cs2_candidate, {:invalid_base_sha, "main"}}} =
             SemanticJiraBridge.execution_package(candidate(%{"base_sha" => "main"}), "zcode")
  end

  test "orders an execution batch by dependency layer then identity" do
    later = candidate(%{"identity" => "CS2-WRK-002", "layer" => 1})

    assert {:ok, [first, second]} =
             SemanticJiraBridge.execution_batch([later, candidate()], "zcode")

    assert first["work_order_id"] == "CS2-WRK-001"
    assert second["work_order_id"] == "CS2-WRK-002"
  end

  test "engineer workflow composes the semantic candidate without DO" do
    assert {:ok, workflow} = EngineerWorkflow.from_semantic_candidate(candidate(), "zcode")
    assert workflow["kind"] == "cs2.engineer_workflow"
    assert workflow["authority"] == "NONE"
    assert workflow["execution_package"]["lease_request"]["issued"] == false
  end
end
