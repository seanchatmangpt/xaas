defmodule XaasWeb.PlugMountOrderCourtTest do
  @moduledoc """
  W703 court: `XaasWeb.Plugs.SyntheticMarkingPlug` must be registered in
  `XaasWeb.Endpoint` BEFORE `XaasWeb.Plugs.EuAiActAdmissionPlug`
  (evidenced line: lib/xaas_web/endpoint.ex:99-100, per W533's documented
  seam; Art. 50 marking disclosure — Regulation (EU) 2024/1689,
  Art. 50(2): synthetic content must be machine-detectably marked).

  The composition is ORDER-SENSITIVE. `EuAiActAdmissionPlug` halts the
  conn on refusal; Plug.Builder skips remaining plugs once halted. If the
  plugs were reordered (admission before marking), an Art. 5 refusal would
  halt BEFORE the marking plug registers its `register_before_send`
  callback, and the refusal envelope would ship UNMARKED — an Art. 50(2)
  disclosure failure on the exact responses that refuse.

  ## The reorder-killing observable

  An Art-5-refused POST /a2a response whose envelope is UNMARKED (no
  `x-ai-generated: true` header, no top-level `"ai_generated": true`)
  kills the reorder mutation. This court asserts the marked variant on a
  real endpoint-stack request.

  Chicago-style: real `XaasWeb.Endpoint` pipeline, real JSON-RPC bodies,
  no mocks.
  """

  use XaasWeb.ConnCase

  alias Plug.Test

  @moduletag :eu_ai_act

  @rpc_path "/a2a/v1"

  defp post_json(path, body) do
    build_conn()
    |> put_req_header("content-type", "application/json")
    |> post(path, Jason.encode!(body))
  end

  defp refused_marked_conn do
    post_json(@rpc_path, %{
      "jsonrpc" => "2.0",
      "method" => "message/send",
      "params" => %{
        "techniques" => ["subliminal"],
        "note" => "w703 plug-order probe"
      },
      "id" => "w703-1"
    })
  end

  @tag :eu_ai_act
  test "a. Art-5-refused /a2a POST is BOTH refusal-enveloped AND marked" do
    conn = refused_marked_conn()

    # Refusal envelope (W521 admission gate answered, halted there).
    assert conn.status == 200

    assert %{
             "jsonrpc" => "2.0",
             "id" => "w703-1",
             "error" => %{
               "code" => -32600,
               "data" => %{"refusal" => "REFUSED_EUAIA_MANIPULATIVE"}
             }
           } = json_response(conn, 200)

    # AND marked (W533 marking ran first, so its before_send still fires
    # on the halted send).
    assert {"x-ai-generated", "true"} in conn.resp_headers

    assert %{"ai_generated" => true, "error" => %{"code" => -32600}} =
             json_response(conn, 200)
  end

  @tag :eu_ai_act
  test "b. marked-but-admitted path stays marked" do
    conn =
      post_json(@rpc_path, %{
        "jsonrpc" => "2.0",
        "method" => "message/send",
        "params" => %{
          "message" => %{
            "role" => "ROLE_USER",
            "messageId" => "msg-w703-lawful",
            "parts" => [%{"kind" => "text", "text" => "hddl:plan"}]
          }
        },
        "id" => "w703-2"
      })

    # The gate did NOT halt (request reached the token floor).
    assert conn.status == 401
    assert %{"error" => "unauthorized"} = json_response(conn, 401)

    # Marking still applied on the admitted path.
    assert {"x-ai-generated", "true"} in conn.resp_headers
    assert %{"ai_generated" => true} = json_response(conn, 401)
  end

  @tag :eu_ai_act
  test "c. reorder mutation observable: refusal+marking composition holds" do
    # The reorder mutation (admission plug registered first) would make
    # THIS request ship unmarked: the refusal halts the conn before the
    # marking plug ever runs, so no before_send callback is registered and
    # the envelope leaves the endpoint without the Art. 50(2) markings.
    #
    # This test therefore pins BOTH halves of the order-sensitive
    # observable on the same real request:
    #   - refusal present (gate answered), AND
    #   - marking present (marking registered before the gate ran).
    # If either half fails, the composition order is wrong.
    conn = refused_marked_conn()

    assert %{"error" => %{"data" => %{"refusal" => refusal}}} = json_response(conn, 200)
    assert refusal =~ "REFUSED_EUAIA"

    marked_header? = {"x-ai-generated", "true"} in conn.resp_headers
    marked_body? = %{"ai_generated" => true} = json_response(conn, 200)

    assert marked_header?, """
    REORDER KILL: /a2a Art-5 refusal envelope shipped UNMARKED
    (no x-ai-generated header). SyntheticMarkingPlug is no longer
    registered BEFORE EuAiActAdmissionPlug in lib/xaas_web/endpoint.ex
    (evidenced lines 99-100) — Art. 50(2) disclosure failure on refusals.
    """

    assert marked_body?, """
    REORDER KILL: /a2a Art-5 refusal envelope shipped UNMARKED
    (no ai_generated body field). SyntheticMarkingPlug is no longer
    registered BEFORE EuAiActAdmissionPlug in lib/xaas_web/endpoint.ex
    (evidenced lines 99-100) — Art. 50(2) disclosure failure on refusals.
    """
  end

  @tag :eu_ai_act
  test "d. reorder mutation witnessed: admission-first ships the refusal UNMARKED" do
    # Direct execution of the REORDERED composition (admission plug first,
    # marking plug second) over the same real plug modules — no endpoint
    # edit, no mocks. The refusal halts in EuAiActAdmissionPlug, so
    # SyntheticMarkingPlug never runs, no before_send is registered, and
    # the send produces an unmarked envelope. This is the exact observable
    # that kills the reorder; test (c) pins the live endpoint to the
    # correct (marked) side of it.
    params = %{
      "jsonrpc" => "2.0",
      "method" => "message/send",
      "params" => %{"techniques" => ["subliminal"], "note" => "w703 reorder witness"},
      "id" => "w703-4"
    }

    alias XaasWeb.Plugs.{EuAiActAdmissionPlug, SyntheticMarkingPlug}

    halted =
      Test.conn(:post, @rpc_path)
      |> Plug.Conn.put_req_header("content-type", "application/json")
      |> Map.replace!(:body_params, Jason.decode!(Jason.encode!(params)))
      |> EuAiActAdmissionPlug.call([])

    # The gate refused and halted BEFORE the marking plug ran (reorder).
    assert halted.halted
    assert halted.status == 200
    assert %{"error" => %{"data" => %{"refusal" => "REFUSED_EUAIA_MANIPULATIVE"}}} =
             Jason.decode!(halted.resp_body)

    # The reordered send: no header, no body field.
    refute {"x-ai-generated", "true"} in halted.resp_headers
    refute Jason.decode!(halted.resp_body)["ai_generated"]
  end
end
