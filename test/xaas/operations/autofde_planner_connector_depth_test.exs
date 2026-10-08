defmodule Xaas.Operations.AutofdePlannerConnectorDepthTest do
  @moduledoc """
  Depth court for the four UNKNOWN `AutofdePlanner*` connector resources
  (`AutofdePlannerCatalog`, `AutofdePlannerCacheStats`, `AutofdePlannerCacheHotset`,
  `AutofdePlannerMatch`) -- the slice W984cw4's census left for a later lane
  (W984dk census: 5 Operations UNKNOWN; W984cw4 took `RefusalLedgerExport`).

  Chicago-style: every collaborator is real. The cnv-deploy `/invoke` surface is a
  real in-test `Bandit` HTTP listener speaking the real wire contract (the same
  `%{"execution" => %{"stdout" => ..., "exit_code" => ...}}` envelope cnv-deploy's
  http.rs returns); `Req` performs a real loopback HTTP round-trip; persistence goes
  through real Ash create actions into real Postgres (real migrations back each
  table); authorization is the real `Xaas.Checks.SystemActor` policy check. Nothing
  about `Req`, Ash, Ecto, or the connector code is stubbed.

  Mutation rationale per test:
    1. kills a mutant that invents a `trajectory_sha256` for a non-solve tool,
       drops `requested_at`, or parses the FIRST `{` instead of the LAST `{\n`
       (the frozenset-noise regression the extraction logic exists for);
    2. kills a mutant that sends the wrong `tool` per resource or drops the
       `domain` argument on `fabric__match`;
    3. kills a mutant that swallows a nonzero `exit_code` (treats it as success);
    4. kills a mutant that admits non-200 / malformed-envelope / unreachable
       responses as successful empty creates;
    5. kills a mutant that reverts the XAAS-2602 `SystemActor` predicate back to
       `always()` (bare always() would admit a foreign actor's create).
  """
  use ExUnit.Case, async: false

  @resources [
    {Xaas.Operations.AutofdePlannerCatalog, :request_catalog},
    {Xaas.Operations.AutofdePlannerCacheStats, :request_cache_stats},
    {Xaas.Operations.AutofdePlannerCacheHotset, :request_cache_hotset},
    {Xaas.Operations.AutofdePlannerMatch, :request_match}
  ]

  defmodule CnvInvokePlug do
    @moduledoc """
    Real Plug standing in for the real cnv-deploy /invoke HTTP surface: captures
    each received request body into a real Agent and answers per the configured
    `:respond` instruction.
    """
    import Plug.Conn

    def init(opts), do: opts

    def call(conn, opts) do
      {:ok, body, conn} = read_body(conn)
      agent = Keyword.fetch!(opts, :agent)
      Agent.update(agent, fn reqs -> reqs ++ [Jason.decode!(body)] end)

      respond =
        case Keyword.fetch!(opts, :respond) do
          {:ok, envelope_json} -> envelope_json
          json when is_binary(json) -> json
          {status, text} when is_integer(status) -> {status, text}
        end

      case respond do
        {status, text} ->
          send_resp(conn, status, text)

        body when is_binary(body) ->
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(200, body)
      end
    end
  end

  setup context do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)

    {:ok, agent} = Agent.start_link(fn -> [] end)

    # Real payload shaped like cnv-deploy's real Typer output: preceded by
    # genuine log-noise lines -- one of which itself contains a literal `{`
    # (the frozenset repr case the extraction logic documents) -- and the real
    # JSON object emitted `indent=2`, i.e. its opening brace alone on its own line.
    noise_payload =
      "frozenset({1, 2, 3}) planner boot" <>
        "\nwarning: partial match { unclosed brace in log line" <>
        "\n{\n  \"ok\": true,\n  \"rows\": [1, 2, 3]\n}"

    envelope =
      Jason.encode!(%{
        "execution" => %{"stdout" => noise_payload, "exit_code" => 0}
      })

    {:ok, server_pid} =
      Bandit.start_link(
        plug: {CnvInvokePlug, [agent: agent, respond: {:ok, envelope}]},
        port: 0,
        ip: {127, 0, 0, 1}
      )

    Process.unlink(server_pid)
    {:ok, {_addr, port}} = ThousandIsland.listener_info(server_pid)

    original_env = Application.get_env(:xaas, :cnv_deploy_base_url)

    Application.put_env(:xaas, :cnv_deploy_base_url, "http://127.0.0.1:#{port}")

    on_exit(fn ->
      if Process.alive?(server_pid), do: Process.exit(server_pid, :shutdown)
      Application.put_env(:xaas, :cnv_deploy_base_url, original_env)
    end)

    %{agent: agent, port: port, envelope: envelope}
  end

  defp create!(resource, action, query, extra \\ %{}) do
    resource
    |> Ash.Changeset.for_create(action, Map.merge(%{query: query}, extra))
    |> Ash.create(actor: Xaas.SystemAuthority.new(:autofde_coverage_monitor))
  end

  defp count!(resource), do: resource |> Ash.read!() |> length()

  test "1. success path persists the decoded cnv_response and requested_at and invents no trajectory_sha256 for any of the four connectors" do
    # Mutation rationale: kills invented-digest, missing-timestamp, and
    # first-`{`-instead-of-last-`{\n` mutants (a first-`{` parse would decode
    # `{1, 2, 3}` noise fragments, not the real trailing payload).
    for {resource, action} <- @resources do
      {:ok, record} = create!(resource, action, "w984dq2-probe")

      assert %{"ok" => true, "rows" => [1, 2, 3]} = record.cnv_response
      assert %DateTime{} = record.requested_at
      # No digest is invented for a non-solve tool -- the field stays nil.
      assert record.trajectory_sha256 == nil
    end
  end

  test "2. each connector dispatches its real tool name over the wire; match passes the query as domain" do
    # Mutation rationale: kills wrong-tool-per-resource mutants and a mutant
    # dropping `arguments.domain` on fabric__match (Match is the only connector
    # whose query reaches the wire).
    for {resource, action} <- @resources do
      {:ok, agent} = Agent.start_link(fn -> [] end)

      {:ok, server_pid} =
        Bandit.start_link(
          plug: {CnvInvokePlug, [agent: agent, respond: {400, "body ignored"}]},
          port: 0,
          ip: {127, 0, 0, 1}
        )

      Process.unlink(server_pid)
      {:ok, {_addr, port}} = ThousandIsland.listener_info(server_pid)
      original = Application.get_env(:xaas, :cnv_deploy_base_url)
      Application.put_env(:xaas, :cnv_deploy_base_url, "http://127.0.0.1:#{port}")

      {:error, _} = create!(resource, action, "blocks")

      Application.put_env(:xaas, :cnv_deploy_base_url, original)
      Process.exit(server_pid, :shutdown)

      assert [%{"tool" => tool, "arguments" => args}] = Agent.get(agent, & &1)

      expected_tool =
        case resource do
          Xaas.Operations.AutofdePlannerCatalog -> "fabric__catalog"
          Xaas.Operations.AutofdePlannerCacheStats -> "fabric__cache-stats"
          Xaas.Operations.AutofdePlannerCacheHotset -> "fabric__cache-hotset"
          Xaas.Operations.AutofdePlannerMatch -> "fabric__match"
        end

      assert tool == expected_tool

      case resource do
        Xaas.Operations.AutofdePlannerMatch -> assert args == %{"domain" => "blocks"}
        _ -> assert args == %{}
      end
    end
  end

  test "3. nonzero exit_code is a typed error naming the tool, and no row is persisted" do
    # Mutation rationale: kills a mutant that treats a nonzero exit_code as
    # success (or that persists the create despite the change error).
    envelope =
      Jason.encode!(%{
        "execution" => %{
          "stdout" => "",
          "exit_code" => 2,
          "stderr" => "domain not found: blocks"
        }
      })

    for {resource, action} <- @resources do
      start_cnv_server!(envelope)

      before = count!(resource)
      {:error, error} = create!(resource, action, "blocks")

      assert error_message(error) =~ "exited 2"
      assert error_message(error) =~ "domain not found"
      assert count!(resource) == before
    end
  end

  test "4. non-200 status, malformed envelope, and unreachable server are each typed failures with no persisted row" do
    # Mutation rationale: kills mutants admitting any of these three real
    # failure classes as successful creates.
    for {resource, action} <- @resources do
      # (a) non-200
      start_cnv_server!({500, "internal cnv-deploy error"})
      before = count!(resource)
      {:error, error} = create!(resource, action, "q")
      assert error_message(error) =~ "returned status 500"
      assert count!(resource) == before

      # (b) 200 but malformed envelope (no "execution" key)
      start_cnv_server!(Jason.encode!(%{"unexpected" => "shape"}))
      {:error, error} = create!(resource, action, "q")
      assert error_message(error) =~ "unexpected cnv-deploy /invoke response shape"
      assert count!(resource) == before

      # (c) unreachable server (nothing listening)
      dead = Application.get_env(:xaas, :cnv_deploy_base_url)
      Application.put_env(:xaas, :cnv_deploy_base_url, "http://127.0.0.1:1")
      {:error, error} = create!(resource, action, "q")
      assert error_message(error) =~ "request failed"
      assert count!(resource) == before
      Application.put_env(:xaas, :cnv_deploy_base_url, dead)
    end
  end

  test "5. deny-by-default: a non-system actor is forbidden on create; the SystemActor bypass is the admitting path" do
    # Mutation rationale: kills a mutant reverting the XAAS-2602 policy from
    # `SystemActor` back to bare `always()` -- under always() this create would
    # be admitted instead of forbidden.
    {resource, action} = Enum.at(@resources, 0)

    {:error, error} =
      resource
      |> Ash.Changeset.for_create(action, %{query: "blocks"})
      |> Ash.create(actor: %{actor: :foreign_lane_actor})

    assert match?(%Ash.Error.Forbidden{}, error)

    # The admitting path (already exercised end-to-end in test 1) for contrast:
    assert match?({:ok, _}, create!(resource, action, "blocks"))
  end

  defp error_message(error), do: error |> inspect() |> to_string()

  defp start_cnv_server!(respond) do
    {:ok, agent} = Agent.start_link(fn -> [] end)

    {:ok, server_pid} =
      Bandit.start_link(plug: {CnvInvokePlug, [agent: agent, respond: respond]},
                        port: 0,
                        ip: {127, 0, 0, 1})

    Process.unlink(server_pid)
    {:ok, {_addr, port}} = ThousandIsland.listener_info(server_pid)
    original = Application.get_env(:xaas, :cnv_deploy_base_url)
    Application.put_env(:xaas, :cnv_deploy_base_url, "http://127.0.0.1:#{port}")

    on_exit(fn ->
      if Process.alive?(server_pid), do: Process.exit(server_pid, :shutdown)
    end)

    :ok
  end
end
