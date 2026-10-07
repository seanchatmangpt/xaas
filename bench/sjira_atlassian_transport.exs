alias Xaas.Sjira.AtlassianTransport

count =
  case System.get_env("SJIRA_BENCH_COUNT") do
    nil -> 10_000
    value -> String.to_integer(value)
  end

items =
  for n <- 1..count do
    %{
      "order" => "urn:bench:work:" <> Integer.to_string(n),
      "iri" => "urn:bench:work:" <> Integer.to_string(n),
      "checkpoint_of" => "urn:bench:checkpoint:1",
      "capability" => "atlassian:jira.issue",
      "provider" => "atlassian",
      "tuple_digest" =>
        :crypto.hash(:sha256, Integer.to_string(n)) |> Base.encode16(case: :lower),
      "classification" => "Successor",
      "resolve" => "ok",
      "route" => "KNOWN",
      "standing" => "UNKNOWN",
      "reason" => "provider_registered",
      "summary" => "Benchmark work item " <> Integer.to_string(n)
    }
  end

request_fun = fn _, _, _, _ ->
  {:ok, %{status: 201, headers: [], body: %{"key" => "BENCH-1"}}}
end

opts = [
  base_url: "https://example.atlassian.net",
  project_key: "BENCH",
  request_fun: request_fun
]

{micros, {:ok, envelopes}} =
  :timer.tc(fn ->
    AtlassianTransport.plan(items, opts)
  end)

bytes =
  envelopes
  |> Enum.reduce(0, fn envelope, acc ->
    acc + byte_size(envelope["encoded_body"])
  end)

IO.puts(
  Jason.encode!(%{
    "count" => count,
    "elapsed_us" => micros,
    "envelopes_per_second" => Float.round(count / (micros / 1_000_000), 2),
    "encoded_bytes" => bytes,
    "average_body_bytes" => Float.round(bytes / count, 2)
  })
)
