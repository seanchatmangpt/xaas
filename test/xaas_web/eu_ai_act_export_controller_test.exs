defmodule XaasWeb.EuAiActExportControllerTest do
  @moduledoc """
  Real Chicago-style test for the OS-14 runtime export surface
  (GET /internal-api/eu-ai-act/pack): real HTTP request through the real
  internal-api token floor against the real fail-closed pack build
  (`Mix.Tasks.Xaas.EuAiActPack.build/1`) reading the real on-disk evidence
  tree. No mocks.
  """
  use XaasWeb.ConnCase

  defp with_internal_api_token(conn) do
    put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
  end

  test "GET /internal-api/eu-ai-act/pack returns the parseable pack with schema + typed gaps",
       %{conn: conn} do
    conn = conn |> with_internal_api_token() |> get("/internal-api/eu-ai-act/pack")
    body = json_response(conn, 200)

    assert body["schema"] == "xaas.eu_ai_act_pack/v1"
    assert %{"lines" => lines} = body["typed_gaps"]
    assert is_list(lines) and lines != []
    assert Enum.any?(lines, &String.contains?(&1, "GAP("))

    assert %{"branch" => _, "head_sha" => _} = body["subject"]
    assert is_map(body["articles"])
    refute map_size(body["articles"]) == 0
  end

  test "every cited evidence path exists on disk (fail-closed contract held)",
       %{conn: conn} do
    conn = conn |> with_internal_api_token() |> get("/internal-api/eu-ai-act/pack")
    body = json_response(conn, 200)

    paths =
      body["articles"]
      |> Map.values()
      |> Enum.flat_map(& &1["evidence"])
      |> Enum.uniq()

    refute paths == []

    for path <- paths do
      assert File.exists?(Path.expand(path)), "cited evidence path missing: #{path}"
    end
  end

  test "two GETs are identical modulo generated_at (deterministic pack)",
       %{conn: conn} do
    conn1 = conn |> with_internal_api_token() |> get("/internal-api/eu-ai-act/pack")
    body1 = json_response(conn1, 200)
    conn2 = conn |> with_internal_api_token() |> get("/internal-api/eu-ai-act/pack")
    body2 = json_response(conn2, 200)

    assert %{body1 | "generated_at" => nil} == %{body2 | "generated_at" => nil}
    refute body1["generated_at"] == body2["generated_at"]
  end

  test "no token -> the existing floor's typed 401 (behavior preserved)",
       %{conn: conn} do
    conn = get(conn, "/internal-api/eu-ai-act/pack")
    assert conn.status == 401
  end
end
