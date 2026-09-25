defmodule Xaas.Tunnel.CapabilitiesOntologyTest do
  @moduledoc """
  Drift guard: `priv/tunnel/ontology.ttl` is the source of truth for the fabric
  capability set; the handwritten `Xaas.Tunnel.Capabilities` must equal it.
  """
  use ExUnit.Case, async: true

  alias Xaas.Tunnel.{Capabilities, Fabric}

  @ttl Path.expand("../../../priv/tunnel/ontology.ttl", __DIR__)
  @tf "http://seanchatmangpt.github.io/packs/tunnel-fabric#"

  defp graph, do: RDF.Turtle.read_file!(@ttl)
  defp p(local), do: RDF.iri(@tf <> local)

  defp capabilities(graph) do
    graph
    |> RDF.Graph.descriptions()
    |> Enum.filter(&(RDF.Description.first(&1, RDF.type()) == p("Capability")))
    |> Enum.map(fn d ->
      {to_string(RDF.Description.first(d, p("verb")) |> RDF.Term.value()),
       to_string(RDF.Description.first(d, p("standing")) |> RDF.Term.value()),
       RDF.Description.first(d, p("refusalReason"))}
    end)
  end

  test "admitted individuals equal Capabilities.allowlist/0" do
    admitted = for {verb, "ADMITTED", _} <- capabilities(graph()), do: verb
    assert Enum.sort(admitted) == Enum.sort(Capabilities.allowlist())
    assert length(admitted) == 3
  end

  test "refused individuals equal Capabilities.refused/0" do
    refused =
      for {verb, "REFUSED", reason} <- capabilities(graph()),
          into: %{},
          do: {verb, reason |> RDF.Term.value() |> String.to_existing_atom()}

    assert refused == Capabilities.refused()
  end

  test "protocol and long-poll bound match the fabric module" do
    [fabric] =
      graph()
      |> RDF.Graph.descriptions()
      |> Enum.filter(&(RDF.Description.first(&1, RDF.type()) == p("Fabric")))

    assert RDF.Description.first(fabric, p("protocol")) |> RDF.Term.value() == Fabric.protocol()

    assert RDF.Description.first(fabric, p("longPollMaxMs")) |> RDF.Term.value() ==
             Fabric.long_poll_max_ms()
  end

  test "anti-vacuity: an ontology with a fourth admitted verb is detected" do
    extra = """
    @prefix tf: <#{@tf}> .
    <urn:tf:capability/extra> a tf:Capability ; tf:verb "extra.verb" ; tf:standing "ADMITTED" .
    """

    mutated = RDF.Graph.add(graph(), RDF.Turtle.read_string!(extra))
    admitted = for {verb, "ADMITTED", _} <- capabilities(mutated), do: verb
    refute Enum.sort(admitted) == Enum.sort(Capabilities.allowlist())
  end
end
