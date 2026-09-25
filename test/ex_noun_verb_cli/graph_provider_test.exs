defmodule ExNounVerbCli.GraphProviderTest do
  use ExUnit.Case, async: true

  alias ExNounVerbCliTest.Support.InMemoryGraphProvider

  describe "load!/1" do
    test "returns the provider-defined graph handle for the given source" do
      triples = [{"a", "knows", "b"}, {"b", "knows", "c"}]

      assert InMemoryGraphProvider.load!(triples) == triples
    end
  end

  describe "query/2" do
    setup do
      triples = [
        {"pkg:receipt-verify", "rdf:type", "cnv:Capability"},
        {"pkg:receipt-verify", "cnv:defaultVerb", "verify"},
        {"pkg:calc", "rdf:type", "cnv:Capability"},
        {"pkg:calc", "cnv:defaultVerb", "add"}
      ]

      %{graph: InMemoryGraphProvider.load!(triples)}
    end

    test "matches an exact subject and returns real binding maps", %{graph: graph} do
      bindings = InMemoryGraphProvider.query(graph, {"pkg:calc", :_, :_})

      assert bindings == [
               %{
                 "subject" => "pkg:calc",
                 "predicate" => "rdf:type",
                 "object" => "cnv:Capability"
               },
               %{"subject" => "pkg:calc", "predicate" => "cnv:defaultVerb", "object" => "add"}
             ]
    end

    test "matches on predicate wildcard across all subjects", %{graph: graph} do
      bindings = InMemoryGraphProvider.query(graph, {:_, "rdf:type", "cnv:Capability"})

      assert length(bindings) == 2
      assert Enum.all?(bindings, &(&1["object"] == "cnv:Capability"))
      assert Enum.map(bindings, & &1["subject"]) == ["pkg:receipt-verify", "pkg:calc"]
    end

    test "returns an empty list, never nil, when nothing matches", %{graph: graph} do
      bindings = InMemoryGraphProvider.query(graph, {"pkg:nonexistent", :_, :_})

      assert bindings == []
    end
  end

  test "the fixture module actually implements the GraphProvider behaviour" do
    assert ExNounVerbCli.GraphProvider in InMemoryGraphProvider.__info__(:attributes)[:behaviour]
  end
end
