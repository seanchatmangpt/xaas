defmodule XaasWeb.A2A.A2aUncoveredBranchCourtW984emTest do
  @moduledoc """
  Lane W984em probe + depth court over the A2A surface's genuinely
  unexercised state-bearing branches (census: 6 lib modules behind
  test/xaas_web/a2a/, disposition table in
  docs/sjira/v26.10.6/plans/w984em-probe.md).

  Chicago-style: real Plug.Conn through the real `/a2a` scope, real
  `A2A.Agent` GenServers via `A2A.call/3`, real Postgres rows in the
  sandbox. Zero mocks. Each test names the mutation it kills.
  """

  use XaasWeb.ConnCase, async: false

  alias Xaas.Library.{Book, Checkout, HoldRequest, PersonaGrant}
  alias Xaas.Operations.AuditLogEntry
  require Ash.Query

  @internal_api_caller_id "internal_api_token"
  @card_path "/a2a/v1/.well-known/agent-card.json"
  @rpc_path "/a2a/v1"

  setup context do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    agents = %{conn: context.conn}

    agents =
      if context[:uses_next_read_agent] do
        name = :"next_read_user_agent_w984em_#{System.unique_integer([:positive])}"
        {:ok, pid} = XaasWeb.A2A.NextReadUserAgent.start_link(name: name)
        on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
        Map.put(agents, :agent, pid)
      else
        agents
      end

    agents =
      if context[:uses_zoe_agent] do
        name = :"zoe_event_simulation_agent_w984em_#{System.unique_integer([:positive])}"
        {:ok, pid} = XaasWeb.A2A.ZoeEventSimulationAgent.start_link(name: name)
        on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
        Map.put(agents, :zoe, pid)
      else
        agents
      end

    {:ok, agents}
  end

  defp create_granted_user! do
    user = Xaas.Generator.create_user!()

    PersonaGrant.grant!(
      @internal_api_caller_id,
      user.id,
      "w984em",
      authorize?: false
    )

    user
  end

  # Fixed defaults; Xaas.Generator.create_book!/1's own defaults differ
  # (random grade, 2 copies) -- same guard as next_read_user_agent_test.exs.
  defp create_book!(attrs) do
    Xaas.Generator.create_book!(
      Map.merge(%{grade_level: 5, available_copies: 3, total_copies: 3}, attrs)
    )
  end

  defp task_text(task) do
    (task.artifacts ++ [%{parts: []}])
    |> Enum.flat_map(& &1.parts)
    |> Enum.map_join(" ", fn %A2A.Part.Text{text: text} -> text end)
  end

  defp status_text(nil), do: ""

  defp status_text(msg) do
    Enum.map_join(msg.parts, " ", fn
      %A2A.Part.Text{text: t} -> t
      _ -> ""
    end)
  end

  defp audit_entries_for(user_id) do
    AuditLogEntry
    |> Ash.Query.filter(resource_type == "PersonaGrant" and resource_id == ^to_string(user_id))
    |> Ash.read!(authorize?: false)
  end

  @tag uses_next_read_agent: true
  test "browse over an empty grade band answers 'No books found' and no Checkout row exists", %{
    agent: agent
  } do
    # Mutation killed: deleting the `books == []` branch in
    # NextReadUserAgent.browse/2 (lib/xaas_web/a2a/next_read_user_agent.ex:158)
    # would make an empty-band browse crash on Enum.join of an empty summary
    # or report a phantom "Found 0: ..." string; this pins the real
    # empty-band state response. Grade 1000 keeps the query band
    # (grade-1..grade+1) clear of any seeded catalog row, so the empty-band
    # branch is genuinely reached.
    create_book!(%{title: "Only High School Book", grade_level: 12})

    user = create_granted_user!()

    assert {:ok, task} = A2A.call(agent, "as:#{user.id} browse grade:1000")
    assert task.status.state == :completed

    text = task_text(task)
    assert text == "No books found for grade 1000."
  end

  @tag uses_next_read_agent: true
  test "non-UUID as:<user_id> fails actor resolution at the list_active argument cast and writes a denied audit entry", %{
    agent: agent
  } do
    # Mutation killed: deleting the {:error, _} arm of resolve_actor/2
    # (lib/xaas_web/a2a/next_read_user_agent.ex:112-119) -- the cast-failure
    # deny path, distinct from the {:ok, []} ungranted path -- would leave a
    # non-UUID impersonation attempt without a denied AuditLogEntry. Real
    # state: PersonaGrant.list_active's user_id argument is :uuid
    # (lib/xaas/library/persona_grant.ex), so "not-a-uuid" errors before any
    # grant filter ever runs.
    assert {:ok, task} = A2A.call(agent, "as:not-a-uuid browse grade:5")

    assert task.status.state == :failed
    refute task_text(task) =~ "Found "

    entries = audit_entries_for("not-a-uuid")
    assert Enum.any?(entries, &(&1.metadata["outcome"] == "denied"))
    assert Enum.any?(entries, &(&1.action == "a2a.actor_resolution.denied"))
    refute Enum.any?(entries, &(&1.metadata["outcome"] == "allowed"))
  end

  @tag uses_next_read_agent: true
  test "checkout on a drained book places a real HoldRequest and leaves inventory at zero", %{
    agent: agent
  } do
    # Mutation killed: deleting the CirculationBorrowReactor default branch
    # (HoldRequest :place) or the agent's %HoldRequest{} reply arm
    # (lib/xaas_web/a2a/next_read_user_agent.ex:202-208) -- the
    # "placed hold" A2A reply path had no court; return_hold_cascade tests
    # exercise the cascade, not the agent's hold reply. Checkout count is
    # asserted as a delta (the test DB carries pre-existing checkout rows).
    user = create_granted_user!()
    book = create_book!(%{available_copies: 0, total_copies: 2})
    before_checkouts = Ash.count!(Checkout, authorize?: false)

    assert {:ok, task} =
             A2A.call(agent, "as:#{user.id} checkout book:#{book.id} school:test-school")

    assert task.status.state == :completed
    text = task_text(task)
    assert text =~ "No copies available -- placed hold "
    assert text =~ "book #{book.id}"
    assert text =~ "for user #{user.id}"

    hold =
      HoldRequest
      |> Ash.Query.filter(book_id == ^book.id and user_id == ^user.id)
      |> Ash.read_one!(authorize?: false)

    assert hold != nil

    reloaded = Ash.get!(Book, book.id, authorize?: false)
    assert reloaded.available_copies == 0
    assert Ash.count!(Checkout, authorize?: false) == before_checkouts
  end

  @tag uses_next_read_agent: true
  test "as-prefixed message with an unrecognized command transitions the task to input_required", %{
    agent: agent
  } do
    # Mutation killed: deleting run/3's true-arm fallback
    # (lib/xaas_web/a2a/next_read_user_agent.ex:140-141) would crash or
    # return a wrong-shaped reply for a parsed-but-unknown command; the
    # existing usage-path court only covers the no-"as:" parse failure.
    user = create_granted_user!()

    assert {:ok, task} = A2A.call(agent, "as:#{user.id} frobnicate the shelves")
    assert task.status.state == :input_required

    assert status_text(task.status.message) =~ "Expected:"
    usage = status_text(task.status.message)
    assert usage =~ "browse grade:"
  end

  @tag uses_zoe_agent: true
  test "zoe 'simulate' with a non-object snapshot refuses without a completed reply", %{
    zoe: zoe
  } do
    # Mutation killed: deleting the catch-all `_ ->` arm in
    # ZoeEventSimulationAgent.run_simulation/1
    # (lib/xaas_web/a2a/zoe_event_simulation_agent.ex:67-68) would let a
    # non-map snapshot fall through to EventSimulation.simulate/2's
    # function-head {:error, :invalid_simulation} -- a different refusal
    # shape -- instead of the agent's own JSON-object refusal.
    assert {:ok, task} = A2A.call(zoe, ~s(simulate {"snapshot": 5, "scenario": {}}))
    assert task.status.state == :failed

    text = status_text(task.status.message)
    assert text =~ "snapshot and scenario must be JSON objects"
  end

  @tag uses_zoe_agent: true
  test "zoe 'simulate' with valid JSON but a contract-invalid snapshot stringifies a structured refusal", %{
    zoe: zoe
  } do
    # Mutation killed: deleting the {:error, reason} -> "simulation refused:"
    # arm (lib/xaas_web/a2a/zoe_event_simulation_agent.ex:64-65) would drop
    # the stringified-refusal contract for well-formed JSON whose payload
    # the simulator refuses (real observed refusal: {:invalid, :event_id}
    # for an empty snapshot/scenario pair).
    payload = %{"snapshot" => %{}, "scenario" => %{}}

    assert {:ok, task} = A2A.call(zoe, "simulate " <> Jason.encode!(payload))
    assert task.status.state == :failed

    text = status_text(task.status.message)
    # The hex runtime renders a string {:error, reason} as
    # "Error: #{inspect(reason)}" on task.status.message.
    assert text =~ "Error:"
    assert text =~ "simulation refused:"
    assert text =~ "{:invalid, :event_id}"
  end

  test "v1 POST JSON-RPC responses do not carry the wrapper's GET-card caching contract" do
    # Mutation killed: dropping V1TransportPlug.restore_card_caching/1's
    # `conn.method == "GET"` guard (lib/xaas_web/a2a/v1_transport_plug.ex:27)
    # would rewrite every response's cache-control to "public, max-age=300",
    # including JSON-RPC POST replies (the transport sets its own
    # cache-control on non-card responses). Real wire through the /a2a scope.
    if Process.whereis(XaasWeb.A2A.NextReadAshAgent) == nil do
      start_supervised!(XaasWeb.A2A.NextReadAshAgent)
    end

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
      |> put_req_header("content-type", "application/json")
      |> post(
        @rpc_path,
        Jason.encode!(%{
          "jsonrpc" => "2.0",
          "method" => "message/send",
          "params" => %{
            "message" => %{
              "role" => "ROLE_USER",
              "messageId" => AshA2A.Protocol.ID.generate("msg"),
              "parts" => [%{"kind" => "text", "text" => "hddl:plan"}]
            }
          },
          "id" => "w984em-post-cc"
        })
      )

    assert conn.status == 200
    %{"result" => %{"task" => %{"status" => %{"state" => "TASK_STATE_COMPLETED"}}}} =
      json_response(conn, 200)

    assert get_resp_header(conn, "cache-control") != ["public, max-age=300"]

    # The GET card contract itself stays pinned (pairing assertion so the
    # court cannot pass because caching broke everywhere).
    card_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
      |> get(@card_path)

    assert card_conn.status == 200
    assert get_resp_header(card_conn, "cache-control") == ["public, max-age=300"]
  end
end
