defmodule XaasWeb.WdFaStogafControllerTest do
  use XaasWeb.ConnCase, async: true

  test "GET /case-studies/wd-fa/stogaf.json exposes bounded architecture projection", %{
    conn: conn
  } do
    conn = get(conn, ~p"/case-studies/wd-fa/stogaf.json")
    body = json_response(conn, 200)

    assert body["architecture"]["current_conformance"] == "ST-4 CONSTRAINED"
    assert body["architecture"]["target_conformance"] == "ST-6 AUTONOMIC"
    assert body["architecture"]["authority"] == "SELECT_CONSTRUCT_ONLY"
    assert body["architecture"]["human_gate"] == "ENGINEER_DISPOSITION_REQUIRED"
    assert length(body["requirements"]) == 16
    assert length(body["viewpoints"]) == 5
    assert length(body["work_graph"]) == 10
    assert body["dfcm"]["production_levels_unclaimed"] == 3
    assert body["excluded_production_do"]["plane"] == "DO"
    refute Enum.any?(body["capabilities"], &(&1["plane"] == "DO"))
  end

  test "GET /case-studies/wd-fa/context/:case_id.json preserves the JSON context contract", %{
    conn: conn
  } do
    conn = get(conn, "/case-studies/wd-fa/context/known_firmware.json")
    body = json_response(conn, 200)

    assert body["canonical_subject"] == "urn:xaas:wd-cs2:case:known_firmware"
    assert body["authority_ceiling"] == "SELECT_CONSTRUCT_ONLY"
  end
end
