defmodule Xaas.Sjira.AtlassianTransportTest do
  use ExUnit.Case, async: true

  alias Xaas.Sjira.AtlassianTransport
  alias Xaas.Sjira.Checkpoint
  alias Xaas.Sjira.RateLimit

  defmodule MemoryCheckpoint do
    use Agent

    def start_link(initial \\ %{}), do: Agent.start_link(fn -> initial end)

    def load(_scope, run_key, pid: pid) do
      {:ok, Agent.get(pid, &Map.get(&1, run_key))}
    end

    def save(_scope, run_key, state, pid: pid) do
      Agent.update(pid, &Map.put(&1, run_key, state))
      {:ok, "memory://" <> run_key}
    end

    def migrate(state, _version), do: {:ok, state}
  end

  defp known_item(overrides \\ %{}) do
    Map.merge(
      %{
        "order" => "urn:work:42",
        "iri" => "urn:work:42",
        "checkpoint_of" => "urn:checkpoint:9",
        "capability" => "atlassian:jira.issue",
        "provider" => "atlassian",
        "tuple_digest" => "abc123",
        "classification" => "Successor",
        "resolve" => "ok",
        "route" => "KNOWN",
        "standing" => "UNKNOWN",
        "reason" => "provider_registered",
        "resolved" => %{"provider" => "atlassian", "recipe_id" => "jira.issue"}
      },
      overrides
    )
  end

  defp opts(request_fun, extra \\ []) do
    [
      base_url: "https://example.atlassian.net",
      project_key: "ENG",
      request_fun: request_fun,
      now_fun: fn -> ~U[2026-09-27 05:20:00Z] end,
      now_ms_fun: fn -> 1_790_485_200_000 end,
      sleep_fun: fn _ -> :ok end
    ] ++ extra
  end

  test "plan emits deterministic create envelope and semantic property" do
    request_fun = fn _, _, _, _ -> {:ok, %{status: 201, headers: [], body: %{}}} end

    assert {:ok, [request]} =
             AtlassianTransport.plan(
               [known_item(%{"summary" => "Ship semantic work"})],
               opts(request_fun)
             )

    assert request["method"] == "post"
    assert request["path"] == "/rest/api/3/issue"
    assert request["body"]["fields"]["project"] == %{"key" => "ENG"}
    assert request["body"]["fields"]["summary"] == "Ship semantic work"

    [property] = request["body"]["properties"]
    assert property["key"] == "xaas.semantic.identity"
    assert property["value"]["order"] == "urn:work:42"
    assert is_binary(request["delivery_id"])
  end

  test "existing jira_key becomes update request" do
    request_fun = fn _, _, _, _ -> {:ok, %{status: 204, headers: [], body: nil}} end

    assert {:ok, [request]} =
             AtlassianTransport.plan(
               [known_item(%{"jira_key" => "ENG-17"})],
               opts(request_fun)
             )

    assert request["method"] == "put"
    assert request["path"] == "/rest/api/3/issue/ENG-17"
  end

  test "non-known successor is refused before transport" do
    request_fun = fn _, _, _, _ -> flunk("transport must not run") end

    assert {:error, {:successor_not_routable, "urn:work:42", "UNSUPPORTED", _}} =
             AtlassianTransport.plan(
               [known_item(%{"route" => "UNSUPPORTED"})],
               opts(request_fun)
             )
  end

  test "deduplicate keeps first semantic identity and tuple digest pair" do
    first = known_item(%{"summary" => "first"})
    duplicate = known_item(%{"summary" => "duplicate"})
    second = known_item(%{"order" => "urn:work:43", "tuple_digest" => "def456"})

    assert [^first, ^second] = AtlassianTransport.deduplicate([first, duplicate, second])
  end

  test "429 uses retry-after before exponential backoff" do
    assert 7_000 ==
             RateLimit.delay_ms([{"Retry-After", "7"}], 3,
               now_ms: 0,
               base_backoff_ms: 500,
               max_backoff_ms: 30_000
             )
  end

  test "rate-limit reset converts epoch to bounded delay" do
    assert 5_000 ==
             RateLimit.delay_ms([{"X-RateLimit-Reset", "15"}], 1,
               now_ms: 10_000,
               base_backoff_ms: 500,
               max_backoff_ms: 30_000
             )
  end

  test "delivery retries 429 and advances checkpoint on success" do
    {:ok, checkpoint} = MemoryCheckpoint.start_link()
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    request_fun = fn _method, _url, _headers, _body ->
      attempt = Agent.get_and_update(counter, fn n -> {n + 1, n + 1} end)

      if attempt == 1 do
        {:ok, %{status: 429, headers: [{"retry-after", "0"}], body: %{}}}
      else
        {:ok, %{status: 201, headers: [], body: %{"key" => "ENG-42", "id" => "10042"}}}
      end
    end

    assert {:ok, result} =
             AtlassianTransport.deliver(
               "run-1",
               [known_item()],
               opts(request_fun,
                 checkpoint_module: MemoryCheckpoint,
                 checkpoint_opts: [pid: checkpoint]
               )
             )

    assert result["status"] == "complete"
    assert result["delivered_count"] == 1
    assert result["failed_count"] == 0
    assert Agent.get(counter, & &1) == 2
  end

  test "retry exhaustion becomes terminal failed disposition and continues" do
    {:ok, checkpoint} = MemoryCheckpoint.start_link()

    request_fun = fn _method, _url, _headers, _body ->
      {:error, :econnrefused}
    end

    assert {:ok, result} =
             AtlassianTransport.deliver(
               "run-exhaust",
               [known_item()],
               opts(request_fun,
                 checkpoint_module: MemoryCheckpoint,
                 checkpoint_opts: [pid: checkpoint],
                 max_attempts: 2
               )
             )

    assert result["delivered_count"] == 0
    assert result["failed_count"] == 1
    [failure] = result["failed"]
    assert failure["outcome"] == "RETRY_EXHAUSTED"
    assert failure["attempts"] == 2
  end

  test "persisted inflight envelope is replayed with the same delivery id" do
    {:ok, checkpoint} = MemoryCheckpoint.start_link()
    {:ok, seen} = Agent.start_link(fn -> [] end)

    request_fun = fn _method, _url, headers, _body ->
      id =
        Enum.find_value(headers, fn {key, value} ->
          if String.downcase(key) == "x-xaas-delivery-id", do: value
        end)

      Agent.update(seen, &[id | &1])
      {:ok, %{status: 201, headers: [], body: %{"key" => "ENG-42"}}}
    end

    assert {:ok, [envelope]} = AtlassianTransport.plan([known_item()], opts(request_fun))

    persisted = %{
      "version" => 1,
      "scope" => "sjira-atlassian-delivery",
      "run_key" => "run-resume",
      "status" => "running",
      "cursor" => 0,
      "attempt" => 1,
      "requests" => [envelope],
      "completed" => %{},
      "failed" => [],
      "inflight" => envelope,
      "created_at" => "2026-09-27T05:20:00Z",
      "updated_at" => "2026-09-27T05:20:00Z"
    }

    assert {:ok, _} =
             MemoryCheckpoint.save(
               "sjira-atlassian-delivery",
               "run-resume",
               persisted,
               pid: checkpoint
             )

    assert {:ok, result} =
             AtlassianTransport.resume(
               "run-resume",
               opts(request_fun,
                 checkpoint_module: MemoryCheckpoint,
                 checkpoint_opts: [pid: checkpoint]
               )
             )

    assert result["delivered_count"] == 1
    assert [id] = Agent.get(seen, & &1)
    assert id == envelope["delivery_id"]
  end

  test "filesystem checkpoint path never contains raw run key" do
    path =
      Checkpoint.path(
        "sjira-atlassian-delivery",
        "../../tenant/secret?x=1",
        checkpoint_dir: "/tmp/checkpoints"
      )

    refute String.contains?(path, "../")
    refute String.contains?(path, "tenant/secret")
    assert String.ends_with?(path, ".json")
  end

  test "provider 400 is terminal refusal, not retried" do
    {:ok, checkpoint} = MemoryCheckpoint.start_link()
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    request_fun = fn _, _, _, _ ->
      Agent.update(counter, &(&1 + 1))

      {:ok,
       %{
         status: 400,
         headers: [],
         body: %{"errorMessages" => ["summary is required"], "errors" => %{}}
       }}
    end

    assert {:ok, result} =
             AtlassianTransport.deliver(
               "run-400",
               [known_item()],
               opts(request_fun,
                 checkpoint_module: MemoryCheckpoint,
                 checkpoint_opts: [pid: checkpoint]
               )
             )

    assert Agent.get(counter, & &1) == 1
    [failure] = result["failed"]
    assert failure["outcome"] == "REFUSED_BY_PROVIDER"
    assert failure["status"] == 400
  end
end
