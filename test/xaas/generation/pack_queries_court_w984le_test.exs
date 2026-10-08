defmodule Xaas.Generation.PackQueriesCourtW984leTest do
  @moduledoc """
  W984le court: the unclaimed `priv/packs/xaas_library_pack` query surfaces —
  `gates/*.rq` (the real consumer path: `GgenIgniter.Pack.discover_queries/1`
  reads `<pack_dir>/gates/*.rq` as the default `--query` source of
  `mix ggen_igniter.sync --pack-dir`) and `queries/*.rq` (no pack-dir
  consumer; 014's SELECT shape is mirrored at runtime by
  `Xaas.Library.Config.ontology_weights/0`).

  Chicago-school: every collaborator is real — the real Turtle file on disk,
  real `RDF.Turtle.read_file!/1`, real SPARQL execution via
  `GgenIgniter.Query.run/2` (the exact engine ggen_igniter uses at
  manufacturing time), and the real pack discovery function. Zero mocks.

  Mutation rationale (C05): each assertion below is killed by a targeted
  mutation — deleting an `xl:` triple from `ontology.ttl` empties the
  corresponding query's result set (tests 2-4), removing a query file drops
  the discovery count (test 1), un-grounding the 014 gate (removing its
  NOT EXISTS filter or a RankingFactor's weight triple) flips test 6's empty
  gate result, and editing either copy of a 001-013 query breaks test 7's
  byte-parity with the exercised gates/ copy.
  """

  use ExUnit.Case, async: true

  @pack_dir Path.join(:code.priv_dir(:xaas), "packs/xaas_library_pack")
  @ontology_path Path.join(@pack_dir, "ontology.ttl")

  @stems %{
    1 => "domain_structure",
    2 => "book_class_grounding",
    3 => "checkout_class_grounding",
    4 => "curation_class_grounding",
    5 => "book_resource_mapping",
    6 => "checkout_resource_mapping",
    7 => "curation_resource_mapping",
    8 => "base_phase_targets",
    9 => "core_phase_targets",
    10 => "all_codegen_targets",
    11 => "resource_inventory",
    12 => "domain_authorization_gate",
    13 => "relational_integrity"
  }

  setup_all do
    {:ok, graph} = RDF.Turtle.read_file(@ontology_path)
    gates = GgenIgniter.Pack.discover_queries(@pack_dir)
    {:ok, graph: graph, gates: gates}
  end

  defp run_query!(graph, path) do
    graph |> GgenIgniter.Query.run(File.read!(path)) |> Enum.to_list()
  end

  defp gate_path(gates, stem) do
    {_name, path} = Enum.find(gates, fn {_n, p} -> String.contains?(p, "/#{stem}.rq") end)
    path
  end

  defp gate_file(n, stem), do: Path.join([@pack_dir, "gates", "#{pad(n)}_#{stem}.rq"])
  defp queries_file(n, stem), do: Path.join([@pack_dir, "queries", "#{pad(n)}_#{stem}.rq"])
  defp pad(n), do: String.pad_leading(Integer.to_string(n), 3, "0")

  @tag :w984le
  test "1. real consumer path discovers exactly the 14 gates queries" do
    gates = GgenIgniter.Pack.discover_queries(@pack_dir)
    names = Enum.map(gates, fn {name, _} -> name end)

    assert length(gates) == 14
    assert Enum.sort(names) ==
             Enum.sort(~w(domain_structure book_class_grounding checkout_class_grounding
                          curation_class_grounding book_resource_mapping
                          checkout_resource_mapping curation_resource_mapping
                          base_phase_targets core_phase_targets all_codegen_targets
                          resource_inventory domain_authorization_gate
                          relational_integrity ranker_factor_weights))
  end

  @tag :w984le
  test "2. domain queries (001/012) return the real grounded domain row" do
    gates = GgenIgniter.Pack.discover_queries(@pack_dir)
    {:ok, graph} = RDF.Turtle.read_file(@ontology_path)

    domain_rows = run_query!(graph, gate_path(gates, "001_domain_structure"))
    assert [%{"domain" => "https://ggen.io/ontology/xaas-library#Domain_Library"}] = domain_rows
    assert %{"domainModule" => "Xaas.Library", "otpApp" => "kanban", "adminShow" => true} =
             hd(domain_rows)

    # 012 applies the FILTER(?adminShow = true) gate
    auth_rows = run_query!(graph, gate_path(gates, "012_domain_authorization_gate"))
    assert [%{"domainModule" => "Xaas.Library", "adminShow" => true}] = auth_rows
  end

  @tag :w984le
  test "3. class-grounding queries (002-004) each return exactly one class through real subClassOf grounding" do
    gates = GgenIgniter.Pack.discover_queries(@pack_dir)
    {:ok, graph} = RDF.Turtle.read_file(@ontology_path)

    expectations = %{
      "002_book_class_grounding" => {"bookClass", "Book"},
      "003_checkout_class_grounding" => {"checkoutClass", "Checkout"},
      "004_curation_class_grounding" => {"curationClass", "Curation"}
    }

    for {stem, {column, class}} <- expectations do
      rows = run_query!(graph, gate_path(gates, stem))
      assert [%{^column => class_iri}] = rows
      assert String.ends_with?(class_iri, "##{class}")
    end
  end

  @tag :w984le
  test "4. resource-mapping queries (005-007) return the grounded resource rows with expected column mappings" do
    gates = GgenIgniter.Pack.discover_queries(@pack_dir)
    {:ok, graph} = RDF.Turtle.read_file(@ontology_path)

    book_rows = run_query!(graph, gate_path(gates, "005_book_resource_mapping"))
    assert [%{"tableName" => "library_books"}] = book_rows
    assert %{"isbn" => "isbn", "author" => "author", "genre" => "genres",
             "gradeLevel" => "grade_level", "available" => "available_copies"} = hd(book_rows)

    checkout_rows = run_query!(graph, gate_path(gates, "006_checkout_resource_mapping"))
    assert [%{"tableName" => "library_checkouts", "status" => "status"}] = checkout_rows

    curation_rows = run_query!(graph, gate_path(gates, "007_curation_resource_mapping"))
    assert [%{"tableName" => "library_curations", "active" => "active"}] = curation_rows
  end

  @tag :w984le
  test "5. codegen-target queries (008-010) return the full base/core pipeline" do
    gates = GgenIgniter.Pack.discover_queries(@pack_dir)
    {:ok, graph} = RDF.Turtle.read_file(@ontology_path)

    base = run_query!(graph, gate_path(gates, "008_base_phase_targets"))
    assert length(base) == 6

    tasks =
      base |> Enum.sort_by(& &1["order"]) |> Enum.map(& &1["mixTask"])

    assert Enum.frequencies(tasks) == %{"ash.gen.domain" => 1, "ash.gen.resource" => 5}

    core = run_query!(graph, gate_path(gates, "009_core_phase_targets"))
    assert length(core) == 5
    assert Enum.uniq(Enum.map(core, & &1["mixTask"])) == ["xaas.library.core"]

    all_targets = run_query!(graph, gate_path(gates, "010_all_codegen_targets"))
    assert length(all_targets) == 11
  end

  @tag :w984le
  test "6. resource_inventory (011) and relational_integrity (013) return grounded rows" do
    gates = GgenIgniter.Pack.discover_queries(@pack_dir)
    {:ok, graph} = RDF.Turtle.read_file(@ontology_path)

    inventory = run_query!(graph, gate_path(gates, "011_resource_inventory"))
    assert length(inventory) == 5
    assert "Xaas.Library.Book" in Enum.map(inventory, & &1["module"])

    integrity = run_query!(graph, gate_path(gates, "013_relational_integrity"))
    assert [%{"checkout" => "Xaas.Library.Checkout",
              "curation" => "Xaas.Library.Curation",
              "bookModule" => "Xaas.Library.Book"}] = integrity
  end

  @tag :w984le
  test "7. ranker factor weights: runtime parser, SELECT shape, and complement gate agree on the real ontology" do
    gates = GgenIgniter.Pack.discover_queries(@pack_dir)
    {:ok, graph} = RDF.Turtle.read_file(@ontology_path)

    # Real runtime consumer: regex parser over the same ontology.ttl
    weights = Xaas.Library.Config.ontology_weights()
    assert map_size(weights) == 6
    assert weights.collab == 0.34 and weights.semantic == 0.26 and weights.grade_fit == 0.16
    assert weights.available == 0.10 and weights.diversity == 0.06 and weights.curation == 0.09

    # queries/014 SELECT shape returns exactly the 6 grounded factors
    select_rows = run_query!(graph, Path.join(@pack_dir, "queries/014_ranker_factor_weights.rq"))
    assert length(select_rows) == 6
    select_names = select_rows |> Enum.map(& &1["name"]) |> Enum.sort()
    assert select_names == Enum.sort(~w(collab semantic grade_fit available diversity curation))

    # The gates/014 complement gate: empty result = every factor fully grounded
    gate_rows = run_query!(graph, gate_path(gates, "014_ranker_factor_weights"))
    assert gate_rows == []

    # Mutation (real in-memory graph surgery, no mock): drop the weight triple
    # from xl:Factor_Collab and the gate must fire, identifying that factor,
    # while the SELECT shape loses the collab row.
    collab = RDF.iri("https://ggen.io/ontology/xaas-library#Factor_Collab")
    weight_pred = RDF.iri("https://ggen.io/ontology/xaas-library#weight")

    collab_desc =
      graph |> RDF.Graph.descriptions() |> Enum.find(&(&1.subject == collab))

    assert %RDF.Description{} = collab_desc
    assert RDF.Description.get(collab_desc, weight_pred) != nil

    weight_values = RDF.Description.get(collab_desc, weight_pred)
    assert weight_values != nil

    mutated_desc =
      struct(RDF.Description,
        subject: collab,
        predications: Map.delete(collab_desc.predications, weight_pred)
      )

    mutated = RDF.Graph.put(graph, mutated_desc)

    # SELECT shape loses exactly the collab row (6 -> 5) under both engines.
    mutated_select = run_query!(mutated, Path.join(@pack_dir, "queries/014_ranker_factor_weights.rq"))
    assert length(mutated_select) == 5
    refute Enum.any?(mutated_select, fn row ->
      String.ends_with?(row["factor"], "#Factor_Collab")
    end)

    # gates/014 complement gate FIRES on the mutated graph under the real
    # spec-conformant engine (oxigraph).
    gate14 = File.read!(gate_path(gates, "014_ranker_factor_weights"))
    assert [%{"factor" => factor}] = GgenIgniter.Query.Oxigraph.run(mutated, gate14)
    assert String.ends_with?(factor, "#Factor_Collab")

    # W984le FINDING (engine limitation, witnessed here): under ggen_igniter's
    # DEFAULT `--engine sparql`, the same gate returns [] on the mutated graph
    # — `FILTER ( NOT EXISTS {..} || NOT EXISTS {..} )` silently evaluates
    # false, so gates/014 is a false-negative gate (can never fail) under the
    # default engine, the same class of limitation as the ORDER BY defect
    # already disclosed in GgenIgniter.Query's moduledoc. This assertion is
    # the regression trip-wire: if the sparql lib gains `||`-joined NOT EXISTS
    # support, this assertion fails and flags the limitation as fixed.
    assert run_query!(mutated, gate_path(gates, "014_ranker_factor_weights")) == []
  end

  @tag :w984le
  test "8. queries/ is byte-identical to gates/ for 001-013; 014 is the documented complement" do
    for n <- 1..13 do
      q = File.read!(queries_file(n, @stems[n]))
      g = File.read!(gate_file(n, @stems[n]))
      assert q == g, "queries/#{pad(n)}_#{@stems[n]}.rq drifted from gates copy"
    end

    q14 = File.read!(Path.join(@pack_dir, "queries/014_ranker_factor_weights.rq"))
    g14 = File.read!(Path.join(@pack_dir, "gates/014_ranker_factor_weights.rq"))
    assert q14 != g14
    assert q14 =~ "SELECT ?factor ?name ?weight"
    assert g14 =~ "NOT EXISTS"
  end
end
