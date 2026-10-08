# Admit the v26.9.22 multi-repo work orders through the GgenIgniter.SemanticJira kernel.
# Run from a ggen_igniter checkout that has the semantic_jira module compiled:
#   cd ~/ggen_igniter && WO=/Users/sac/xaas/docs/sjira/v26.9.22/wo.json \
#     mix run /Users/sac/xaas/docs/sjira/v26.9.22/admit.exs
# Prints one "ADMITTED <identity> <digest>" or "REFUSED <identity> <reason>" line
# per order. Admission manufactures an intent record; it grants no authority.
{:ok, l} = File.read!(System.get_env("WO")) |> Jason.decode()

for w <- l do
  case GgenIgniter.SemanticJira.admit_work_order(w) do
    {:ok, a} -> IO.puts("ADMITTED #{w["identity"]} #{a["work_order_digest"]}")
    e -> IO.puts("REFUSED #{w["identity"]} #{inspect(e)}")
  end
end
