defmodule Xaas.CaseStudies.WdFaStogafCapabilitiesTest do
  use ExUnit.Case, async: true

  alias Xaas.CaseStudies.WdFa.Stogaf.Capabilities

  test "Friday capability set contains no DO edge" do
    assert Capabilities.friday_do_count() == 0
    refute Enum.any?(Capabilities.friday(), &(&1.plane == "DO"))
  end

  test "production DO remains explicitly outside Friday scope" do
    do_capability = Capabilities.production_do()

    assert do_capability.plane == "DO"
    assert do_capability.authority == "OUTSIDE_FRIDAY_SCOPE"
  end

  test "KNOWN path does not require general LLM reasoning" do
    refute Capabilities.known_path_general_llm_required?()

    assert Enum.any?(Capabilities.friday(), fn capability ->
             capability.id == "test_applicability" and capability.intelligence == "NONE"
           end)
  end
end
