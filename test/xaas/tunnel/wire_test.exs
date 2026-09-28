defmodule Xaas.Tunnel.WireTest do
  use ExUnit.Case, async: true

  alias Xaas.Tunnel.Wire

  test "admits exactly the bounded trio" do
    for {wire, projected} <- [
          {"fabric.probe", :probe},
          {"run.submit", :submit},
          {"epoch.receipts", :receipts}
        ] do
      assert {:ok, {^projected, %{"subject" => "s"}}} =
               Wire.admit(%{
                 "v" => 1,
                 "kind" => "http",
                 "operation" => wire,
                 "payload" => %{"subject" => "s"}
               })
    end
  end

  test "generic MCP and unknown operations refuse before dispatch" do
    parent = self()
    handler = fn op, payload -> send(parent, {:called, op, payload}) end

    assert {:refused, :operation} =
             Wire.dispatch(
               %{"v" => 1, "kind" => "http", "operation" => "mcp.call", "payload" => %{}},
               handler
             )

    refute_receive {:called, _, _}
  end

  test "actuation vocabulary is an explicit authority refusal" do
    for operation <- ["actuate", "do", "command.execute"] do
      assert {:refused, :authority_ceiling} =
               Wire.admit(%{
                 "v" => 1,
                 "kind" => "http",
                 "operation" => operation,
                 "payload" => %{}
               })
    end
  end

  test "wrong version, kind, and non-map payload fail closed" do
    assert {:refused, :wire_version} =
             Wire.admit(%{"v" => 2, "kind" => "http", "operation" => "fabric.probe"})

    assert {:refused, :wire_kind} =
             Wire.admit(%{"v" => 1, "kind" => "mcp", "operation" => "fabric.probe"})

    assert {:refused, :malformed} =
             Wire.admit(%{
               "v" => 1,
               "kind" => "http",
               "operation" => "run.submit",
               "payload" => "shell"
             })
  end

  test "response preserves the cloud worker http_response envelope" do
    assert %{
             "v" => 1,
             "kind" => "http_response",
             "status" => 202,
             "body" => %{"standing" => "PARTIAL_ALIVE"}
           } =
             Wire.response(202, %{"standing" => "PARTIAL_ALIVE"})
  end
end
