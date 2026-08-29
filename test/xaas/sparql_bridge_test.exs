defmodule Xaas.SparqlBridgeTest do
  @moduledoc """
  Chicago-style qualification of `Xaas.SparqlBridge.write_turtle/1`'s real
  `GgenIgniter.Actuate.write_file!/3`-backed write-safety, same pattern as
  `Xaas.Semantics.OntopMappingTest`'s idempotency test: real Postgres via
  `Ecto.Adapters.SQL.Sandbox`, real tmp-dir file I/O, no mocking.
  """

  use ExUnit.Case, async: true

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)

    tmp_path =
      Path.join(System.tmp_dir!(), "xaas_sparql_bridge_test_#{System.unique_integer([:positive])}.ttl")

    on_exit(fn -> File.rm(tmp_path) end)

    {:ok, tmp_path: tmp_path}
  end

  test "write_turtle/1 writes a real file containing the real Turtle prefix", %{tmp_path: tmp_path} do
    assert {:ok, ^tmp_path} = Xaas.SparqlBridge.write_turtle(tmp_path)
    assert File.exists?(tmp_path)
    assert File.read!(tmp_path) =~ "@prefix aacm: <https://xaas.dev/ontology/autofde-monitor#>"
  end

  test "write_turtle/1 is a real idempotent no-op on an unchanged snapshot, via GgenIgniter.Actuate's hash guard", %{
    tmp_path: tmp_path
  } do
    assert {:ok, ^tmp_path} = Xaas.SparqlBridge.write_turtle(tmp_path)
    {:ok, stat_before} = File.stat(tmp_path, time: :posix)

    assert {:ok, ^tmp_path} = Xaas.SparqlBridge.write_turtle(tmp_path)
    {:ok, stat_after} = File.stat(tmp_path, time: :posix)

    assert stat_before.mtime == stat_after.mtime
    assert stat_before.size == stat_after.size
  end
end
