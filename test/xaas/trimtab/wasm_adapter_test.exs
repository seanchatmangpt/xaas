defmodule Xaas.Trimtab.WasmAdapterTest do
  use ExUnit.Case, async: true
  alias Xaas.Trimtab.WasmAdapter

  test "portable envelope preserves exact subject digest" do
    assert {:ok, env} = WasmAdapter.envelope("comp", "digest", %{x: 1})
    assert env.component_id == "comp"
    assert env.subject_digest == "digest"
    assert is_binary(env.digest)
  end

  test "non-binary component is refused" do
    assert WasmAdapter.envelope(42, "d", %{}) == {:error, :invalid_component}
  end
end
