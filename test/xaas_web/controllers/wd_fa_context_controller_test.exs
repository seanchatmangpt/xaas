defmodule XaasWeb.WdFaContextControllerTest do
  use XaasWeb.ConnCase, async: true

  test "GET context endpoint exposes reconstructable semantic envelope", %{conn: conn} do
    conn =
      get(
        conn,
        ~p"/case-studies/wd-fa/context/partial_firmware.json?viewpoint=fa-engineer"
      )

    body = json_response(conn, 200)
    assert body["case_id"] == "partial_firmware"
    assert body["classification"] == "PARTIAL"
    assert body["work_standing"] == "BLOCKED_ON_EVIDENCE"
    assert body["authority_ceiling"] == "SELECT_CONSTRUCT_ONLY"
  end

  test "GET learned novel context carries replay identity", %{conn: conn} do
    conn =
      get(
        conn,
        ~p"/case-studies/wd-fa/context/novel_x.json?viewpoint=assessment&learned=true"
      )

    body = json_response(conn, 200)
    assert body["classification"] == "KNOWN"
    assert body["replay_identity"] == "NOVEL-X-REPLAY"
  end

  test "unknown case is refused", %{conn: conn} do
    conn = get(conn, ~p"/case-studies/wd-fa/context/missing-case.json")
    body = json_response(conn, 404)

    assert body["standing"] == "REFUSED"
    assert body["reason"] == "unknown_case"
  end
end
