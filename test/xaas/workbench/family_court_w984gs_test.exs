defmodule Xaas.Workbench.FamilyCourtW984gsTest do
  @moduledoc """
  W984gs unclaimed-family court on `Xaas.Workbench.GgenClient`.

  W984eq covered the GgenWorkbench controller via workbench_deepening_test.exs;
  this court goes past it at module level. Every refusal branch below has zero
  prior grep hits in test/ (checked by literal code string), so each test is a
  mutation falsifier: reverting or miswriting the branch makes the assertion
  fail. Pure validation — no mocks, real env-var state for config refusals.
  """

  use ExUnit.Case, async: false

  alias Xaas.Workbench.GgenClient

  setup do
    url = System.get_env("GGEN_WORKBENCH_URL")
    token = System.get_env("GGEN_WORKBENCH_TOKEN")
    System.delete_env("GGEN_WORKBENCH_URL")
    System.delete_env("GGEN_WORKBENCH_TOKEN")

    on_exit(fn ->
      if url, do: System.put_env("GGEN_WORKBENCH_URL", url)
      if token, do: System.put_env("GGEN_WORKBENCH_TOKEN", token)
    end)

    :ok
  end

  test "non-map payload -> INVALID_REQUEST (mutation: dropping the non-map clause must fail)" do
    assert {:error, {:refused, "INVALID_REQUEST", _}} = GgenClient.validate_payload("nope")
    assert {:error, {:refused, "INVALID_REQUEST", _}} = GgenClient.validate_payload(nil)
  end

  test "empty args and non-list args -> INVALID_ARGS" do
    assert {:error, {:refused, "INVALID_ARGS", _}} = GgenClient.validate_payload(%{"args" => []})
    assert {:error, {:refused, "INVALID_ARGS", _}} = GgenClient.validate_payload(%{"args" => "x"})
  end

  test "over-64 argv -> ARGS_LIMIT" do
    args = List.duplicate("--flag", 65)
    assert {:error, {:refused, "ARGS_LIMIT", _}} = GgenClient.validate_payload(%{"args" => args})
  end

  test "non-binary / NUL-containing / over-512-byte args -> INVALID_ARG" do
    assert {:error, {:refused, "INVALID_ARG", _}} =
             GgenClient.validate_payload(%{"args" => [123]})

    assert {:error, {:refused, "INVALID_ARG", _}} =
             GgenClient.validate_payload(%{"args" => ["a" <> <<0>> <> "b"]})

    assert {:error, {:refused, "INVALID_ARG", _}} =
             GgenClient.validate_payload(%{"args" => [String.duplicate("x", 513)]})
  end

  test "non-map files -> INVALID_FILES" do
    assert {:error, {:refused, "INVALID_FILES", _}} =
             GgenClient.validate_payload(%{"files" => ["a"]})
  end

  test "over-256 files -> FILES_LIMIT" do
    files = Map.new(1..257, fn i -> {"f#{i}.ex", "x"} end)
    assert {:error, {:refused, "FILES_LIMIT", _}} = GgenClient.validate_payload(%{"files" => files})
  end

  test "absolute path and '.' path -> UNSAFE_PATH / INVALID_PATH" do
    assert {:error, {:refused, "UNSAFE_PATH", _}} =
             GgenClient.validate_payload(%{"files" => %{"/etc/passwd" => "x"}})

    assert {:error, {:refused, "INVALID_PATH", _}} =
             GgenClient.validate_payload(%{"files" => %{"." => "x"}})
  end

  test "empty-string and non-string file paths -> INVALID_PATH" do
    assert {:error, {:refused, "INVALID_PATH", _}} = GgenClient.validate_payload(%{"files" => %{"" => "x"}})
    assert {:error, {:refused, "INVALID_PATH", _}} = GgenClient.validate_payload(%{"files" => %{5 => "x"}})
  end

  test "non-string non-base64 file content -> INVALID_FILE_CONTENT" do
    assert {:error, {:refused, "INVALID_FILE_CONTENT", _}} =
             GgenClient.validate_payload(%{"files" => %{"a.ex" => 42}})
  end

  test "aggregate input over 5 MiB -> INPUT_LIMIT (sum across files, not per-file)" do
    # six files each just under the 1 MiB per-file cap, summing past 5 MiB
    files = Map.new(1..6, fn i -> {"f#{i}.ex", String.duplicate("x", 900_000)} end)
    assert {:error, {:refused, "INPUT_LIMIT", _}} = GgenClient.validate_payload(%{"files" => files})
  end

  test "non-integer, zero, and over-max timeout -> INVALID_TIMEOUT" do
    for bad <- ["5000", 0, -1, 300_001] do
      assert {:error, {:refused, "INVALID_TIMEOUT", _}} =
               GgenClient.validate_payload(%{"timeout_ms" => bad})
    end
  end

  test "unset GGEN_WORKBENCH_URL -> run/1 refuses WORKBENCH_NOT_CONFIGURED before any HTTP" do
    assert {:error, {:refused, "WORKBENCH_NOT_CONFIGURED", _}} =
             GgenClient.run(%{"args" => ["--version"]})
  end

  test "unset GGEN_WORKBENCH_TOKEN -> run/1 refuses WORKBENCH_TOKEN_MISSING after URL admits" do
    System.put_env("GGEN_WORKBENCH_URL", "http://127.0.0.1:9")
    assert {:error, {:refused, "WORKBENCH_TOKEN_MISSING", _}} =
             GgenClient.run(%{"args" => ["--version"]})
  end

  test "empty GGEN_WORKBENCH_TOKEN -> WORKBENCH_TOKEN_MISSING (empty-byte clause)" do
    System.put_env("GGEN_WORKBENCH_URL", "http://127.0.0.1:9")
    System.put_env("GGEN_WORKBENCH_TOKEN", "")
    assert {:error, {:refused, "WORKBENCH_TOKEN_MISSING", _}} =
             GgenClient.run(%{"args" => ["--version"]})
  end

  test "health/0 without config refuses WORKBENCH_NOT_CONFIGURED" do
    assert {:error, {:refused, "WORKBENCH_NOT_CONFIGURED", _}} = GgenClient.health()
  end

  test "atom file keys are stringified and content_base64 maps normalized (admit path)" do
    b64 = Base.encode64("hello")
    assert {:ok, normalized} =
             GgenClient.validate_payload(%{
               args: ["generate"],
               files: %{:"lib/gen.ex" => %{content_base64: b64}},
               timeout_ms: 1
             })

    assert normalized["args"] == ["generate"]
    assert normalized["files"] == %{"lib/gen.ex" => %{"content_base64" => b64}}
    assert normalized["timeout_ms"] == 1
  end
end
