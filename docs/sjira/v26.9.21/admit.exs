{:ok, l} = File.read!(System.get_env("WO")) |> Jason.decode()
for w <- l do
  case GgenIgniter.SemanticJira.admit_work_order(w) do
    {:ok, a} -> IO.puts("ADMITTED #{w["identity"]} #{a["work_order_digest"]}")
    e -> IO.puts("REFUSED #{w["identity"]} #{inspect(e)}")
  end
end
