defmodule Mix.Tasks.Xaas.CloseCoverageGap do
  @moduledoc """
  Real Monitor -> Analyze -> Plan -> Act -> Monitor closed loop over the real
  K graph produced by `Xaas.SparqlBridge.to_turtle/0`.

  1. Monitor: serialize the real, current K graph (5 real Ash resources'
     rows, via `Xaas.SparqlBridge.to_turtle/0`) to a real Turtle file.
  2. Analyze: shell out to real `python3` + `rdflib` (same round-trip shape
     used elsewhere in this session -- load the real Turtle, run a real
     SPARQL `SELECT ?class (COUNT(?s) AS ?n) WHERE { ?s a ?class }
     GROUP BY ?class` over the 5 known aacm: classes) to get a real
     per-class row count.
  3. Plan: pick the real class with the fewest rows -- the real
     least-exercised-capability signal this task derives from the graph's
     actual current state, not a hardcoded choice.
  4. Act: invoke that class's real, corresponding Ash create action once
     against the real, already-running cnv-deploy server
     (`Application.get_env(:xaas, :cnv_deploy_base_url, "http://127.0.0.1:8080")`),
     with a real, valid `query` argument for that action.
  5. Monitor again: re-run the same real SPARQL count query and print the
     real before/after count for the acted-on class.

  Usage:

      mix xaas.close_coverage_gap
  """
  use Mix.Task

  @shortdoc "Real MAPE-K loop: SPARQL-count the K graph, act on the least-exercised class, re-count"

  alias Xaas.Operations.AutofdePlannerCandidate
  alias Xaas.Operations.AutofdePlannerCatalog
  alias Xaas.Operations.AutofdePlannerMatch
  alias Xaas.Operations.AutofdePlannerCacheStats
  alias Xaas.Operations.AutofdePlannerCacheHotset

  @classes ~w(PlannerCandidate PlannerCatalogRequest PlannerMatchRequest PlannerCacheStatsRequest PlannerCacheHotsetRequest)

  # Real, proven-working fixture query values for each action's :query
  # attribute, matching this session's established fixtures (Maze for
  # domain-taking tools; AutofdePlannerCandidate's action itself hardcodes
  # domain=PDDLDomain/solver=Astar and treats :query as the raw
  # domain-arguments JSON string).
  @query_by_class %{
    "PlannerCandidate" =>
      Jason.encode!(%{"grid" => [[0, 0], [0, 0]], "start" => [0, 0], "goal" => [1, 1]}),
    "PlannerCatalogRequest" => "close_coverage_gap catalog probe",
    "PlannerMatchRequest" => "Maze",
    "PlannerCacheStatsRequest" => "close_coverage_gap cache-stats probe",
    "PlannerCacheHotsetRequest" => "close_coverage_gap cache-hotset probe"
  }

  @action_by_class %{
    "PlannerCandidate" => {AutofdePlannerCandidate, :request_candidate},
    "PlannerCatalogRequest" => {AutofdePlannerCatalog, :request_catalog},
    "PlannerMatchRequest" => {AutofdePlannerMatch, :request_match},
    "PlannerCacheStatsRequest" => {AutofdePlannerCacheStats, :request_cache_stats},
    "PlannerCacheHotsetRequest" => {AutofdePlannerCacheHotset, :request_cache_hotset}
  }

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    Mix.shell().info("== Monitor: real K graph (before) ==")
    before_counts = sparql_count_by_class()
    print_counts(before_counts)

    {target_class, target_n} = least_exercised(before_counts)

    Mix.shell().info(
      "\n== Analyze/Plan: least-exercised class is #{target_class} (#{target_n} rows) =="
    )

    {mod, action} = Map.fetch!(@action_by_class, target_class)
    query = Map.fetch!(@query_by_class, target_class)

    # PlannerCandidate's request_candidate action defaults to
    # domain="PDDLDomain"/solver="Astar", which needs real domain_path/
    # problem_path file arguments the generic query-based call never
    # supplies -- that combination is what produces the real SKD-FABRIC-006
    # error from cnv-deploy. Override with the real, already-proven-working
    # zero-arg fixture domain (Maze/Astar, no domain-arguments needed) for
    # this class only; the other 4 classes keep the unchanged query-only call.
    act_params =
      case target_class do
        "PlannerCandidate" -> %{query: "{}", domain: "Maze", solver: "Astar"}
        _ -> %{query: query}
      end

    Mix.shell().info(
      "== Act: invoking #{inspect(mod)}.#{action} with real params=#{inspect(act_params)} =="
    )

    case mod
         |> Ash.Changeset.for_create(action, act_params)
         |> Ash.create() do
      {:ok, record} ->
        Mix.shell().info("Act succeeded, real record id=#{record.id}")

      {:error, error} ->
        Mix.raise("Real Act step failed for #{target_class}: #{inspect(error)}")
    end

    Mix.shell().info("\n== Monitor: real K graph (after) ==")
    after_counts = sparql_count_by_class()
    print_counts(after_counts)

    before_n = Map.get(before_counts, target_class, 0)
    after_n = Map.get(after_counts, target_class, 0)

    Mix.shell().info(
      "\n== Closed-loop result: #{target_class} before=#{before_n} after=#{after_n} " <>
        "(delta=#{after_n - before_n}) =="
    )
  end

  defp least_exercised(counts) do
    Enum.min_by(@classes, fn class -> Map.get(counts, class, 0) end)
    |> then(fn class -> {class, Map.get(counts, class, 0)} end)
  end

  defp print_counts(counts) do
    Enum.each(@classes, fn class ->
      Mix.shell().info("  aacm:#{class} -> #{Map.get(counts, class, 0)}")
    end)
  end

  # Real SPARQL query against the real, current Turtle serialization,
  # executed via a real python3 + rdflib subprocess round-trip (rdflib
  # 7.6.0, confirmed installed on this machine).
  @spec sparql_count_by_class() :: %{String.t() => non_neg_integer()}
  defp sparql_count_by_class do
    turtle = Xaas.SparqlBridge.to_turtle()

    ttl_path =
      Path.join(
        System.tmp_dir!(),
        "xaas_close_coverage_gap_#{System.unique_integer([:positive])}.ttl"
      )

    File.write!(ttl_path, turtle)

    python_script = """
    import sys, json
    from rdflib import Graph

    g = Graph()
    g.parse(sys.argv[1], format="turtle")

    q = '''
    PREFIX aacm: <https://xaas.dev/ontology/autofde-monitor#>
    SELECT ?class (COUNT(?s) AS ?n) WHERE {
      ?s a ?class .
      FILTER(STRSTARTS(STR(?class), STR(aacm:)))
    } GROUP BY ?class
    '''

    out = {}
    for row in g.query(q):
        local_name = str(row["class"]).split("#")[-1]
        out[local_name] = int(row["n"])

    print(json.dumps(out))
    """

    script_path =
      Path.join(
        System.tmp_dir!(),
        "xaas_close_coverage_gap_#{System.unique_integer([:positive])}.py"
      )

    File.write!(script_path, python_script)

    {output, 0} = System.cmd("python3", [script_path, ttl_path], stderr_to_stdout: false)

    File.rm(ttl_path)
    File.rm(script_path)

    output
    |> Jason.decode!()
    |> Map.new(fn {k, v} -> {k, v} end)
  end
end
