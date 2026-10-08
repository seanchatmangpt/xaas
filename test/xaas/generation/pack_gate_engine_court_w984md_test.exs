defmodule Xaas.Generation.PackGateEngineCourtW984mdTest do
  @moduledoc """
  W984md court: the owner decision on W984le's false-negative-gate finding for
  `priv/packs/xaas_library_pack/gates/014_ranker_factor_weights.rq`.

  Evidence (real reads of the real engine wiring, no mocks):
  - `GgenIgniter.Query.run/2` uses the `sparql` hex engine, whose
    `||`-joined `NOT EXISTS` silently evaluates false (W984le finding) — a
    false-negative gate shape.
  - The actual regen path (`mix ggen_igniter.sync`) resolves its engine as
    `opts[:engine] || "oxigraph"` since v26.8.27
    (`deps/ggen_igniter/lib/mix/tasks/ggen_igniter.sync.ex:1300,1456,1493`),
    and under oxigraph the gate FIRES on a mutated graph (witnessed in
    `pack_queries_court_w984le_test.exs` test 7).

  Chosen fix = Option A: pin `--engine oxigraph` explicitly in every
  library-pack regen invocation recorded in `Xaas.Generated.RegenCheck`, so
  the gate's validity no longer rests on the default string.
  """

  use ExUnit.Case, async: true

  @pack_dir Path.join(:code.priv_dir(:xaas), "packs/xaas_library_pack")

  @tag :w984md
  test "1. engine wiring: the sync task's default engine is oxigraph, not sparql" do
    src = File.read!(Path.join([:code.priv_dir(:xaas), "..", "deps", "ggen_igniter",
                               "lib", "mix", "tasks", "ggen_igniter.sync.ex"]))
    refute src =~ ~s(opts[:engine] || "sparql")
    assert src =~ ~s(opts[:engine] || "oxigraph")
  end

  @tag :w984md
  test "2. every library-pack regen_command in RegenCheck pins --engine oxigraph" do
    src = File.read!(Path.join([:code.priv_dir(:xaas), "..", "lib", "xaas", "generated",
                               "regen_check.ex"]))

    cmds =
      Regex.scan(~r/"mix ggen_igniter\.sync --pack-dir priv\/packs\/xaas_library_pack[^"]*"/, src)
      |> Enum.map(&hd(&1))

    assert length(cmds) >= 2, "expected >=2 library-pack regen_command strings, got: #{inspect(cmds)}"

    for cmd <- cmds do
      assert cmd =~ "--engine oxigraph",
               "library-pack regen invocation missing the oxigraph pin: #{cmd}"
    end
  end

  @tag :w984md
  test "3. mutation falsifier: gates/014 FIRES on the mutated graph under the pinned engine" do
    {:ok, graph} = RDF.Turtle.read_file(Path.join(@pack_dir, "ontology.ttl"))
    gate14 = File.read!(Path.join(@pack_dir, "gates/014_ranker_factor_weights.rq"))

    # Real in-memory surgery: delete xl:Factor_Collab's weight triple.
    collab = RDF.iri("https://ggen.io/ontology/xaas-library#Factor_Collab")
    weight_pred = RDF.iri("https://ggen.io/ontology/xaas-library#weight")

    desc =
      graph |> RDF.Graph.descriptions() |> Enum.find(&(&1.subject == collab))

    mutated =
      RDF.Graph.put(
        graph,
        struct(RDF.Description, subject: collab, predications: Map.delete(desc.predications, weight_pred))
      )

    assert [%{"factor" => factor}] = GgenIgniter.Query.Oxigraph.run(mutated, gate14)
    assert String.ends_with?(factor, "#Factor_Collab")
    # And the gate stays quiet on the unmutated ontology.
    assert GgenIgniter.Query.Oxigraph.run(graph, gate14) == []
  end
end
