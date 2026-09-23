# SJ-003 post-construction SA2A use: admit the construction claim, replay the
# construction manifest against its canonical sha256, then a wrong-hash control.
# Speaks admit/replay only; sa2a_execute (DO edge) is never called.
alias Xaas.Sa2a.Bridge
{:ok, _} = Bridge.start_link([])
[manifest_path, head] = System.argv()
manifest = File.read!(manifest_path) |> Jason.decode!()
digest = "sha256:ecbcd23865fa1ba78061350b53f718dfd8e65aef17510355df3a27d0afe469a6"
canon = fn f, v ->
  case v do
    m when is_map(m) -> "{" <> (m |> Enum.sort_by(&elem(&1, 0)) |> Enum.map(fn {k, x} -> Jason.encode!(k) <> ":" <> f.(f, x) end) |> Enum.join(",")) <> "}"
    l when is_list(l) -> "[" <> (l |> Enum.map(&f.(f, &1)) |> Enum.join(",")) <> "]"
    x -> Jason.encode!(x)
  end
end
hash = Base.encode16(:crypto.hash(:sha256, canon.(canon, manifest)), case: :lower)
IO.puts("== admit (construction claim) ==")
IO.puts(inspect(Bridge.admit("SJ-003", "workorder:SJ-003 digest:#{digest} constructed head:#{head}", query_id: "sjira-v26.9.21", source: "docs/sjira/v26.9.21", evidence: %{"digest" => digest, "head" => head}), pretty: true))
IO.puts("== replay (canonical hash) hash=#{hash} ==")
IO.puts(inspect(Bridge.replay(manifest, hash), pretty: true))
IO.puts("== replay (wrong hash control) ==")
IO.puts(inspect(Bridge.replay(manifest, String.duplicate("0", 64)), pretty: true))
