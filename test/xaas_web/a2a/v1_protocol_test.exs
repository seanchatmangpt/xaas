defmodule XaasWeb.A2A.V1ProtocolTest do
  @moduledoc """
  Integration lane W109 court for the v26.10.6 AshA2A v1 protocol surface:
  real router dispatch through the real `/a2a` scope (`:api` + `:require_internal_api_token`
  pipelines) into `AshA2A.Protocol.Plug` -> `XaasWeb.A2A.NextReadAshAgent` ->
  `XaasWeb.A2A.NextReadUserAgent.handle_message/2`
  (the shared hex-agent skill dispatch). Chicago-style: real Plug.Conn, real
  GenServer agent, real decoded JSON-RPC bodies; no mocks, no string-scraped
  HTTP asserts — structural JSON asserts only.

  Court cases:
    1. Agent card discovery: GET /a2a/v1/.well-known/agent-card.json -> 200 with
       the required v1 card members (name/description/version/skills/capabilities/
       defaultInputModes/defaultOutputModes/supportedInterfaces).
    2. message/send with a skill the agent actually supports ("hddl:plan",
       XaasWeb.A2A.NextReadUserAgentSkills' hddl-plan skill) -> JSON-RPC 2.0 success
       with a completed task whose history carries the agent's reply.
    3. Unknown method -> typed JSON-RPC error -32601 (method not found).
    4. Malformed JSON body -> typed JSON-RPC error -32700 (parse error).
    5. No bearer token -> 401 at the :require_internal_api_token floor (fail-closed),
       before the A2A plug is ever reached.
  """

  use XaasWeb.ConnCase

  alias XaasWeb.A2A.NextReadAshAgent

  @card_path "/a2a/v1/.well-known/agent-card.json"
  @rpc_path "/a2a/v1"

  setup do
    # The v1 agent GenServer is referenced by name in the router mount but is
    # not (yet) in Xaas.Supervisor's tree; start it for the court. If a future
    # tree adds it, whereis wins and start_supervised! is skipped.
    if Process.whereis(NextReadAshAgent) == nil do
      start_supervised!(NextReadAshAgent)
    end

    :ok
  end

  defp token do
    System.fetch_env!("INTERNAL_API_TOKEN")
  end

  defp authed(conn), do: put_req_header(conn, "authorization", "Bearer " <> token())

  defp rpc_body(method, params, id) do
    Jason.encode!(%{"jsonrpc" => "2.0", "method" => method, "params" => params, "id" => id})
  end

  defp message_send_params(text) do
    %{
      "message" => %{
        "role" => "ROLE_USER",
        "messageId" => AshA2A.Protocol.ID.generate("msg"),
        "parts" => [%{"kind" => "text", "text" => text}]
      }
    }
  end

  test "1. agent card discovery returns 200 with the required v1 card members" do
    conn =
      build_conn()
      |> authed()
      |> get(@card_path)

    assert conn.status == 200

    card = json_response(conn, 200)

    assert is_binary(card["name"]) and card["name"] != ""
    assert is_binary(card["description"])
    assert is_binary(card["version"]) and card["version"] != ""
    assert is_list(card["skills"]) and card["skills"] != []

    Enum.each(card["skills"], fn skill ->
      assert is_binary(skill["id"]) and skill["id"] != ""
      assert is_binary(skill["name"]) and skill["name"] != ""
      assert is_binary(skill["description"])
      assert is_list(skill["tags"])
    end)

    assert is_map(card["capabilities"])
    assert card["defaultInputModes"] |> is_list() |> then(&(&1 != []))
    assert card["defaultOutputModes"] |> is_list() |> then(&(&1 != []))

    assert [%{"url" => url, "protocolVersion" => pv} | _] = card["supportedInterfaces"]
    assert is_binary(url) and url != ""
    assert pv in ["1.0", "0.3"]

    # Machine-readable cache contract from the plug
    assert get_resp_header(conn, "etag") != []
    assert get_resp_header(conn, "cache-control") == ["public, max-age=300"]
  end

  test "2. message/send hddl:plan returns a completed task with the agent reply in history" do
    conn =
      build_conn()
      |> authed()
      |> put_req_header("content-type", "application/json")
      |> post(@rpc_path, rpc_body("message/send", message_send_params("hddl:plan"), "w109-2"))

    assert conn.status == 200

    body = json_response(conn, 200)
    assert body["jsonrpc"] == "2.0"
    assert body["id"] == "w109-2"

    # v1.0 send-result: the reply is wrapped under "task" (or "message" when
    # the agent answers without a task). {:reply, parts} from the hex dispatch
    # produces a completed task whose history carries the agent Message.
    assert %{"result" => %{"task" => task}} = body

    assert is_binary(task["id"]) and task["id"] != ""
    assert is_binary(task["contextId"])
    assert task["status"]["state"] == "TASK_STATE_COMPLETED"

    assert [%{"role" => "ROLE_AGENT", "parts" => parts} | _] =
             Enum.reverse(task["history"])

    text =
      parts
      |> Enum.filter(&is_binary(&1["text"]))
      |> Enum.map_join("", & &1["text"])

    assert text =~ "HDDL Domain: next-read"
    assert text =~ "NEXT-READ-DUAL-PERSONA-EXPERIENCE"
  end

  test "3. unknown method returns typed -32601 method-not-found" do
    conn =
      build_conn()
      |> authed()
      |> put_req_header("content-type", "application/json")
      |> post(@rpc_path, rpc_body("definitely/not/a/method", %{}, "w109-3"))

    assert conn.status == 200

    body = json_response(conn, 200)

    assert %{
             "jsonrpc" => "2.0",
             "id" => "w109-3",
             "error" => %{"code" => -32601, "message" => message}
           } = body

    assert is_binary(message) and message != ""
  end

  test "4. malformed JSON body returns typed -32700 parse error" do
    # text/plain keeps body_params unfetched so the A2A plug reads the raw body
    # and Jason is the one to reject it (Plug.Parsers never sees JSON).
    conn =
      build_conn()
      |> authed()
      |> put_req_header("content-type", "text/plain")
      |> post(@rpc_path, "this is { not json")

    assert conn.status == 200

    body = json_response(conn, 200)

    assert %{
             "jsonrpc" => "2.0",
             "error" => %{"code" => -32700, "message" => message}
           } = body

    assert is_binary(message) and message != ""
  end

  test "4b. malformed application/json body also answers -32700 (W150 parse floor)" do
    # Regression court for W113 finding 2: with the real endpoint parsers,
    # application/json used to die in Plug.Parsers.ParseError (bare 400)
    # before the A2A plug's raw-body branch could answer -32700. The
    # XaasWeb.Plugs.A2AParseFloor endpoint plug now decodes first.
    conn =
      build_conn()
      |> authed()
      |> put_req_header("content-type", "application/json")
      |> post(@rpc_path, "this is { not json")

    assert conn.status == 200

    body = json_response(conn, 200)

    assert %{
             "jsonrpc" => "2.0",
             "id" => nil,
             "error" => %{"code" => -32700, "message" => message}
           } = body

    assert is_binary(message) and message != ""
  end

  test "5. no bearer token fails closed with 401 at the token floor" do
    conn =
      build_conn()
      |> get(@card_path)

    assert conn.status == 401

    assert %{"error" => "unauthorized"} = json_response(conn, 401)
  end
end
