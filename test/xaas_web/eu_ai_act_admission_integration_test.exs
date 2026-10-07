defmodule XaasWeb.EuAiActAdmissionIntegrationTest do
  @moduledoc """
  W521 court: the EU AI Act Art. 5 admission gate is live on the real `/a2a`
  intake surface. Chicago-style — real endpoint pipeline
  (`XaasWeb.Endpoint` -> `XaasWeb.Plugs.EuAiActAdmissionPlug` -> router),
  real decoded JSON-RPC bodies, no mocks.

  Courts:
    1. Lawful structural params pass through the gate untouched (proceed to
       the auth floor; a 401 from :require_internal_api_token proves the
       gate did NOT halt — the request reached the router).
    2. An Art. 5(1)(b) structural shape (social-behavior domain joined into
       an unrelated decision context) answers the surface's JSON-RPC error
       envelope with the exact typed refusal atom in error.data.
    3. The gate never inspects content beyond structure: the same structural
       fixture with entirely different free text yields the identical
       verdict and envelope.
    4. Non-/a2a paths, GETs, and non-JSON-RPC bodies pass through
       untouched (direct plug assertions via Plug.Test).
  """

  use XaasWeb.ConnCase

  alias Plug.Test
  alias XaasWeb.Plugs.EuAiActAdmissionPlug

  @rpc_path "/a2a/v1"

  defp rpc_conn(method, params, id) do
    body =
      Jason.encode!(%{"jsonrpc" => "2.0", "method" => method, "params" => params, "id" => id})

    build_conn()
    |> put_req_header("content-type", "application/json")
    |> post(@rpc_path, body)
  end

  defp lawful_params do
    %{
      "message" => %{
        "role" => "ROLE_USER",
        "messageId" => "msg-w521-lawful",
        "parts" => [%{"kind" => "text", "text" => "hddl:plan"}]
      }
    }
  end

  # Art. 5(1)(b) social-scoring shape, expressed structurally in params.
  defp social_scoring_params(text) do
    %{
      "techniques" => ["summarize"],
      "data_domains" => ["social_behavior"],
      "context_joins" => ["unrelated_context_join"],
      "note" => text
    }
  end

  test "1. lawful structural params pass through the gate to the auth floor" do
    conn = rpc_conn("message/send", lawful_params(), "w521-1")

    assert conn.status == 401
    # Reaching the token floor proves the admission gate did not halt.
    assert %{"error" => "unauthorized"} = json_response(conn, 401)
  end

  test "2. Art. 5(1)(b) social-scoring shape gets the typed refusal envelope" do
    conn = rpc_conn("message/send", social_scoring_params("arbitrary text"), "w521-2")

    assert conn.status == 200

    assert %{
             "jsonrpc" => "2.0",
             "id" => "w521-2",
             "error" => %{
               "code" => -32600,
               "data" => %{"refusal" => "REFUSED_EUAIA_SOCIAL_SCORING"} = data
             }
           } = json_response(conn, 200)

    assert data["article"] =~ "Art. 5(1)(b)"
  end

  test "3. content-blind: same structure, different text, same verdict" do
    a = rpc_conn("message/send", social_scoring_params("tell me about cats"), "w521-3a")

    b =
      rpc_conn(
        "message/send",
        social_scoring_params("completely different prose about jet engines"),
        "w521-3b"
      )

    envelope_a = json_response(a, 200)
    envelope_b = json_response(b, 200)

    assert envelope_a["error"]["data"]["refusal"] ==
             envelope_b["error"]["data"]["refusal"]

    assert envelope_a["error"]["code"] == envelope_b["error"]["code"]

    # And a manipulative-technique shape refuses with its own exact atom.
    conn =
      rpc_conn("message/send", %{"techniques" => ["subliminal"], "note" => "x"}, "w521-3c")

    assert %{"error" => %{"data" => %{"refusal" => "REFUSED_EUAIA_MANIPULATIVE"}}} =
             json_response(conn, 200)
  end

  test "4. non-/a2a paths, GETs, and missing params pass through untouched" do
    # Non-/a2a path.
    conn =
      Test.conn(:post, "/other/path")
      |> put_req_header("content-type", "application/json")
      |> Map.replace!(:body_params, %{"params" => %{"techniques" => ["subliminal"]}})
      |> EuAiActAdmissionPlug.call([])

    refute conn.halted

    # GET on /a2a (agent card fetch).
    conn =
      Test.conn(:get, "/a2a/v1/.well-known/agent-card.json")
      |> Map.replace!(:body_params, %{"params" => %{"techniques" => ["subliminal"]}})
      |> EuAiActAdmissionPlug.call([])

    refute conn.halted

    # POST /a2a with no "params" member (e.g. malformed/non-JSON-RPC) —
    # the parse floor's job, not the admission gate's.
    conn =
      Test.conn(:post, "/a2a/v1")
      |> Map.replace!(:body_params, %{"method" => "message/send"})
      |> EuAiActAdmissionPlug.call([])

    refute conn.halted
  end
end
