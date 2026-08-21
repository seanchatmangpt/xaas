defmodule Xaas.SparqlBridge do
  @moduledoc """
  Real Monitor substrate for a MAPE-K loop: projects real, live Postgres rows
  from three Ash resources into RDF triples, serialized as real Turtle text.

    * Xaas.Operations.AutofdePlannerCandidate (autofde_planner_candidates)
    * Xaas.Operations.AutofdePlannerCatalog   (autofde_planner_catalog_requests)
    * Xaas.Operations.AutofdePlannerMatch     (autofde_planner_match_requests)

  Vocabulary (real, defined here, not borrowed):
    prefix aacm: <https://xaas.dev/ontology/autofde-monitor#>

    aacm:PlannerCandidate      -- class: one row of autofde_planner_candidates
    aacm:PlannerCatalogRequest -- class: one row of autofde_planner_catalog_requests
    aacm:PlannerMatchRequest   -- class: one row of autofde_planner_match_requests

    aacm:query                 -- the real query column (raw domain-arguments JSON),
                                   shared by all three classes
    aacm:requestedAt           -- the real requested_at timestamp column, shared by
                                   all three classes
    aacm:trajectorySha256      -- the real trajectory_sha256 digest column, shared
                                   by all three classes (always nil/absent for
                                   PlannerCatalogRequest and PlannerMatchRequest,
                                   since fabric__catalog and fabric__match are not
                                   solve calls and never emit a trajectory digest --
                                   see each resource's own moduledoc)
    aacm:solver                -- solver name extracted from cnv_response's real
                                   request.solver field (e.g. "Astar").
                                   PlannerCandidate only.
    aacm:domain                -- domain name extracted from cnv_response's real
                                   request.domain field (e.g. "PDDLDomain").
                                   PlannerCandidate only.

  No digest, timestamp, or identifier here is invented -- every triple's object
  is copied verbatim from a real column value already persisted by the
  corresponding Ash resource's create action (request_candidate /
  request_catalog / request_match), none of which invent trajectory_sha256;
  see each resource's own moduledoc.
  """

  alias Xaas.Operations.AutofdePlannerCandidate
  alias Xaas.Operations.AutofdePlannerCatalog
  alias Xaas.Operations.AutofdePlannerMatch
  alias Xaas.Operations.AutofdePlannerCacheHotset
  alias Xaas.Operations.AutofdePlannerCacheStats

  @prefix "https://xaas.dev/ontology/autofde-monitor#"

  @doc """
  Query all three real tables (via Ash) and return real Turtle text -- one
  individual per row, across all three classes.
  """
  @spec to_turtle() :: String.t()
  def to_turtle do
    {:ok, candidates} = Ash.read(AutofdePlannerCandidate)
    {:ok, catalog_requests} = Ash.read(AutofdePlannerCatalog)
    {:ok, match_requests} = Ash.read(AutofdePlannerMatch)
    {:ok, cache_stats_requests} = Ash.read(AutofdePlannerCacheStats)
    {:ok, cache_hotset_requests} = Ash.read(AutofdePlannerCacheHotset)

    header = """
    @prefix aacm: <#{@prefix}> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

    """

    body =
      (Enum.map(candidates, &candidate_to_turtle/1) ++
         Enum.map(catalog_requests, &catalog_to_turtle/1) ++
         Enum.map(match_requests, &match_to_turtle/1) ++
         Enum.map(cache_stats_requests, &cache_stats_row_to_turtle/1) ++
         Enum.map(cache_hotset_requests, &cache_hotset_row_to_turtle/1))
      |> Enum.join("\n")

    header <> body
  end

  @doc """
  Query the real autofde_planner_candidates table (via Ash) and return real
  Turtle text -- one aacm:PlannerCandidate individual per row.
  """
  @spec to_turtle([AutofdePlannerCandidate.t()]) :: String.t()
  def to_turtle(rows) when is_list(rows) do
    header = """
    @prefix aacm: <#{@prefix}> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

    """

    body =
      rows
      |> Enum.map(&candidate_to_turtle/1)
      |> Enum.join("\n")

    header <> body
  end

  @doc """
  Query the real autofde_planner_catalog_requests table (via Ash) and return
  real Turtle text -- one aacm:PlannerCatalogRequest individual per row.
  """
  @spec catalog_to_turtle() :: String.t()
  def catalog_to_turtle do
    {:ok, rows} = Ash.read(AutofdePlannerCatalog)
    turtle_document(Enum.map(rows, &catalog_to_turtle/1))
  end

  @doc """
  Query the real autofde_planner_match_requests table (via Ash) and return
  real Turtle text -- one aacm:PlannerMatchRequest individual per row.
  """
  @spec match_to_turtle() :: String.t()
  def match_to_turtle do
    {:ok, rows} = Ash.read(AutofdePlannerMatch)
    turtle_document(Enum.map(rows, &match_to_turtle/1))
  end

  @doc """
  Query the real autofde_planner_cache_hotset_requests table (via Ash) and return
  real Turtle text -- one aacm:PlannerCacheHotsetRequest individual per row.
  """
  @spec cache_hotset_to_turtle() :: String.t()
  def cache_hotset_to_turtle do
    {:ok, rows} = Ash.read(AutofdePlannerCacheHotset)
    turtle_document(Enum.map(rows, &cache_hotset_row_to_turtle/1))
  end

  @doc """
  Query the real autofde_planner_cache_stats_requests table (via Ash) and return
  real Turtle text -- one aacm:PlannerCacheStatsRequest individual per row.
  """
  @spec cache_stats_to_turtle() :: String.t()
  def cache_stats_to_turtle do
    {:ok, rows} = Ash.read(AutofdePlannerCacheStats)
    turtle_document(Enum.map(rows, &cache_stats_row_to_turtle/1))
  end

  defp turtle_document(bodies) do
    header = """
    @prefix aacm: <#{@prefix}> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

    """

    header <> Enum.join(bodies, "\n")
  end

  defp candidate_to_turtle(%AutofdePlannerCandidate{} = row) do
    subject = "aacm:PlannerCandidate_#{row.id}"
    {solver, domain} = extract_solver_and_domain(row.cnv_response)

    render_individual(subject, [
      {"a", "aacm:PlannerCandidate"},
      {"aacm:query", turtle_string(row.query)},
      {"aacm:trajectorySha256", turtle_maybe_string(row.trajectory_sha256)},
      {"aacm:solver", turtle_maybe_string(solver)},
      {"aacm:domain", turtle_maybe_string(domain)},
      {"aacm:requestedAt", turtle_maybe_datetime(row.requested_at)}
    ])
  end

  defp catalog_to_turtle(%AutofdePlannerCatalog{} = row) do
    subject = "aacm:PlannerCatalogRequest_#{row.id}"

    render_individual(subject, [
      {"a", "aacm:PlannerCatalogRequest"},
      {"aacm:query", turtle_string(row.query)},
      {"aacm:trajectorySha256", turtle_maybe_string(row.trajectory_sha256)},
      {"aacm:requestedAt", turtle_maybe_datetime(row.requested_at)}
    ])
  end

  defp match_to_turtle(%AutofdePlannerMatch{} = row) do
    subject = "aacm:PlannerMatchRequest_#{row.id}"

    render_individual(subject, [
      {"a", "aacm:PlannerMatchRequest"},
      {"aacm:query", turtle_string(row.query)},
      {"aacm:trajectorySha256", turtle_maybe_string(row.trajectory_sha256)},
      {"aacm:requestedAt", turtle_maybe_datetime(row.requested_at)}
    ])
  end

  defp cache_hotset_row_to_turtle(%AutofdePlannerCacheHotset{} = row) do
    subject = "aacm:PlannerCacheHotsetRequest_#{row.id}"

    render_individual(subject, [
      {"a", "aacm:PlannerCacheHotsetRequest"},
      {"aacm:query", turtle_string(row.query)},
      {"aacm:trajectorySha256", turtle_maybe_string(row.trajectory_sha256)},
      {"aacm:requestedAt", turtle_maybe_datetime(row.requested_at)}
    ])
  end

  defp cache_stats_row_to_turtle(%AutofdePlannerCacheStats{} = row) do
    subject = "aacm:PlannerCacheStatsRequest_#{row.id}"

    render_individual(subject, [
      {"a", "aacm:PlannerCacheStatsRequest"},
      {"aacm:query", turtle_string(row.query)},
      {"aacm:trajectorySha256", turtle_maybe_string(row.trajectory_sha256)},
      {"aacm:requestedAt", turtle_maybe_datetime(row.requested_at)}
    ])
  end

  defp render_individual(subject, lines) do
    predicate_lines =
      lines
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Enum.map(fn {p, v} -> "  #{p} #{v}" end)
      |> Enum.join(" ;\n")

    "#{subject}\n#{predicate_lines} .\n"
  end

  defp extract_solver_and_domain(%{"stdout" => stdout}) when is_binary(stdout) do
    case last_json_object(stdout) do
      {:ok, %{"request" => %{"solver" => solver, "domain" => domain}}} ->
        {solver, domain}

      {:ok, %{"solver" => solver, "request" => %{"domain" => domain}}} ->
        {solver, domain}

      {:ok, %{"solver" => solver}} ->
        {solver, nil}

      _ ->
        {nil, nil}
    end
  end

  defp extract_solver_and_domain(_), do: {nil, nil}

  # Same real last-JSON-object extraction rule as
  # Xaas.Operations.AutofdePlannerCandidate.last_json_object/1 (log-noise lines
  # can contain a literal "{" via frozenset() reprs, so anchor on the LAST
  # standalone "{\n" line, matching json.dumps(indent=2)'s own real output shape).
  defp last_json_object(stdout) do
    case :binary.matches(stdout, "\n{\n") do
      [] ->
        if String.starts_with?(stdout, "{\n"), do: Jason.decode(stdout), else: :error

      matches ->
        {start, _len} = List.last(matches)
        Jason.decode(binary_part(stdout, start + 1, byte_size(stdout) - start - 1))
    end
  end

  defp turtle_string(nil), do: nil

  defp turtle_string(s) when is_binary(s) do
    escaped =
      s
      |> String.replace("\\", "\\\\")
      |> String.replace("\"", "\\\"")
      |> String.replace("\n", "\\n")

    "\"#{escaped}\""
  end

  defp turtle_maybe_string(nil), do: nil
  defp turtle_maybe_string(s), do: turtle_string(s)

  defp turtle_maybe_datetime(nil), do: nil

  defp turtle_maybe_datetime(%DateTime{} = dt) do
    "\"#{DateTime.to_iso8601(dt)}\"^^xsd:dateTime"
  end

  @doc """
  Write the real Turtle serialization (all three classes) to a file on disk.
  Returns the path.
  """
  @spec write_turtle(String.t()) :: {:ok, String.t()}
  def write_turtle(path \\ "priv/autofde_monitor.ttl") do
    turtle = to_turtle()
    File.write!(path, turtle)
    {:ok, path}
  end
end
