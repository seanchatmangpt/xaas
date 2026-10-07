# SA2A driver for the Semantic Jira loop, v26.9.22. Copy of docs/sjira/v26.9.21/sa2a_loop.exs
# whose `plan` takes historical_yield from the manufacturing process's own OCEL log
# (Xaas.Sjira.Yield, XAAS-26922-21 / composition C02) instead of a literal standing->weight table.
# Usage (from the xaas checkout, autofde on PATH):
#   PATH=$HOME/autofde-lab/.venv/bin:$PATH mix run --no-start docs/sjira/v26.9.22/sa2a_loop.exs \
#     plan [OCEL.json] [orders.json] [order-classes.json] [repo]
#     (defaults: /Users/sac/wt/v26922/{ocel/v26922.ocel.json,orders.json,order-classes.json}, xaas)
#   ... admit <order-id> <work_order_digest>
#   ... replay <manifest.json> [expected_sha256]   (omits expected -> computes canonical sha256)
# Speaks only validate/admit/plan/replay; sa2a_execute is a DO edge and is never called here.
alias Xaas.Sa2a.Bridge
alias Xaas.Sjira.Yield

canon = fn v -> Jason.encode!(v) end
{:ok, _} = Bridge.start_link([])
root = "/Users/sac/wt/v26922"
# the SA2A allocator admits at most this many candidate lanes (Chatman constant 8)
lanes = 8

case System.argv() do
  ["plan" | rest] ->
    [ocel, orders_path, classes_path, repo] =
      rest ++
        Enum.drop(
          [
            "#{root}/ocel/v26922.ocel.json",
            "#{root}/orders.json",
            "#{root}/order-classes.json",
            "xaas"
          ],
          length(rest)
        )

    classes = if File.exists?(classes_path), do: Yield.load_classes!(classes_path), else: %{}
    mined = Yield.mine_file!(ocel, classes: classes, classes_source: classes_path)

    ranked =
      mined
      |> Yield.candidates(Yield.orders_from_file!(orders_path, repo: repo), classes: classes)
      |> Yield.rank()
      |> Enum.take(lanes)

    wire =
      Enum.map(
        ranked,
        &Map.take(&1, ~w(item_id description option_entropy estimated_cost historical_yield))
      )

    {:ok, resp} =
      Bridge.plan(wire, plan_id: "sjira-v26.9.22", ticks: 5000, tokens: 500_000, experiments: 20)

    IO.puts(
      Jason.encode!(
        %{
          "yield_source" => mined["source"],
          "machinery_share" => mined["machinery_share"],
          "candidates" => ranked,
          "plan" => resp
        },
        pretty: true
      )
    )

  ["admit", id, digest] ->
    {:ok, resp} =
      Bridge.admit(id, "workorder:#{id} digest:#{digest} requires-construction",
        query_id: "sjira-v26.9.22",
        source: "docs/sjira/v26.9.22",
        evidence: %{"digest" => digest}
      )

    IO.puts(Jason.encode!(resp, pretty: true))

  ["replay", file | rest] ->
    manifest = File.read!(file) |> Jason.decode!()

    expected =
      case rest do
        [h] -> h
        _ -> nil
      end

    # canonical form matches the port's sort_keys/compact sha256
    sorted = fn f, v ->
      case v do
        m when is_map(m) ->
          "{" <>
            (m
             |> Enum.sort_by(&elem(&1, 0))
             |> Enum.map(fn {k, x} -> Jason.encode!(k) <> ":" <> f.(f, x) end)
             |> Enum.join(",")) <> "}"

        l when is_list(l) ->
          "[" <> (l |> Enum.map(&f.(f, &1)) |> Enum.join(",")) <> "]"

        x ->
          canon.(x)
      end
    end

    hash =
      expected || Base.encode16(:crypto.hash(:sha256, sorted.(sorted, manifest)), case: :lower)

    IO.puts(
      Jason.encode!(%{expected_hash: hash, result: Bridge.replay(manifest, hash) |> elem(1)},
        pretty: true
      )
    )

    bad = Bridge.replay(manifest, String.duplicate("0", 64))
    IO.puts("wrong-hash: " <> inspect(bad))
end
