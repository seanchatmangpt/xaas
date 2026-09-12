defmodule XaasWeb.OcelEnvelopeAvatarsTest.CapturingPlug do
  @moduledoc false
  use Plug.Router

  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
  plug(:match)
  plug(:dispatch)

  post "/api/v1/ocel/events" do
    send(:ocel_envelope_avatars_test, {:captured_envelope, conn.body_params})

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(201, Jason.encode!(%{"status" => "success"}))
  end

  match _ do
    Plug.Conn.send_resp(conn, 404, "not found")
  end
end

defmodule XaasWeb.OcelEnvelopeAvatarsTest do
  @moduledoc """
  Five real Chicago-style avatar scenarios proving the generated
  `Xaas.Telemetry.OcelEnvelope.build/3` (generated from
  `priv/packs/xaas_telemetry_pack/`, see `lib/xaas/telemetry/ocel_envelope.ex`'s
  header) works end to end against ex4pm's real
  `Ex4pm.OCEL.validate_envelope/1` contract. No mocking of any collaborator:
  real Ash actions, real `:telemetry` events, real `Xaas.Telemetry.OcelAshEmitter`
  handler, real Bandit HTTP server capturing the real POST body, real `A2A.call/3`,
  real `/mcp` JSON-RPC HTTP round trip, and a real second invocation of the real
  generator's render pipeline for the idempotency proof.

  1. Real MCP `list_books` tool call -> real Ash read action -> real `:stop`
     telemetry -> real `OcelAshEmitter.handle_event/4` -> real
     `OcelForwarder.forward/1` -> real `OcelEnvelope.build/3` -> real HTTP POST
     captured by a real local Bandit server -> asserted against
     `Ex4pm.OCEL.validate_envelope/1`'s real contract.
  2. Real A2A checkout message (`A2A.call/3`) -> real `Checkout.borrow` Ash
     action -> the same real telemetry -> forward -> envelope path as above.
  3. Regression: the generated `OcelEnvelope.build/3` produces byte-identical
     output (via `:erlang.term_to_binary/1` on the returned map, plus a
     `Jason.encode!/1` byte comparison) to a literal reconstruction of what the
     hand-written pre-generation version produced for the same input.
  4. Re-generation idempotency: run the real generator's admission pipeline
     (`GgenIgniter.Reactors.ReconcileReactor.plan/1`) twice against the real
     `xaas_telemetry_pack`, assert the computed `desired_hash` is identical
     both times.
  5. A real SHACL cardinality edge case: an empty `"events"` list (`sh:minCount`
     is on each event's own `activity`/`timestamp` properties, not on the
     envelope's `events` collection itself -- `Ex4pm.OCEL.validate_envelope/1`
     only requires `is_list/1` or `is_map/1`, so `[]` is valid) and a missing
     optional `"previous_digest"` field, both asserted against the real
     `validate_envelope/1` return value.
  """

  use XaasWeb.ConnCase, async: false

  alias Xaas.Library.{Checkout, PersonaGrant}
  alias Xaas.Telemetry.OcelEnvelope

  require Ash.Query

  @internal_api_caller_id "internal_api_token"

  alias XaasWeb.OcelEnvelopeAvatarsTest.CapturingPlug

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    Process.register(self(), :ocel_envelope_avatars_test)

    port = 42_900 + :erlang.phash2(self(), 500)

    {:ok, server_pid} = Bandit.start_link(plug: CapturingPlug, port: port, ip: {127, 0, 0, 1})
    Process.unlink(server_pid)

    previous_url = Application.get_env(:xaas, :ex4pm_ocel_ingest_url)

    Application.put_env(
      :xaas,
      :ex4pm_ocel_ingest_url,
      "http://127.0.0.1:#{port}/api/v1/ocel/events"
    )

    on_exit(fn ->
      if previous_url do
        Application.put_env(:xaas, :ex4pm_ocel_ingest_url, previous_url)
      else
        Application.delete_env(:xaas, :ex4pm_ocel_ingest_url)
      end

      if Process.alive?(server_pid), do: Process.exit(server_pid, :shutdown)
    end)

    :ok
  end

  defp with_internal_api_token(conn) do
    put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
  end

  defp mcp_post(conn, body) do
    conn
    |> with_internal_api_token()
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json")
    |> post("/mcp", Jason.encode!(body))
  end

  defp initialize!(conn, client_name) do
    conn =
      mcp_post(conn, %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => "2024-11-05",
          "capabilities" => %{},
          "clientInfo" => %{"name" => client_name, "version" => "0.0.0"}
        }
      })

    body = json_response(conn, 200)
    assert body["result"]["protocolVersion"] == "2024-11-05"

    conn
    |> get_resp_header("mcp-session-id")
    |> List.first()
  end

  defp create_book!(tag, available_copies \\ 3) do
    Xaas.Generator.create_book!(%{
      title: "#{tag}-book",
      author: "Avatar Author",
      grade_level: Decimal.new("5.0"),
      available_copies: available_copies,
      total_copies: available_copies
    })
  end

  defp create_granted_user!(tag) do
    user = Xaas.Generator.create_user!(%{email: "#{tag}@example.com"})
    PersonaGrant.grant!(@internal_api_caller_id, user.id, tag, authorize?: false)
    user
  end

  # Drains any envelopes already sitting in the mailbox (e.g. from the
  # `create_book!`/`create_granted_user!` setup calls' own real OCEL
  # `create` events) so the assertion below observes only the event(s)
  # produced by the action actually under test.
  defp flush_captured_envelopes! do
    receive do
      {:captured_envelope, _} -> flush_captured_envelopes!()
    after
      0 -> :ok
    end
  end

  # Real-mailbox scan for the envelope whose single wrapped event's
  # "ocel:activity" contains `substring` -- multiple real Ash actions can
  # each emit and forward their own envelope inside the same test (e.g. a
  # background `ash_ai_update_embeddings` update triggered by book
  # creation), so asserting on strictly the first received message is not
  # a reliable way to find the one under test.
  defp assert_receive_envelope_matching!(substring, timeout \\ 2_000) do
    receive do
      {:captured_envelope, envelope} ->
        events = Map.get(envelope, "events", [])

        if Enum.any?(List.wrap(events), fn event ->
             String.contains?(to_string(event["ocel:activity"]), substring)
           end) do
          envelope
        else
          assert_receive_envelope_matching!(substring, timeout)
        end
    after
      timeout ->
        flunk(
          "no captured OCEL envelope with an event activity containing #{inspect(substring)} arrived within #{timeout}ms"
        )
    end
  end

  # -- Avatar 1 --------------------------------------------------------------

  test "avatar 1: real MCP list_books call forwards a real OCEL envelope matching Ex4pm.OCEL.validate_envelope/1",
       %{
         conn: conn
       } do
    tag = "mcp-envelope-avatar-#{System.unique_integer([:positive])}"
    book = create_book!(tag)

    flush_captured_envelopes!()

    session_id = initialize!(conn, "ocel_envelope_avatars_test")

    list_conn =
      build_conn()
      |> put_req_header("mcp-session-id", session_id)
      |> mcp_post(%{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "tools/call",
        "params" => %{"name" => "list_books", "arguments" => %{"input" => %{}}}
      })

    body = json_response(list_conn, 200)
    assert body["result"]["isError"] == false
    [%{"type" => "text", "text" => encoded}] = body["result"]["content"]
    decoded = Jason.decode!(encoded)
    assert Enum.any?(decoded, &(&1["id"] == book.id))

    envelope = assert_receive_envelope_matching!("read")

    # Real envelope shape, asserted directly against Ex4pm.OCEL's real
    # contract -- not a hand-copied expectation.
    assert {:ok, validated} = Ex4pm.OCEL.validate_envelope(envelope)
    assert validated.schema == "xaas.ocel.v2"
    assert is_map(validated.producer)
    assert is_integer(validated.sequence)
    assert [event] = validated.events
    assert String.contains?(event["ocel:activity"], "read")
  end

  # -- Avatar 2 ---------------------------------------------------------------

  test "avatar 2: real A2A checkout message forwards a real OCEL envelope through the same path" do
    tag = "a2a-envelope-avatar-#{System.unique_integer([:positive])}"
    agent_name = :"ocel_envelope_avatars_a2a_#{System.unique_integer([:positive])}"
    {:ok, agent} = XaasWeb.A2A.NextReadUserAgent.start_link(name: agent_name)
    on_exit(fn -> if Process.alive?(agent), do: GenServer.stop(agent) end)

    user = create_granted_user!(tag)
    book = create_book!(tag)

    flush_captured_envelopes!()

    assert {:ok, _task} =
             A2A.call(agent, "as:#{user.id} checkout book:#{book.id} school:willow-creek")

    real_checkout =
      Checkout
      |> Ash.Query.filter(book_id == ^book.id and user_id == ^user.id)
      |> Ash.read_one!(authorize?: false)

    assert real_checkout != nil

    envelope = assert_receive_envelope_matching!("borrow")

    assert {:ok, validated} = Ex4pm.OCEL.validate_envelope(envelope)
    assert validated.schema == "xaas.ocel.v2"
    assert [event] = validated.events
    assert String.contains?(event["ocel:activity"], "borrow")
  end

  # -- Avatar 3 -----------------------------------------------------------

  test "avatar 3: generated OcelEnvelope.build/3 is byte-identical to the hand-written version's output" do
    event = %{
      "ocel:eid" => "regression-eid-1",
      "ocel:activity" => "Book.read",
      "ocel:timestamp" => "2026-09-09T00:00:00Z",
      "ocel:omap" => ["Book"],
      "ocel:vmap" => %{"outcome" => "ok"}
    }

    producer = %{"agent_id" => "xaas", "run_id" => "run-regression"}
    sequence = 99

    # The exact literal shape `do_forward/2` built inline before this pack's
    # generated module existed (see batch-2 report / git history at
    # `lib/xaas/telemetry/ocel_forwarder.ex` pre-`OcelEnvelope.build/3`):
    hand_written_envelope = %{
      "schema" => "xaas.ocel.v2",
      "producer" => producer,
      "sequence" => sequence,
      "events" => [event]
    }

    generated_envelope = OcelEnvelope.build(event, producer, sequence)

    assert generated_envelope == hand_written_envelope

    # Byte-identical, not just structurally-equal: compare both the raw
    # term encoding and the JSON encoding actually POSTed over the wire.
    assert :erlang.term_to_binary(generated_envelope) ==
             :erlang.term_to_binary(hand_written_envelope)

    assert Jason.encode!(generated_envelope) == Jason.encode!(hand_written_envelope)
  end

  # -- Avatar 4 -----------------------------------------------------------

  test "avatar 4: re-running the real generator's admission pipeline twice yields identical desired_hash" do
    plan_opts = [
      pack_dir: "priv/packs/xaas_telemetry_pack",
      template: "priv/packs/xaas_telemetry_pack/templates/ocel_envelope.ex.eex",
      query: "envelope_fields=priv/packs/xaas_telemetry_pack/queries/001_envelope_fields.rq",
      out: "lib/xaas/telemetry/ocel_envelope.ex"
    ]

    assert {:ok, first_run} = GgenIgniter.Reactors.ReconcileReactor.plan(plan_opts)
    assert {:ok, second_run} = GgenIgniter.Reactors.ReconcileReactor.plan(plan_opts)

    assert length(first_run) == length(second_run)
    assert length(first_run) > 0

    first_hashes = Enum.map(first_run, & &1.desired_hash)
    second_hashes = Enum.map(second_run, & &1.desired_hash)

    assert first_hashes == second_hashes
    refute Enum.any?(first_hashes, &is_nil/1)
  end

  # -- Avatar 5 -----------------------------------------------------------

  test "avatar 5: Ex4pm.OCEL.validate_envelope/1 accepts an empty events list and a missing optional previous_digest" do
    envelope_with_empty_events = %{
      "schema" => "xaas.ocel.v2",
      "producer" => %{"agent_id" => "xaas", "run_id" => "run-edge"},
      "sequence" => 0,
      "events" => []
      # "previous_digest" deliberately omitted -- an optional field per
      # Ex4pm.OCEL.validate_envelope/1, defaulted to nil, not required.
    }

    assert {:ok, validated} = Ex4pm.OCEL.validate_envelope(envelope_with_empty_events)
    assert validated.events == []
    assert validated.previous_digest == nil
    assert validated.objects == %{}
    assert validated.object_relationships == []

    # The other real edge: the same envelope shape but with `events` as a
    # map (also accepted -- validate_envelope/1 requires is_list/1 OR
    # is_map/1), still with no previous_digest.
    envelope_with_map_events = Map.put(envelope_with_empty_events, "events", %{})
    assert {:ok, validated_map} = Ex4pm.OCEL.validate_envelope(envelope_with_map_events)
    assert validated_map.events == %{}
  end
end
