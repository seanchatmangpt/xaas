defmodule Xaas.Workbench.GgenClientTest do
  use ExUnit.Case, async: true

  alias Xaas.Workbench.GgenClient

  test "admits bounded ggen argv and an ephemeral source bundle" do
    assert {:ok, admitted} =
             GgenClient.validate_payload(%{
               "args" => ["sync", "run", "--dry-run"],
               "files" => %{
                 "ggen.toml" => "[project]\nname = \"consumer\"\n",
                 "ontology.ttl" => "@prefix ex: <https://example.test/> .\n"
               },
               "timeout_ms" => 30_000
             })

    assert admitted["args"] == ["sync", "run", "--dry-run"]
    assert admitted["timeout_ms"] == 30_000
    assert Map.has_key?(admitted["files"], "ggen.toml")
    assert Map.has_key?(admitted["files"], "ontology.ttl")
  end

  test "defaults to an exact ggen version execution when no command is supplied" do
    assert {:ok, admitted} = GgenClient.validate_payload(%{})
    assert admitted["args"] == ["--version"]
    assert admitted["files"] == %{}
    assert admitted["timeout_ms"] == 120_000
  end

  test "refuses path traversal before the worker receives the request" do
    assert {:error, {:refused, "UNSAFE_PATH", _}} =
             GgenClient.validate_payload(%{
               "args" => ["sync", "run"],
               "files" => %{"../outside.ttl" => "not admitted"}
             })
  end

  test "shell metacharacters remain literal ggen argv rather than ambient shell authority" do
    assert {:ok, admitted} =
             GgenClient.validate_payload(%{"args" => ["--help", ";", "rm -rf /"]})

    assert admitted["args"] == ["--help", ";", "rm -rf /"]
  end

  test "refuses oversized individual input files" do
    too_large = :binary.copy("x", 1024 * 1024 + 1)

    assert {:error, {:refused, "FILE_LIMIT", _}} =
             GgenClient.validate_payload(%{
               "args" => ["sync", "run"],
               "files" => %{"ontology.ttl" => too_large}
             })
  end

  test "accepts base64-encoded binary inputs and refuses malformed base64" do
    assert {:ok, _} =
             GgenClient.validate_payload(%{
               "files" => %{"fixture.bin" => %{content_base64: Base.encode64(<<0, 1, 2>>)}}
             })

    assert {:error, {:refused, "INVALID_BASE64", _}} =
             GgenClient.validate_payload(%{
               "files" => %{"fixture.bin" => %{"content_base64" => "%%%"}}
             })
  end
end
