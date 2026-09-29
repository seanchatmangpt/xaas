alias Xaas.Sjira.EngineerWorkflow
sizes = System.get_env("SJIRA_BENCH_SIZES", "100,1000,10000") |> String.split(",", trim: true) |> Enum.map(&String.to_integer/1)
mk = fn n -> %{id: "WO-#{n}", subject: "case:#{n}", classification: "KNOWN",
  standing: "READY_FOR_ENGINEER_DISPOSITION", obligation: "synthetic work #{n}",
  owner: "bench", next_action: "inspect", required_evidence: [], supporting_evidence: ["fixture"],
  authority: "SELECT_CONSTRUCT_ONLY", human_gate: "ENGINEER_DISPOSITION_REQUIRED"} end
for size <- sizes do
  input = Enum.map(1..size, mk)
  Benchee.run(%{
    "project_many/#{size}" => fn -> EngineerWorkflow.project_many(input, provider: "jira", project: "CS2") end,
    "project+jsonl/#{size}" => fn ->
      {:ok, projected} = EngineerWorkflow.project_many(input, provider: "jira", project: "CS2")
      EngineerWorkflow.encode_jsonl(projected)
    end
  }, time: 2, memory_time: 1, reduction_time: 1, print: [fast_warning: false])
end
