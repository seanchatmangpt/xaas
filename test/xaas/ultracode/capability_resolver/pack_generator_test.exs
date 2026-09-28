defmodule Xaas.Ultracode.CapabilityResolver.PackGeneratorTest do
  @moduledoc """
  Chicago qualification of the generation executor against the REAL
  ggen-marketplace checkout and the REAL `ggen` binary: the marketplace's
  own `qualify_packs.qualify_pack/3` runs `ggen sync run` twice in a scratch
  consumer. Degrades to a named, visible skip on a machine without either
  (never a substituted double).
  """
  use ExUnit.Case, async: false

  alias Xaas.Ultracode.CapabilityResolver.{Execution, PackGenerator, Receipt}

  @available? match?({:ok, _}, PackGenerator.marketplace_root([])) and
                is_binary(System.find_executable("ggen"))

  @moduletag skip:
               if(@available?,
                 do: false,
                 else: "requires ~/ggen-marketplace checkout and ggen on PATH"
               )

  @moduletag timeout: 180_000

  test "a real admitted pack generates deterministically through the canonical harness" do
    assert {:generated, record} = PackGenerator.generate("ash-extension-pack")
    assert record["status"] in ["ALIVE", "WARN"]
    assert record["name"] == "ash-extension-pack"
  end

  test "a pack the marketplace does not contain is typed :unknown_pack" do
    assert {:error, {:unknown_pack, "no-such-pack-v26927"}} =
             PackGenerator.generate("no-such-pack-v26927")
  end

  test "a :generate verdict naming a real pack executes as {:generated, packs}; an unknown pack is refused" do
    receipt = fn pack ->
      %Receipt{
        item_id: "gen-#{pack}",
        class: :generate,
        required_capabilities: ["req-1"],
        selected_capabilities: [],
        candidate_capabilities: [
          %{capability_id: "ggen-pack:" <> pack, satisfies: ["req-1"], source: "local"}
        ],
        sources_queried: ["local"],
        falsifier: nil,
        resolved_at: DateTime.utc_now()
      }
    end

    ok = Execution.execute(receipt.("ash-extension-pack"))
    assert ok.outcome == {:generated, ["ash-extension-pack"]}
    assert ok.standing == "PARTIAL_ALIVE"

    assert %{"generation" => %{"ash-extension-pack" => %{"status" => status}}} = ok.replay
    assert status in ["ALIVE", "WARN"]
    assert Execution.outcome_json(ok.outcome) == "generated:ash-extension-pack"

    refused = Execution.execute(receipt.("no-such-pack-v26927"))
    assert refused.outcome == {:refused, "REFUSED:UNKNOWN_PACK"}
    assert refused.standing == "REFUSED"
  end
end
