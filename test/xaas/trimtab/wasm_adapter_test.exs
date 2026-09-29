defmodule XaaS.Trimtab.WasmAdapterTest do
  use ExUnit.Case, async: true
  alias XaaS.Trimtab.WasmAdapter
  test "portable request preserves exact subject" do
    assert %{subject: "s"}=WasmAdapter.request("s",%{x: 1})
  end
end
