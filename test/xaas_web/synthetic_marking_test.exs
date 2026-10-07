defmodule XaasWeb.SyntheticMarkingTest do
  @moduledoc """
  W533 court: EU AI Act Art. 50(2) synthetic-content marking is live on the
  real AI surfaces. Chicago-style — real endpoint pipeline
  (`XaasWeb.Endpoint` -> router), real JSON bodies, no mocks.

  Courts:
    1. POST /a2a response carries `x-ai-generated: true` header plus
       `"ai_generated": true` in the JSON body.
    2. POST /mcp response carries both markings.
    3. Refusal envelopes are marked too (the 401 token-floor refusal is the
       cheapest real refusal on these surfaces; the W521 Art. 5 admission
       refusal envelope is marked as well).
    4. Non-AI surfaces are untouched (no header, no injected field).
    5. Plug-level pass-through: GETs and non-AI paths are unmarked.
  """

  use XaasWeb.ConnCase

  alias Plug.Test
  alias XaasWeb.Plugs.SyntheticMarkingPlug

  @rpc_path "/a2a/v1"
  @mcp_path "/mcp"

  defp post_json(path, body) do
    build_conn()
    |> put_req_header("content-type", "application/json")
    |> post(path, Jason.encode!(body))
  end

  defp lawful_params do
    %{
      "message" => %{
        "role" => "ROLE_USER",
        "messageId" => "msg-w533-lawful",
        "parts" => [%{"kind" => "text", "text" => "hddl:plan"}]
      }
    }
  end

  test "1. POST /a2a response is marked (header + JSON field)" do
    conn =
      post_json(@rpc_path, %{
        "jsonrpc" => "2.0",
        "method" => "message/send",
        "params" => lawful_params(),
        "id" => "w533-1"
      })

    # Response arrived from the real surface (401 token floor — the auth
    # floor is not this court's subject; marking must be on it regardless).
    assert conn.status in [200, 401]

    assert {"x-ai-generated", "true"} in conn.resp_headers
    assert %{"ai_generated" => true} = json_response(conn, conn.status)
  end

  test "2. POST /mcp response is marked (header + JSON body field)" do
    conn = post_json(@mcp_path, %{"jsonrpc" => "2.0", "method" => "tools/list", "id" => "w533-2"})

    assert conn.status in [200, 401]
    assert {"x-ai-generated", "true"} in conn.resp_headers
    assert %{"ai_generated" => true} = json_response(conn, conn.status)
  end

  test "3. refusal envelopes are marked too (W521 Art. 5 admission refusal)" do
    conn =
      post_json(@rpc_path, %{
        "jsonrpc" => "2.0",
        "method" => "message/send",
        "params" => %{
          "techniques" => ["subliminal"],
          "note" => "w533 refusal marking probe"
        },
        "id" => "w533-3"
      })

    assert conn.status == 200

    assert %{"error" => %{"code" => -32600, "data" => %{"refusal" => refusal}}} =
             json_response(conn, 200)

    assert refusal =~ "REFUSED_EUAIA"
    assert {"x-ai-generated", "true"} in conn.resp_headers
    assert %{"ai_generated" => true, "error" => %{"code" => -32600}} =
             json_response(conn, 200)
  end

  test "4. non-AI surfaces are untouched" do
    # /internal-api token-floor refusal carries no marking.
    conn = post_json("/internal-api/anything", %{"ping" => 1})

    assert conn.status == 401
    refute {"x-ai-generated", "true"} in conn.resp_headers

    refute json_response(conn, 401)["ai_generated"]
  end

  test "5. plug-level pass-through: GETs and non-AI paths are unmarked" do
    conn =
      Test.conn(:get, "/a2a/v1/.well-known/agent-card.json")
      |> SyntheticMarkingPlug.call([])

    refute conn.halted

    conn =
      Test.conn(:post, "/some/other/path")
      |> SyntheticMarkingPlug.call([])

    # No before_send registered for non-AI paths: simulate send.
    conn = Plug.Conn.send_resp(conn, 200, "{}")
    refute {"x-ai-generated", "true"} in conn.resp_headers
    refute Jason.decode!(conn.resp_body)["ai_generated"]
  end
end
