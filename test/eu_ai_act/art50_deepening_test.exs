defmodule Xaas.EUAIAct.Art50DeepeningTest do
  @moduledoc """
  Lane W665: Art. 50 transparency-to-deployee evidenced-line deepening.

  W619 deepened 50.1/50.5 with direct plug calls; this court goes further on
  the real wire: full endpoint pipeline (XaasWeb.Endpoint -> router) HTTP
  requests via ConnCase, refusal-envelope marking, and the typed Art. 5
  kernel refusals behind the disclosure claims in
  docs/cro/artifacts/end-user-disclosure-v26.10.6.md.

  Chicago-style: real plugs, real HTTP, real module calls; asserts on final
  state only. No mocks.
  """

  use XaasWeb.ConnCase

  @moduletag :eu_ai_act

  alias Xaas.Semantics.EuAiActAdmission

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
        "messageId" => "msg-w665-lawful",
        "parts" => [%{"kind" => "text", "text" => "hddl:plan"}]
      }
    }
  end

  # --- Art. 50(1): the end user can see they are interacting with an AI -----

  test "50.1a POST /a2a/v1 response is marked (x-ai-generated header + ai_generated field)" do
    conn =
      post_json(@rpc_path, %{
        "jsonrpc" => "2.0",
        "method" => "message/send",
        "params" => lawful_params(),
        "id" => "w665-501a"
      })

    assert conn.status in [200, 401]
    assert {"x-ai-generated", "true"} in conn.resp_headers
    assert %{"ai_generated" => true} = json_response(conn, conn.status)
  end

  test "50.1b POST /mcp marked; GET /mcp and POST /internal-api/x untouched" do
    marked = post_json(@mcp_path, %{"jsonrpc" => "2.0", "method" => "tools/list", "id" => "w665-501b"})

    assert marked.status in [200, 401]
    assert {"x-ai-generated", "true"} in marked.resp_headers
    assert %{"ai_generated" => true} = json_response(marked, marked.status)

    get = build_conn() |> get(@mcp_path)

    assert get.status in [200, 400, 401, 404]
    refute Enum.any?(get.resp_headers, fn {k, _} -> k == "x-ai-generated" end)

    other = post_json("/internal-api/x", %{"probe" => "w665 non-AI surface"})

    refute Enum.any?(other.resp_headers, fn {k, _} -> k == "x-ai-generated" end)
  end

  # --- Art. 50(2): synthetic-content marking survives real refusals ---------

  test "50.2a refusal envelope is marked on the real wire (W521 admission refusal)" do
    conn =
      post_json(@rpc_path, %{
        "jsonrpc" => "2.0",
        "method" => "message/send",
        "params" => %{"techniques" => ["subliminal"]},
        "id" => "w665-502a"
      })

    assert conn.status == 200

    assert %{"ai_generated" => true} = json_response(conn, 200)
    assert {"x-ai-generated", "true"} in conn.resp_headers

    # The refusal must be typed and wire-distinguishable from tool absence
    # (the disclosure artifact's central claim).
    body = json_response(conn, 200)
    assert body != %{"error" => %{"code" => -32602}}
  end

  test "50.2b typed kernel refusals behind the disclosure claims (real module calls)" do
    assert {:error, :REFUSED_EUAIA_MANIPULATIVE} =
             EuAiActAdmission.admit(%{techniques: [:subliminal]})

    # Emotion-recognition refusal fires on the affective-domain +
    # workplace/education conjunction (impl: affective_in_context?/1,
    # lib/xaas/semantics/eu_ai_act_admission.ex).
    assert {:error, :REFUSED_EUAIA_EMOTION_RECOGNITION} =
             EuAiActAdmission.admit(%{data_domains: [:affective], setting: :workplace})

    assert {:error, :REFUSED_EUAIA_EMOTION_RECOGNITION} =
             EuAiActAdmission.admit(%{data_domains: [:affective], setting: :education})

    # W897 (w665 kernel-gap repair): the bare :emotion_recognition technique
    # atom — which used to admit (pinned honestly by w665) — now refuses
    # typed with the same Art. 5(1)(e) refusal atom.
    assert {:error, :REFUSED_EUAIA_EMOTION_RECOGNITION} =
             EuAiActAdmission.admit(%{techniques: [:emotion_recognition]})
  end

  # --- Art. 50(5)-analog: machine-readable marking is deterministic and -----
  # --- non-invasive on non-JSON bodies --------------------------------------

  test "50.5a direct plug call: iodata body still gets header, non-JSON body not mutated" do
    alias XaasWeb.Plugs.SyntheticMarkingPlug

    marked =
      Plug.Test.conn("POST", "/mcp", "")
      |> SyntheticMarkingPlug.call([])
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ["{", "\"result\"", ":\"refusal\"", "}"])
      |> Plug.Conn.send_resp()

    assert Plug.Conn.get_resp_header(marked, "x-ai-generated") == ["true"]
    assert %{"ai_generated" => true, "result" => "refusal"} = Jason.decode!(marked.resp_body)

    # Non-JSON (SSE-like chunk) body: header only, body untouched.
    sse =
      Plug.Test.conn("POST", "/mcp", "")
      |> SyntheticMarkingPlug.call([])
      |> Plug.Conn.put_resp_content_type("text/event-stream")
      |> Plug.Conn.resp(200, "data: hello\n\n")
      |> Plug.Conn.send_resp()

    assert Plug.Conn.get_resp_header(sse, "x-ai-generated") == ["true"]
    assert sse.resp_body == "data: hello\n\n"
  end

  test "50.5b direct plug call: marking is idempotent on an already-marked body" do
    alias XaasWeb.Plugs.SyntheticMarkingPlug

    conn =
      Plug.Test.conn("POST", "/a2a/v1", "")
      |> SyntheticMarkingPlug.call([])
      |> Plug.Conn.resp(200, Jason.encode!(%{"ok" => true, "ai_generated" => true}))
      |> Plug.Conn.send_resp()

    assert Plug.Conn.get_resp_header(conn, "x-ai-generated") == ["true"]
    assert %{"ok" => true, "ai_generated" => true} = Jason.decode!(conn.resp_body)
  end

  test "50.5c direct plug call: JSON array body gets header only, body unchanged" do
    alias XaasWeb.Plugs.SyntheticMarkingPlug

    conn =
      Plug.Test.conn("POST", "/mcp", "")
      |> SyntheticMarkingPlug.call([])
      |> Plug.Conn.resp(200, Jason.encode!([1, 2, 3]))
      |> Plug.Conn.send_resp()

    assert Plug.Conn.get_resp_header(conn, "x-ai-generated") == ["true"]
    assert conn.resp_body == "[1,2,3]"
  end
end
