# SA2A driver for the Semantic Jira loop. Usage (from ~/xaas, autofde on PATH):
#   PATH=$HOME/autofde-lab/.venv/bin:$PATH [SJ_IDS=SJ-007,SJ-010 SJ_PLAN_ID=<id>] mix run --no-start docs/sjira/v26.9.21/sa2a_loop.exs plan
#   ... admit SJ-001 <work_order_digest>
#   ... replay <manifest.json> [expected_sha256]   (omits expected -> computes canonical sha256)
# Speaks only validate/admit/plan/replay; sa2a_execute is a DO edge and is never called here.
alias Xaas.Sa2a.Bridge

canon = fn v -> Jason.encode!(v) end
{:ok, _} = Bridge.start_link([])
dir = Path.dirname(__ENV__.file)

case System.argv() do
  ["plan"] ->
    idx = File.read!(Path.join(dir, "index.json")) |> Jason.decode!() |> Enum.reject(&(&1["standing"] == "BLOCKED"))
    # Bridge caps the frontier at 8 lanes: SJ_IDS="SJ-007,SJ-010" narrows the candidate set.
    idx = case System.get_env("SJ_IDS") do
      nil -> idx
      ids -> keep = String.split(ids, ","); Enum.filter(idx, &(&1["id"] in keep))
    end
    weight = %{"UNSUPPORTED" => 0.9, "UNKNOWN" => 0.8, "PARTIAL_ALIVE" => 0.6, "BLOCKED" => 0.2}
    cands =
      for o <- idx do
        %{"item_id" => o["id"], "description" => o["path"],
          "option_entropy" => 1.0 + length(o["dependencies"]),
          "estimated_cost" => 5.0 + 3.0 * length(o["dependencies"]),
          "historical_yield" => Map.get(weight, o["standing"], 0.5)}
      end
    {:ok, resp} = Bridge.plan(cands, plan_id: System.get_env("SJ_PLAN_ID", "sjira-v26.9.21"), ticks: 5000, tokens: 500_000, experiments: 20)
    IO.puts(Jason.encode!(resp, pretty: true))

  ["admit", id, digest] ->
    {:ok, resp} = Bridge.admit(id, "workorder:#{id} digest:#{digest} requires-construction",
      query_id: "sjira-v26.9.21", source: "docs/sjira/v26.9.21", evidence: %{"digest" => digest})
    IO.puts(Jason.encode!(resp, pretty: true))

  ["replay", file | rest] ->
    manifest = File.read!(file) |> Jason.decode!()
    expected = case rest do [h] -> h; _ -> nil end
    # canonical form matches the port's sort_keys/compact sha256
    sorted = fn f, v -> case v do
      m when is_map(m) -> "{" <> (m |> Enum.sort_by(&elem(&1, 0)) |> Enum.map(fn {k, x} -> Jason.encode!(k) <> ":" <> f.(f, x) end) |> Enum.join(",")) <> "}"
      l when is_list(l) -> "[" <> (l |> Enum.map(&f.(f, &1)) |> Enum.join(",")) <> "]"
      x -> canon.(x) end end
    hash = expected || Base.encode16(:crypto.hash(:sha256, sorted.(sorted, manifest)), case: :lower)
    IO.puts(Jason.encode!(%{expected_hash: hash, result: Bridge.replay(manifest, hash) |> elem(1)}, pretty: true))
    bad = Bridge.replay(manifest, String.duplicate("0", 64))
    IO.puts("wrong-hash: " <> inspect(bad))
end
