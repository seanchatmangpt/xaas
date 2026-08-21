defmodule Xaas.SparqlBridge do
  @moduledoc """
  Real Monitor substrate for a MAPE-K loop: projects the real, live Postgres
  rows in Xaas.Operations.AutofdePlannerCandidate (autofde_planner_candidates
  table) into RDF triples, serialized as real Turtle text.

  Vocabulary (real, defined here, not borrowed):
    prefix aacm: <https://xaas.dev/ontology/autofde-monitor#>

    aacm:PlannerCandidate      -- class: one row of autofde_planner_candidates
    aacm:trajectorySha256      -- the real trajectory_sha256 digest column
    aacm:solver                -- solver name extracted from cnv_response's real
                                   request.solver field (e.g. "Astar")
    aacm:domain                -- domain name extracted from cnv_response's real
                                   request.domain field (e.g. "PDDLDomain")
    aacm:requestedAt           -- the real requested_at timestamp column
    aacm:query                 -- the real query column (raw domain-arguments JSON)

  No digest, timestamp, or identifier here is invented -- every triple's object
  is copied verbatim from a real column value already persisted by
  Xaas.Operations.AutofdePlannerCandidate.request_candidate (which itself never
  invents trajectory_sha256; see that module's own moduledoc).
  """

  alias Xaas.Operations.AutofdePlannerCandidate

  @prefix "https://xaas.dev/ontology/autofde-monitor#"

  @doc """
  Query the real autofde_planner_candidates table (via Ash) and return real
  Turtle text -- one aacm:PlannerCandidate individual per row.
  """
  @spec to_turtle() :: String.t()
  def to_turtle do
    {:ok, rows} = Ash.read(AutofdePlannerCandidate)
    to_turtle(rows)
  end

  @spec to_turtle([AutofdePlannerCandidate.t()]) :: String.t()
  def to_turtle(rows) when is_list(rows) do
    header = """
    @prefix aacm: <#{@prefix}> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

    """

    body =
      rows
      |> Enum.map(&row_to_turtle/1)
      |> Enum.join("\n")

    header <> body
  end

  defp row_to_turtle(%AutofdePlannerCandidate{} = row) do
    subject = "aacm:PlannerCandidate_#{row.id}"
    {solver, domain} = extract_solver_and_domain(row.cnv_response)

    lines =
      [
        {"a", "aacm:PlannerCandidate"},
        {"aacm:query", turtle_string(row.query)},
        {"aacm:trajectorySha256", turtle_maybe_string(row.trajectory_sha256)},
        {"aacm:solver", turtle_maybe_string(solver)},
        {"aacm:domain", turtle_maybe_string(domain)},
        {"aacm:requestedAt", turtle_maybe_datetime(row.requested_at)}
      ]
      |> Enum.reject(fn {_, v} -> is_nil(v) end)

    predicate_lines =
      lines
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
  Write the real Turtle serialization to a file on disk. Returns the path.
  """
  @spec write_turtle(String.t()) :: {:ok, String.t()}
  def write_turtle(path \\ "priv/autofde_monitor.ttl") do
    turtle = to_turtle()
    File.write!(path, turtle)
    {:ok, path}
  end
end
