# The work-graph projection of a compiled successor checkpoint (lane V23-H,
# GC-26.9.23 gate GC23-12; PRD section 12, ARD sections 5.5 and 24 M9): reads
# the goal graph and the compiler's orders.ttl (`mix semantic_jira.compile_prose`)
# through the semantic-jira-pack's OWN canonical projection -- the cold
# bootstrap queries priv/ggen/semantic-jira-pack/bootstrap/work_orders.rq and
# dependencies.rq, grouped by `GgenIgniter.SemanticJira.Bootstrap.Graph.orders/3`
# -- and writes the kernel work-order rows `mix semantic_jira.frontier
# --work-orders` and `mix semantic_jira.descriptor --work-orders` read.
#
# Run from a ggen_igniter checkout (`Xaas.Sjira.Successor` does this as an OS
# process, the way the drive runs scripts/sa2a_route_task.exs):
#
#   MIX_ENV=test mix run --no-start /abs/scripts/successor_work_graph.exs \
#     <goal.ttl> <orders.ttl> <work-out.json>
#
# Each row is the pack kernel (identity, title, description, subject,
# repository, base_sha, evidence_ceiling, authority_requirement,
# promotion_rule, replay_identity, required_courts, required_evidence,
# required_receipt_classes, acceptance, falsifiers, projections, path_scope,
# dependencies) plus the contract tuple in the row vocabulary the SA2A route
# reads (`Xaas.Sa2a.Route.tuple(:order, row)`: postcondition,
# requires_capability, evidence_horizon, authority_ceiling,
# consequence_class, exclusions, successor_policy), the order's placement
# (checkpoint_of, boundary_class, iri) and the stop-court tuple digest
# (`Graph.tuple_digest/1`). `standing` is "UNKNOWN": the kernel never selects
# the sj:standing literal (PR-006); standing is projected by the frontier from
# the ledger. The only hand-written step is the join of kernel + tuple into one
# row (HANDWRITTEN.md, UNSUPPORTED(generator-capability)).
#
# Output: canonical JSON (keys sorted recursively, rows sorted by identity, no
# timestamp, no absolute path), so two runs over the same inputs are
# byte-identical. Exit 0 and one JSON line {"ok": true, "work_orders": N,
# "work_graph_sha256": ...}; exit 1 and {"ok": false, "reason": ...} when an
# input is unreadable or an order's tuple is incomplete or ambiguous.

alias GgenIgniter.SemanticJira.Bootstrap.Graph

refuse = fn reason, detail ->
  IO.puts(Jason.encode!(%{"ok" => false, "reason" => reason, "detail" => detail}))
  System.halt(1)
end

[goal_path, orders_path, out_path] =
  case System.argv() do
    [_goal, _orders, _out] = argv -> argv
    other -> refuse.("usage", %{"argv" => other})
  end

pack_dir = Path.join(File.cwd!(), "priv/ggen/semantic-jira-pack")

queries =
  case Graph.read_queries(pack_dir) do
    {:ok, queries} -> queries
    {:error, detail} -> refuse.("pack_queries_unreadable", detail)
  end

parse = fn path ->
  with {:ok, bytes} <- File.read(path),
       {:ok, graph} <- Graph.parse(bytes) do
    {bytes, graph}
  else
    {:error, detail} ->
      refuse.("input_unreadable", %{"path" => Path.basename(path), "error" => inspect(detail)})
  end
end

{goal_bytes, goal} = parse.(goal_path)
{orders_bytes, orders_graph} = parse.(orders_path)

root =
  case Graph.root(goal, queries) do
    {:ok, root} -> root
    {:error, detail} -> refuse.("goal_root", detail)
  end

merged = RDF.Graph.add(goal, orders_graph)

single = fn fields, key ->
  case Map.get(fields, key, []) do
    [value] -> value
    _none_or_many -> nil
  end
end

rows =
  merged
  |> Graph.orders(queries, "successor")
  |> Enum.map(fn order ->
    tuple =
      case order.tuple do
        {:ok, tuple, digest} -> Map.put(tuple, "tuple_digest", digest)
        {kind, field} -> refuse.("tuple_#{kind}", %{"order" => order.id, "field" => field})
      end

    order.kernel
    |> Map.merge(%{
      "standing" => "UNKNOWN",
      "iri" => order.iri,
      "postcondition" => tuple["postcondition"],
      "requires_capability" => tuple["capability"],
      "evidence_horizon" => single.(order.fields, "evidence_horizon"),
      "authority_ceiling" => tuple["authority_ceiling"],
      "consequence_class" => tuple["consequence_class"],
      "exclusions" => Enum.sort(tuple["exclusions"]),
      "successor_policy" => single.(order.fields, "successor_policy"),
      "checkpoint_of" => single.(order.fields, "checkpoint_of"),
      "boundary_class" => single.(order.fields, "boundary_class"),
      "tuple_digest" => tuple["tuple_digest"]
    })
  end)
  |> Enum.sort_by(& &1["identity"])

sha256 = fn bytes -> "sha256:" <> Base.encode16(:crypto.hash(:sha256, bytes), case: :lower) end

canonical = fn canonical, value ->
  cond do
    is_map(value) ->
      value
      |> Enum.map(fn {key, item} -> {to_string(key), canonical.(canonical, item)} end)
      |> Enum.sort_by(&elem(&1, 0))
      |> Jason.OrderedObject.new()

    is_list(value) ->
      Enum.map(value, &canonical.(canonical, &1))

    true ->
      value
  end
end

document = %{
  "schema" => "xaas/successor-work-graph/v1",
  "checkpoint" => root,
  "projection" =>
    "semantic-jira-pack bootstrap/work_orders.rq + dependencies.rq (Bootstrap.Graph.orders/3)",
  "inputs" => %{
    "goal_sha256" => sha256.(goal_bytes),
    "orders_sha256" => sha256.(orders_bytes),
    "work_orders_query_sha256" => sha256.(queries["work_orders"]),
    "dependencies_query_sha256" => sha256.(queries["dependencies"])
  },
  "work_orders" => rows
}

json = Jason.encode!(canonical.(canonical, document), pretty: true) <> "\n"
File.write!(out_path, json)

IO.puts(
  Jason.encode!(%{
    "ok" => true,
    "work_orders" => length(rows),
    "work_graph_sha256" => sha256.(json)
  })
)
