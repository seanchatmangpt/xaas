defmodule Xaas.OperationsAshAiToolsTest do
  @moduledoc """
  Real introspection coverage for the two read-only AshAi tools declared on
  `Xaas.Operations` (`lib/xaas/operations.ex`) -- proves they are actually
  registered on the domain, target the intended resource/action, and are
  read-only (no write tools declared).
  """
  use ExUnit.Case, async: true

  test "read_incidents and read_audit_log are registered on Xaas.Operations, targeting :read" do
    tools = AshAi.Info.tools(Xaas.Operations)

    assert %{resource: Xaas.Operations.Incident, action: :read} =
             Enum.find(tools, &(&1.name == :read_incidents))

    assert %{resource: Xaas.Operations.AuditLogEntry, action: :read} =
             Enum.find(tools, &(&1.name == :read_audit_log))
  end

  test "exactly two tools are declared on Xaas.Operations, and both are read-only" do
    tools = AshAi.Info.tools(Xaas.Operations)
    tool_names = Enum.map(tools, & &1.name) |> Enum.sort()

    assert tool_names == [:read_audit_log, :read_incidents]
    assert Enum.all?(tools, &(&1.action == :read))
  end

  test "each tool carries a real, non-empty description" do
    tools = AshAi.Info.tools(Xaas.Operations)

    for tool <- tools do
      assert is_binary(tool.description)
      assert String.length(tool.description) > 0
    end
  end
end
