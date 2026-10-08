defmodule Xaas.SparqlBridgeCourtTest do
  @moduledoc """
  W984cv depth court for `Xaas.SparqlBridge` (MAPE-K Monitor substrate).

  Chicago-style: real Postgres rows (inserted directly, bypassing the HTTP-calling
  `request_*` create actions), real Turtle output, parsed back with the real
  RDF.ex Turtle parser that ships in this repo's dependency closure
  (`{:rdf, "~> 3.0"}`). No mocks.

  Invariants under test:

    1. Projection of real rows across all five projected classes produces
       well-formed Turtle with the exact class/property vocabulary declared in
       the moduledoc.
    2. Determinism: two projections over the same Postgres state are
       byte-identical (Monitor substrate must not invent jitter).
    3. Empty tables: the document is still valid Turtle with only the two
       prefix declarations and zero triples (the Monitor must be able to report
       an empty K graph, not crash).
    4. Malformed `cnv_response` payloads (log-noise stdout without a parseable
       JSON tail, and a nil response) are handled with typed degradation: the
       solver/domain triples are omitted, the rest of the individual survives,
       and the document still round-trips through a real parser.
    5. Round-trip through `write_turtle/1` to a real file, then parse that file
       and confirm one typed subject per persisted row (this is the exact seam
       consumed by the MAPE-K Monitor loop, `mix xaas.close_coverage_gap`).
  """

  use ExUnit.Case, async: false

  alias Xaas.Operations.{
    AutofdePlannerCandidate,
    AutofdePlannerCatalog,
    AutofdePlannerMatch,
    AutofdePlannerCacheHotset,
    AutofdePlannerCacheStats
  }

  alias Xaas.{Repo, SparqlBridge}

  @aacm "https://xaas.dev/ontology/autofde-monitor#"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  defp insert_row!(schema, attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    struct!(
      schema,
      Map.merge(
        %{
          id: Ecto.UUID.generate(),
          query: "(define (domain d))",
          inserted_at: now,
          updated_at: now
        },
        attrs
      )
    )
    |> Repo.insert!()
  end

  test "projection of real Postgres rows across all classes is well-formed Turtle" do
    ts = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    insert_row!(AutofdePlannerCandidate, %{
      trajectory_sha256: "c0ffee",
      requested_at: ts,
      cnv_response: %{
        "stdout" =>
          "log noise with a { literal\n{\n\"request\": {\"solver\": \"Astar\", \"domain\": \"PDDLDomain\"}}"
      }
    })

    insert_row!(AutofdePlannerCatalog, %{requested_at: ts})
    insert_row!(AutofdePlannerMatch, %{trajectory_sha256: "abc123", requested_at: ts})
    insert_row!(AutofdePlannerCacheHotset, %{requested_at: ts})
    insert_row!(AutofdePlannerCacheStats, %{requested_at: ts})

    turtle = SparqlBridge.to_turtle()
    {:ok, graph} = RDF.Turtle.read_string(turtle)

    # one typed subject per class
    assert 1 == count_typed(graph, RDF.iri(@aacm <> "PlannerCandidate"))
    assert 1 == count_typed(graph, RDF.iri(@aacm <> "PlannerCatalogRequest"))
    assert 1 == count_typed(graph, RDF.iri(@aacm <> "PlannerMatchRequest"))
    assert 1 == count_typed(graph, RDF.iri(@aacm <> "PlannerCacheHotsetRequest"))
    assert 1 == count_typed(graph, RDF.iri(@aacm <> "PlannerCacheStatsRequest"))

    # the candidate carries its copied-verbatim columns
    cand_subject = RDF.iri(@aacm <> "PlannerCandidate_" <> first_id(AutofdePlannerCandidate))

    assert {cand_subject, RDF.type(), RDF.iri(@aacm <> "PlannerCandidate")} in
             RDF.Graph.triples(graph)

    assert "c0ffee" == obj(graph, cand_subject, "trajectorySha256")

    assert "Astar" == obj(graph, cand_subject, "solver")

    assert "PDDLDomain" == obj(graph, cand_subject, "domain")
  end

  test "determinism: two projections over the same state are byte-identical" do
    ts = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    insert_row!(AutofdePlannerCandidate, %{requested_at: ts})
    insert_row!(AutofdePlannerMatch, %{requested_at: ts})

    # ×2 fresh roots: independent Ash reads, no shared computed state.
    t1 = SparqlBridge.to_turtle()
    t2 = SparqlBridge.to_turtle()

    assert t1 == t2
    assert t1 != ""
  end

  test "empty tables produce a valid, prefix-only Turtle document with zero triples" do
    turtle = SparqlBridge.to_turtle()

    {:ok, graph} = RDF.Turtle.read_string(turtle)

    assert 0 == RDF.Graph.triple_count(graph)
    assert turtle =~ ~S(@prefix aacm: <https://xaas.dev/ontology/autofde-monitor#>)
    assert turtle =~ ~S(@prefix xsd: <http://www.w3.org/2001/XMLSchema#>)
  end

  test "malformed cnv_response degrades with typed omission, never a crash" do
    ts = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    # noisy stdout with no parseable trailing JSON object -> {nil, nil}
    insert_row!(AutofdePlannerCandidate, %{
      requested_at: ts,
      cnv_response: %{"stdout" => "garbage with { frozenset() repr but no JSON tail"}
    })

    # nil cnv_response entirely
    insert_row!(AutofdePlannerCandidate, %{requested_at: ts, cnv_response: nil})

    turtle = SparqlBridge.to_turtle()
    {:ok, graph} = RDF.Turtle.read_string(turtle)

    assert 2 == count_typed(graph, RDF.iri(@aacm <> "PlannerCandidate"))

    # neither malformed row emitted solver/domain/query-trajectory noise
    assert [] ==
             graph
             |> RDF.Graph.triples()
             |> Enum.filter(fn {_, p, _} ->
               p in [RDF.iri(@aacm <> "solver"), RDF.iri(@aacm <> "domain")]
             end)

    # but both rows still carry their real query column
    assert 2 ==
             graph
             |> RDF.Graph.triples()
             |> Enum.count(fn {_, p, _} -> p == RDF.iri(@aacm <> "query") end)
  end

  test "write_turtle round-trip: file parses to one typed subject per real row" do
    ts = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    insert_row!(AutofdePlannerCatalog, %{requested_at: ts})
    insert_row!(AutofdePlannerMatch, %{requested_at: ts})
    insert_row!(AutofdePlannerCacheStats, %{requested_at: ts})

    path = Path.join(System.tmp_dir!(), "w984cv_#{System.unique_integer([:positive])}.ttl")

    on_exit(fn -> File.rm(path) end)

    assert {:ok, ^path} = SparqlBridge.write_turtle(path)

    {:ok, graph} = path |> File.read!() |> RDF.Turtle.read_string()

    assert 1 == count_typed(graph, RDF.iri(@aacm <> "PlannerCatalogRequest"))
    assert 1 == count_typed(graph, RDF.iri(@aacm <> "PlannerMatchRequest"))
    assert 1 == count_typed(graph, RDF.iri(@aacm <> "PlannerCacheStatsRequest"))
    assert 0 == count_typed(graph, RDF.iri(@aacm <> "PlannerCandidate"))

    ids = all_ids(AutofdePlannerCatalog)

    subject_iris =
      graph
      |> RDF.Graph.triples()
      |> Enum.map(fn {s, _, _} -> s end)
      |> Enum.uniq()

    for id <- ids do
      assert RDF.iri(@aacm <> "PlannerCatalogRequest_" <> id) in subject_iris
    end
  end

  defp obj(graph, subject, local) do
    graph
    |> RDF.Graph.triples()
    |> Enum.find_value(fn
      {^subject, %RDF.IRI{} = p, o} ->
        if to_string(p) == @aacm <> local, do: to_string(o)

      _ ->
        nil
    end)
  end

  defp count_typed(graph, class_iri) do
    graph
    |> RDF.Graph.triples()
    |> Enum.count(fn {s, p, o} -> p == RDF.type() and o == class_iri end)
  end

  defp first_id(schema), do: schema |> Ash.read!(authorize?: false) |> hd() |> Map.get(:id)

  defp all_ids(schema), do: schema |> Ash.read!(authorize?: false) |> Enum.map(& &1.id)
end
