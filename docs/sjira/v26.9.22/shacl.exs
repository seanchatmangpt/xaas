# SHACL court over work-orders.ttl with the semantic-jira-pack shapes, via the
# executing validator GgenIgniter.SemanticJira.Shacl. Run from a ggen_igniter
# checkout with the module compiled:
#   cd <ggen_igniter> && TTL=<abs>/docs/sjira/v26.9.22/work-orders.ttl \
#     mix run <abs>/docs/sjira/v26.9.22/shacl.exs
# Prints CONFORMS or one grouped line per (shape, constraint, message) with the
# violation count and focus identifiers, then the focus-node total. Exit 1 on
# any violation. The court grants no authority.
alias GgenIgniter.SemanticJira.Shacl

report = Shacl.validate_file(System.fetch_env!("TTL"))
IO.puts("shapes_checked=#{length(report.shapes_checked)} focus_nodes=#{report.focus_node_count} violations=#{length(report.violations)}")

if report.conforms do
  IO.puts("CONFORMS")
else
  report.violations
  |> Enum.group_by(fn v -> Map.drop(v, [:focus_node, :focus, :value, :values]) end)
  |> Enum.sort_by(fn {k, _} -> inspect(k) end)
  |> Enum.each(fn {k, vs} ->
    foci =
      vs
      |> Enum.map(&to_string(Map.get(&1, :focus_node) || Map.get(&1, :focus) || "?"))
      |> Enum.map(&String.replace(&1, "https://ggen-igniter.dev/ontology/semantic-jira#", "sj:"))
      |> Enum.uniq()

    IO.puts("VIOLATION count=#{length(vs)} #{inspect(k)} focus=#{Enum.join(foci, ",")}")
  end)

  System.halt(1)
end
