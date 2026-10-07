alias Xaas.Sjira.{Atlassian, DeliveryBatch}

mk = fn n ->
  %{
    "identity" => "SJ-#{n}",
    "project_key" => "XAAS",
    "issue_type" => "Task",
    "summary" => "Item #{n}",
    "description" => String.duplicate("evidence ", rem(n, 64) + 1),
    "depends_on" => if(n > 1, do: ["SJ-#{n - 1}"], else: [])
  }
end

for size <- [10, 100, 1_000, 10_000] do
  items = Enum.map(1..size, mk)

  Benchee.run(
    %{
      "project/#{size}" => fn -> Enum.map(items, &Atlassian.project/1) end,
      "dependency-plan/#{size}" => fn -> DeliveryBatch.plan(items, max_batch: 50) end
    },
    time: 3,
    memory_time: 1,
    print: [fast_warning: false]
  )
end
