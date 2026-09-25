defmodule Xaas.CaseStudies.WdFaCapabilitySelectorTest do
  use ExUnit.Case, async: true

  alias Xaas.CaseStudies.WdFa.CapabilitySelector

  test "case capability selection is deterministic and contains no DO" do
    capabilities = CapabilitySelector.for_case("novel_x")
    ids = Enum.map(capabilities, & &1.id)

    assert "reconstruct_subject" in ids
    assert "rank_hypotheses" in ids
    assert "test_applicability" in ids
    assert "construct_diagnostic_work" in ids
    assert "project_sjira" in ids
    refute Enum.any?(capabilities, &(&1.plane == "DO"))
  end

  test "KNOWN case selection does not require a general LLM capability" do
    capabilities = CapabilitySelector.for_case("known_firmware")

    refute Enum.any?(capabilities, &(&1.intelligence == "GENERAL_LLM_REQUIRED"))
  end
end
