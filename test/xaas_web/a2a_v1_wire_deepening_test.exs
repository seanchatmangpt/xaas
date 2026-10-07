defmodule XaasWeb.A2A.V1WireDeepeningTest do
  @moduledoc """
  Lane W699 court: wire-level deepening of the v26.10.6 A2A v1 protocol
  surface (POST /a2a/v1 via `XaasWeb.A2A.V1TransportPlug` ->
  `XaasWeb.A2A.NextReadAshAgent`), layering the endpoint-level EU AI Act
  composition on top of the plug-level courts in
  `test/xaas_web/a2a/v1_protocol_test.exs`. Chicago-style: real endpoint
  pipeline (`XaasWeb.Endpoint` -> `A2AParseFloor` -> `Plug.Parsers` ->
  `SyntheticMarkingPlug` -> `EuAiActAdmissionPlug` -> router ->
  `:require_internal_api_token` -> `V1TransportPlug`), real Plug.Conn,
  real GenServer agent, real decoded JSON-RPC bodies; no mocks.

  Courts:
    1. Malformed JSON-RPC envelope (valid JSON, missing "jsonrpc" member)
       answers the -32600 invalid-request family, and the two -32600
       sources are shape-consistent: the transport's invalid-request
       envelope and the `EuAiActAdmissionPlug` Art. 5 refusal envelope
       share the same JSON-RPC 2.0 wire shape (jsonrpc/id/error.code/
       error.message), differing only in typed `error.data`.
    2. Plug ordering: the W521 admission gate sits at the endpoint,
       BEFORE the router's token floor — an Art. 5 refusal preempts the
       401 even with no bearer token at all; and the W533 marking plug
       (registered before the gate) marks the refusal envelope too
       (header + body field).
    3. Agent-card fetch shape at GET /a2a/v1/.well-known/agent-card.json:
       the required v1 card members on the wire through the wrapper's
       §8.6.1 caching contract.
    4. W533 marking presence on every v1 POST response: success, typed
       -32601 error envelope, and the -32600 refusal envelope all carry
       `x-ai-generated: true` and `"ai_generated": true`.
    5. Bearer gate fail-closed: with INTERNAL_API_TOKEN unset, the v1
       surface answers 503 (misconfigured), not 401 — per the
       `XaasWeb.Plugs.RequireInternalApiToken` fail-closed convention.

  EU AI Act relevance (Art. 14 transparency / Art. 50.1 disclosure
  class): the marked, refusal-typed, discoverable-card wire surface is
  the machine-detectable disclosure layer these tests pin. Evidenced
  lines: `lib/xaas_web/plugs/synthetic_marking_plug.ex` (Art. 50(2)
  marking, W533), `lib/xaas_web/plugs/eu_ai_act_admission_plug.ex`
  (typed Art. 5 refusal envelope), `lib/xaas_web/a2a/v1_transport_plug.ex`
  (§8.6.1 card caching contract).
  """

  use XaasWeb.ConnCase

  # EU AI Act compliance suite tag (Art. 14 transparency / Art. 50.1
  # disclosure class). Runs via `mix test --include eu_ai_act`.
  @moduletag :eu_ai_act

  alias XaasWeb.A2A.NextReadAshAgent

  @card_path "/a2a/v1/.well-known/agent-card.json"
  @rpc_path "/a2a/v1"

  setup do
    # Same idiom as V1ProtocolTest: the v1 agent GenServer is referenced by
    # name in the router mount but not (yet) in Xaas.Supervisor's tree.
    if Process.whereis(NextReadAshAgent) == nil do
      start_supervised!(NextReadAshAgent)
    end

    :ok
  end

  defp token, do: System.fetch_env!("INTERNAL_API_TOKEN")

  defp authed(conn), do: put_req_header(conn, "authorization", "Bearer " <> token())

  defp rpc_conn(method, params, id) do
    build_conn()
    |> put_req_header("content-type", "application/json")
    |> post(@rpc_path, Jason.encode!(%{"jsonrpc" => "2.0", "method" => method, "params" => params, "id" => id}))
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

  # -- (a) malformed envelope + -32600-family consistency ---------------------

  test "1a. valid JSON, missing jsonrpc member -> -32600 invalid request from the transport" do
    conn =
      build_conn()
      |> authed()
      |> put_req_header("content-type", "application/json")
      |> post(@rpc_path, Jason.encode!(%{"method" => "message/send", "id" => "w699-1a"}))

    assert conn.status == 200

    body = json_response(conn, 200)

    assert %{
             "jsonrpc" => "2.0",
             "id" => "w699-1a",
             "error" => %{"code" => -32600, "message" => message}
           } = body

    assert is_binary(message) and message != ""
  end

  test "1b. the two -32600 sources are wire-shape-consistent (transport vs Art. 5 refusal)" do
    # Transport invalid-request envelope.
    invalid_conn =
      build_conn()
      |> authed()
      |> put_req_header("content-type", "application/json")
      |> post(@rpc_path, Jason.encode!(%{"method" => "message/send", "id" => "w699-1b-t"}))

    assert %{"jsonrpc" => "2.0", "id" => "w699-1b-t", "error" => transport_error} =
             json_response(invalid_conn, 200)

    assert transport_error["code"] == -32600

    # Art. 5 admission refusal envelope (same -32600 family, HTTP 200).
    refusal_conn =
      rpc_conn(
        "message/send",
        %{
          "techniques" => ["summarize"],
          "data_domains" => ["social_behavior"],
          "context_joins" => ["unrelated_context_join"]
        },
        "w699-1b-r"
      )

    assert %{"jsonrpc" => "2.0", "id" => "w699-1b-r", "error" => refusal_error} =
             json_response(refusal_conn, 200)

    assert refusal_error["code"] == -32600
    assert refusal_error["data"]["refusal"] == "REFUSED_EUAIA_SOCIAL_SCORING"

    # Consistency: identical envelope keys, identical wire status family.
    assert MapSet.new(Map.keys(transport_error)) == MapSet.new(Map.keys(refusal_error))
    assert invalid_conn.status == refusal_conn.status
  end

  # -- (a)/(b) plug ordering: admission gate preempts the token floor -------

  test "2a. Art. 5 refusal preempts the 401 token floor (endpoint plug before router auth)" do
    # No Authorization header at all. The admission gate halts at the
    # endpoint with the -32600 refusal before the router's token floor
    # could answer 401.
    conn =
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> post(
        @rpc_path,
        Jason.encode!(%{
          "jsonrpc" => "2.0",
          "method" => "message/send",
          "params" => %{"techniques" => ["subliminal"]},
          "id" => "w699-2a"
        })
      )

    assert conn.status == 200

    assert %{
             "jsonrpc" => "2.0",
             "id" => "w699-2a",
             "error" => %{
               "code" => -32600,
               "data" => %{"refusal" => "REFUSED_EUAIA_MANIPULATIVE"}
             }
           } = json_response(conn, 200)
  end

  test "2b. the refusal envelope is marked too (marking plug precedes the admission gate)" do
    conn =
      rpc_conn(
        "message/send",
        %{
          "techniques" => ["summarize"],
          "data_domains" => ["social_behavior"],
          "context_joins" => ["unrelated_context_join"]
        },
        "w699-2b"
      )

    assert conn.status == 200

    assert get_resp_header(conn, "x-ai-generated") == ["true"]

    assert %{
             "ai_generated" => true,
             "error" => %{"code" => -32600, "data" => %{"refusal" => refusal}}
           } = json_response(conn, 200)

    assert refusal =~ "REFUSED_EUAIA_"
  end

  # -- (b) agent card fetch shape ---------------------------------------------

  test "3. agent card fetch shape through the wrapper's §8.6.1 caching contract" do
    conn =
      build_conn()
      |> authed()
      |> get(@card_path)

    assert conn.status == 200

    card = json_response(conn, 200)

    assert is_binary(card["name"]) and card["name"] != ""
    assert is_binary(card["version"]) and card["version"] != ""
    assert is_binary(card["description"])
    assert is_list(card["skills"]) and card["skills"] != []
    assert is_map(card["capabilities"])
    assert is_list(card["defaultInputModes"]) and card["defaultInputModes"] != []
    assert is_list(card["defaultOutputModes"]) and card["defaultOutputModes"] != []

    assert [%{"url" => url, "protocolVersion" => pv} | _] = card["supportedInterfaces"]
    assert is_binary(url) and url =~ "/a2a/v1"
    assert pv in ["1.0", "0.3"]

    # Wrapper contract (§8.6.1): card responses are public, 300s cacheable.
    assert get_resp_header(conn, "cache-control") == ["public, max-age=300"]
    assert get_resp_header(conn, "etag") != []
  end

  # -- (c) marking header presence on v1 responses ----------------------------

  test "4a. success envelope carries the marking header and body field" do
    conn =
      build_conn()
      |> authed()
      |> put_req_header("content-type", "application/json")
      |> post(@rpc_path, Jason.encode!(%{"jsonrpc" => "2.0", "method" => "message/send", "params" => message_send_params("hddl:plan"), "id" => "w699-4a"}))

    assert conn.status == 200

    assert get_resp_header(conn, "x-ai-generated") == ["true"]

    assert %{"ai_generated" => true, "result" => %{"task" => task}} = json_response(conn, 200)
    assert task["status"]["state"] == "TASK_STATE_COMPLETED"
  end

  test "4b. the -32601 error envelope is marked too" do
    conn =
      build_conn()
      |> authed()
      |> put_req_header("content-type", "application/json")
      |> post(@rpc_path, Jason.encode!(%{"jsonrpc" => "2.0", "method" => "definitely/not/a/method", "params" => %{}, "id" => "w699-4b"}))

    assert conn.status == 200

    assert get_resp_header(conn, "x-ai-generated") == ["true"]

    assert %{"ai_generated" => true, "error" => %{"code" => -32601}} = json_response(conn, 200)
  end

  # -- (d) Bearer gate fail-closed (503 family) --------------------------------

  test "5. unset INTERNAL_API_TOKEN fails closed with 503 on the v1 surface" do
    previous = System.get_env("INTERNAL_API_TOKEN")
    System.delete_env("INTERNAL_API_TOKEN")

    ExUnit.Callbacks.on_exit(fn ->
      if previous == nil, do: System.delete_env("INTERNAL_API_TOKEN"),
        else: System.put_env("INTERNAL_API_TOKEN", previous)
    end)

    conn =
      build_conn()
      |> get(@card_path)

    assert conn.status == 503

    assert json_response(conn, 503) == %{
             "error" => "internal_api_misconfigured",
             "detail" => "INTERNAL_API_TOKEN is not set on the server"
           }
  end

  test "5b. unset INTERNAL_API_TOKEN with a wrong bearer token also fails closed with 503" do
    previous = System.get_env("INTERNAL_API_TOKEN")
    System.delete_env("INTERNAL_API_TOKEN")

    ExUnit.Callbacks.on_exit(fn ->
      if previous == nil, do: System.delete_env("INTERNAL_API_TOKEN"),
        else: System.put_env("INTERNAL_API_TOKEN", previous)
    end)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer wrong-token")
      |> get(@card_path)

    assert conn.status == 503

    assert json_response(conn, 503) == %{
             "error" => "internal_api_misconfigured",
             "detail" => "INTERNAL_API_TOKEN is not set on the server"
           }
  end
end
