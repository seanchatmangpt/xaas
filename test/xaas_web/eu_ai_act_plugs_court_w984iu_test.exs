defmodule XaasWeb.EuAiActPlugsCourtW984IUTest do
  @moduledoc """
  W984iu unclaimed-family probe: branch census of
  `XaasWeb.Plugs.EuAiActAdmissionPlug` (W521) and
  `XaasWeb.Plugs.SyntheticMarkingPlug` (W533) against the existing W521
  (eu_ai_act_admission_integration_test), W533 (synthetic_marking_test) and
  W703 (plug_mount_order_court_test) courts, then courts the genuinely
  unexercised state-bearing branches. Chicago-style: real plug modules over
  real conn construction (the endpoint-mounted path is already exercised by
  the W521/W533/W703 courts), no mocks.

  Dispositions (branch -> status):
    admission plug:
      POST /a2a map body + map params -> pass-through .... COVERED (W521 t1)
      admit {:error, refusal} -> JSON-RPC refusal envelope . COVERED (W521 t2/t3)
      body_params non-map -> else pass-through ............ COVERED here (t2)
      body_params map without "params" .................... COVERED (W521 t4)
      non-POST / non-/a2a pass-through .................... COVERED (W521 t4)
      request_id string-key "id" .......................... COVERED (W521 t2)
      request_id atom-key %{id: id} ....................... COVERED here (t3)
      request_id missing -> nil envelope id ............... COVERED here (t4)
      normalize non-binary key passthrough ................ COVERED here (t5)
    marking plug:
      POST /a2a and /mcp marking .......................... COVERED (W533 t1/t2)
      refusal envelope marked ............................. COVERED (W533 t3, W703)
      non-AI / GET pass-through ........................... COVERED (W533 t4/t5)
      non-JSON body on marked surface: header only ........ COVERED here (t6)
      empty body on marked surface ........................ COVERED here (t7)
  """

  use XaasWeb.ConnCase

  alias Plug.Test
  alias XaasWeb.Plugs.{EuAiActAdmissionPlug, SyntheticMarkingPlug}

  describe "EuAiActAdmissionPlug unexercised branches" do
    test "t2: non-map body_params on POST /a2a passes through untouched",
         _conn do
      # Mutation rationale: if the first `with` clause admitted non-map
      # body_params into normalize/admit, a non-JSON-RPC body would crash
      # Map.get/2 or mint atoms; this pins the else-arm pass-through.
      conn =
        Test.conn(:post, "/a2a/v1")
        |> Map.replace!(:body_params, "raw non-map body")
        |> EuAiActAdmissionPlug.call([])

      refute conn.halted
      refute conn.status
    end

    test "t3: atom-keyed %{id: id} in body_params supplies the envelope id",
         _conn do
      # Mutation rationale: deleting the %{id: id} clause of request_id/1
      # must fail this test — atom-keyed JSON-RPC bodies (e.g. already-
      # atomized internal dispatch) lose their request id in the envelope.
      conn =
        Test.conn(:post, "/a2a/v1")
        |> Map.replace!(:body_params, %{
          "params" => %{"techniques" => ["subliminal"], "note" => "atom id"},
          id: "w984iu-atom"
        })
        |> EuAiActAdmissionPlug.call([])

      assert conn.halted
      assert %{"id" => "w984iu-atom", "error" => %{"data" => %{"refusal" => refusal}}} =
               Jason.decode!(conn.resp_body)

      assert refusal =~ "REFUSED_EUAIA"
    end

    test "t4: refusal with no id ships a nil envelope id",
         _conn do
      # Mutation rationale: the `_ -> nil` clause of request_id/1. If it
      # raised instead of defaulting to nil, a malformed body with a
      # prohibited shape would 500 the surface instead of refusing.
      conn =
        Test.conn(:post, "/a2a/v1")
        |> Map.replace!(:body_params, %{
          "params" => %{"techniques" => ["subliminal"], "note" => "no id"}
        })
        |> EuAiActAdmissionPlug.call([])

      assert conn.halted
      assert %{"id" => nil, "error" => %{"code" => -32600}} = Jason.decode!(conn.resp_body)
    end

    test "t5: normalize keeps non-binary-keyed pairs untouched (values un-atomized)",
         _conn do
      # Mutation rationale: the {k, v} non-binary-key clause of normalize/1.
      # An atom-keyed params map (internal callers) must not crash the gate.
      # Observed real behavior pinned here: the atom-keyed pair passes
      # through with its string value UN-atomized, so admit/1's atom
      # vocabulary does not match it and the gate does NOT refuse — value
      # atomization is coupled to the binary-key clause. If that coupling
      # breaks (values atomized for non-binary keys too), this test flips
      # to a refusal and the drift is witnessed.
      conn =
        Test.conn(:post, "/a2a/v1")
        |> Map.replace!(:body_params, %{
          "params" => Map.new([{:techniques, ["subliminal"]}, {"note", "atom keys"}])
        })
        |> EuAiActAdmissionPlug.call([])

      refute conn.halted
    end
  end

  describe "SyntheticMarkingPlug unexercised branches" do
    test "t6: non-JSON body on a marked surface gets the header, no body injection",
         _conn do
      # Mutation rationale: the `_ -> conn` clause of mark_json_body/1 when
      # Jason.decode fails. If the injection blindly Map.put a binary, the
      # SSE/binary surface would corrupt frames; pins header-only marking.
      conn =
        Test.conn(:post, "/a2a/v1")
        |> SyntheticMarkingPlug.call([])

      conn =
        Plug.Conn.send_resp(conn, 200, "not json at all")

      assert {"x-ai-generated", "true"} in conn.resp_headers
      assert conn.resp_body == "not json at all"
    end

    test "t7: empty body on a marked surface gets the header only",
         _conn do
      # Mutation rationale: the `body != "" and body != nil` guard of
      # mark_json_body/1. Deleting the guard would iodata_to_binary(nil)
      # crash the send on empty responses.
      conn =
        Test.conn(:post, "/mcp")
        |> SyntheticMarkingPlug.call([])

      conn = Plug.Conn.send_resp(conn, 204, "")

      assert {"x-ai-generated", "true"} in conn.resp_headers
      assert conn.resp_body == ""
    end
  end
end
