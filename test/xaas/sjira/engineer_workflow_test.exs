defmodule Xaas.Sjira.EngineerWorkflowTest do
  use ExUnit.Case, async: true
  alias Xaas.Sjira.EngineerWorkflow
  alias Xaas.Sjira.EngineerWorkflow.Codec

  defp work(id, overrides \\ %{}) do
    Map.merge(
      %{
        id: id,
        subject: "case:" <> id,
        classification: "KNOWN",
        standing: "READY_FOR_ENGINEER_DISPOSITION",
        obligation: "prepare known path",
        owner: "platform",
        next_action: "diagnose",
        required_evidence: [],
        supporting_evidence: ["fixture"],
        authority: "SELECT_CONSTRUCT_ONLY",
        human_gate: "ENGINEER_DISPOSITION_REQUIRED"
      },
      overrides
    )
  end

  test "deterministic projection and idempotency" do
    a = work("WO-A")
    assert {:ok, pa} = EngineerWorkflow.project(a, provider: "jira", project: "CS2")

    assert {:ok, pb} =
             EngineerWorkflow.project(a |> Enum.reverse() |> Map.new(),
               provider: "jira",
               project: "CS2"
             )

    assert pa == pb
    assert pa["idempotency_key"] == "sjira:" <> pa["work_digest"]
  end

  test "authority and duplicate conflicts fail closed" do
    assert {:refused, :consequential_authority_not_deliverable, "DO"} =
             EngineerWorkflow.project(work("WO-A", %{authority: "DO"}))

    assert {:refused, :duplicate_identity_conflict, _} =
             EngineerWorkflow.project_many([
               work("WO-A"),
               work("WO-A", %{obligation: "different"})
             ])
  end

  test "dependency closure orders parent before child" do
    assert {:ok, items} =
             EngineerWorkflow.project_many([
               work("WO-C", %{dependencies: ["WO-B"]}),
               work("WO-A"),
               work("WO-B", %{dependencies: ["WO-A"]})
             ])

    assert {:ok, batch} = EngineerWorkflow.dependency_batch(items)
    assert Enum.map(batch, & &1["work_id"]) == ["WO-A", "WO-B", "WO-C"]
  end

  test "missing dependencies and cycles refuse" do
    assert {:ok, missing} =
             EngineerWorkflow.project_many([work("WO-B", %{dependencies: ["WO-X"]})])

    assert {:refused, :missing_dependencies, [{"WO-B", "WO-X"}]} =
             EngineerWorkflow.dependency_batch(missing)

    assert {:ok, cyclic} =
             EngineerWorkflow.project_many([
               work("WO-A", %{dependencies: ["WO-B"]}),
               work("WO-B", %{dependencies: ["WO-A"]})
             ])

    assert {:refused, :dependency_cycle_or_unsatisfied_closure, _} =
             EngineerWorkflow.dependency_batch(cyclic)
  end

  test "pagination cursor rejects replaced boundary" do
    assert {:ok, items} = EngineerWorkflow.project_many(for n <- 1..5, do: work("WO-#{n}"))

    assert {:ok, %{items: first, next_cursor: cursor}} =
             EngineerWorkflow.page(items, page_size: 2)

    boundary = List.last(first)
    changed = %{boundary | "work_digest" => "sha256:" <> String.duplicate("0", 64)}
    replaced = [changed | Enum.reject(items, &(&1["work_id"] == boundary["work_id"]))]
    assert {:refused, :stale_cursor, _} = EngineerWorkflow.page(replaced, cursor: cursor)
  end

  test "upsert remains intent only and codec is canonical" do
    assert {:ok, e} = EngineerWorkflow.project(work("WO-A"), provider: "jira", project: "CS2")

    assert %{"authority" => "INTENT_ONLY", "external_key" => "WO-A"} =
             EngineerWorkflow.upsert_command(e)

    assert Codec.encode(%{b: 2, a: %{d: 4, c: 3}}) == ~s({"a":{"c":3,"d":4},"b":2})
  end
end
