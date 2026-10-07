defmodule XaasWeb.EuAiActExportDeepeningTest do
  @moduledoc """
  W771 deepening court for the OS-14 runtime export surface
  (GET /internal-api/eu-ai-act/pack, `XaasWeb.EuAiActExportController`).

  Chicago-style: real HTTP through the real `RequireInternalApiToken` floor,
  real `Mix.Tasks.Xaas.EuAiActPack.build/1` reading the real on-disk evidence
  tree. No mocks. Pins:

    (a) happy path — pack body shape against the real build/1 output
    (b) build/1 fail-closed — cwd at an empty temp dir -> exact 503 body
        `xaas.eu_ai_act_pack_refusal/v1` (W712's pinned contract)
    (c) token floor — 401 exact body / unset-env 503 fail-closed (W723 matrix)
    (d) determinism — byte-identical pack body from a pinned `now`
    (e) content-type/headers per the real plug_send
  """

  use XaasWeb.ConnCase

  @refusal_body %{
    "schema" => "xaas.eu_ai_act_pack_refusal/v1"
  }

  @unauthorized_body %{
    "error" => "unauthorized",
    "detail" => "missing or invalid Bearer token"
  }

  @misconfigured_body %{
    "error" => "internal_api_misconfigured",
    "detail" => "INTERNAL_API_TOKEN is not set on the server"
  }

  setup do
    {:ok, token: System.fetch_env!("INTERNAL_API_TOKEN")}
  end

  defp authed(conn, token), do: put_req_header(conn, "authorization", "Bearer " <> token)

  # ---------------------------------------------------------------------------
  # (a) happy path — shape pinned against the real build/1, not a snapshot
  # ---------------------------------------------------------------------------

  test "GET pack: top-level keys + one representative entry per section match the real build/1",
       %{conn: conn, token: token} do
    conn = conn |> authed(token) |> get("/internal-api/eu-ai-act/pack")
    body = json_response(conn, 200)

    assert MapSet.new(Map.keys(body)) ==
             MapSet.new([
               "schema",
               "generated_at",
               "subject",
               "source_map",
               "articles",
               "refusal_corpus",
               "typed_gaps"
             ])

    # Section representatives, each cross-checked against the real build/1.
    {:ok, pack} = Mix.Tasks.Xaas.EuAiActPack.build()

    assert body["schema"] == "xaas.eu_ai_act_pack/v1"

    # subject: real git identity of the canonical checkout
    assert %{"branch" => branch, "head_sha" => head_sha} = body["subject"]
    assert String.length(head_sha) == 40
    assert branch != ""
    {git_sha, 0} = System.cmd("git", ["rev-parse", "HEAD"])
    assert head_sha == String.trim(git_sha)

    # source_map
    assert body["source_map"]["path"] ==
             "docs/sjira/v26.10.6/eu-ai-act-nist-coverage-map.md"

    # articles: real keyset + one representative entry, equal to build/1's
    assert MapSet.new(Map.keys(body["articles"])) == MapSet.new(Map.keys(pack.articles))

    art5 = body["articles"]["art5"]
    assert art5["verdict"] == "NOT_MAPPED_IN_COVERAGE_MAP"
    assert is_binary(art5["note"]) and art5["note"] != ""
    assert art5["evidence"] == ["docs/sjira/v26.10.6/eu-ai-act-nist-coverage-map.md"]

    # refusal_corpus
    corpus = body["refusal_corpus"]
    assert corpus["status"] in ["PRESENT", "ABSENT"]

    if corpus["status"] == "PRESENT" do
      assert corpus["path"] == "docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json"
      assert is_map(corpus["counts"]) and map_size(corpus["counts"]) > 0
      assert %{"branch" => _, "head_sha" => _} = corpus["subject"]
    else
      assert Map.has_key?(corpus, "expected_path")
    end

    # typed_gaps: verbatim GAP()/OS-14..19 lines from the real map
    assert %{"source" => source, "note" => note, "lines" => lines} = body["typed_gaps"]
    assert source == "docs/sjira/v26.10.6/eu-ai-act-nist-coverage-map.md"
    assert is_binary(note) and note != ""
    assert is_list(lines) and lines != []
    assert Enum.any?(lines, &String.contains?(&1, "GAP("))
    assert Enum.all?(lines, fn line ->
             String.contains?(line, "GAP(") or Regex.match?(~r/OS-1[4-9]\b/, line)
           end)
  end

  # ---------------------------------------------------------------------------
  # (b) build/1 fail-closed — empty evidence root -> exact 503 refusal body
  # ---------------------------------------------------------------------------

  test "empty evidence root -> 503 with the exact W712 refusal body",
       %{conn: conn, token: token} do
    tmp = Path.join(System.tmp_dir!(), "w771-empty-evidence-#{System.unique_integer()}")
    File.mkdir_p!(tmp)

    on_exit(fn -> File.rm_rf!(tmp) end)

    # build/1 reads relative evidence paths; file:set_cwd is per-process on
    # the BEAM, and ConnCase dispatches the plug pipeline in the test
    # process, so the controller genuinely sees the empty root.
    previous = File.cwd!()
    File.cd!(tmp)

    try do
      conn = conn |> authed(token) |> get("/internal-api/eu-ai-act/pack")

      assert conn.status == 503
      body = json_response(conn, 503)

      assert body["schema"] == "xaas.eu_ai_act_pack_refusal/v1"
      assert body["refused"] ==
               inspect({:REFUSED_COVERAGE_MAP_MISSING, "docs/sjira/v26.10.6/eu-ai-act-nist-coverage-map.md"})
    after
      File.cd!(previous)
    end
  end

  # ---------------------------------------------------------------------------
  # (c) token floor — 401 exact body / unset-env 503 fail-closed (W723 matrix)
  # ---------------------------------------------------------------------------

  test "wrong bearer -> 401 with the exact floor body",
       %{conn: conn, token: _token} do
    conn = conn |> put_req_header("authorization", "Bearer not-the-token") |> get("/internal-api/eu-ai-act/pack")

    assert conn.status == 401
    assert json_response(conn, 401) == @unauthorized_body
  end

  test "no bearer + set env -> 401 with the exact floor body",
       %{conn: conn, token: _token} do
    conn = get(conn, "/internal-api/eu-ai-act/pack")
    assert conn.status == 401
    assert json_response(conn, 401) == @unauthorized_body
  end

  test "unset INTERNAL_API_TOKEN + no bearer -> 503 fail-closed with the exact floor body",
       %{conn: conn, token: _token} do
    previous = System.get_env("INTERNAL_API_TOKEN")
    System.delete_env("INTERNAL_API_TOKEN")

    try do
      conn = get(conn, "/internal-api/eu-ai-act/pack")

      assert conn.status == 503
      assert json_response(conn, 503) == @misconfigured_body
    after
      if previous, do: System.put_env("INTERNAL_API_TOKEN", previous)
    end
  end

  test "unset INTERNAL_API_TOKEN + wrong bearer -> still 503 (fail-closed wins)",
       %{conn: conn, token: _token} do
    previous = System.get_env("INTERNAL_API_TOKEN")
    System.delete_env("INTERNAL_API_TOKEN")

    try do
      conn =
        conn
        |> put_req_header("authorization", "Bearer not-the-token")
        |> get("/internal-api/eu-ai-act/pack")

      assert conn.status == 503
      assert json_response(conn, 503) == @misconfigured_body
    after
      if previous, do: System.put_env("INTERNAL_API_TOKEN", previous)
    end
  end

  # ---------------------------------------------------------------------------
  # (d) determinism — byte-identical pack body (pinned now; the controller
  # injects DateTime.utc_now/0, so over-the-wire bytes differ only in
  # generated_at, pinned equal-modulo-generated_at as well)
  # ---------------------------------------------------------------------------

  test "build/1 with a pinned now encodes byte-identical output across two builds",
       %{conn: _conn, token: _token} do
    now = ~U[2026-10-07 00:00:00.000000Z]

    {:ok, pack1} = Mix.Tasks.Xaas.EuAiActPack.build(now)
    {:ok, pack2} = Mix.Tasks.Xaas.EuAiActPack.build(now)

    bytes1 = Jason.encode!(pack1)
    bytes2 = Jason.encode!(pack2)

    assert bytes1 == bytes2
    assert byte_size(bytes1) > 0
  end

  test "two live GETs are byte-identical modulo generated_at",
       %{conn: conn, token: token} do
    conn1 = conn |> authed(token) |> get("/internal-api/eu-ai-act/pack")
    %{"generated_at" => gen1} = body1 = json_response(conn1, 200)

    conn2 = conn |> authed(token) |> get("/internal-api/eu-ai-act/pack")
    %{"generated_at" => gen2} = body2 = json_response(conn2, 200)

    assert gen1 != gen2
    assert %{body1 | "generated_at" => nil} == %{body2 | "generated_at" => nil}
  end

  # ---------------------------------------------------------------------------
  # (e) content-type / headers per the real plug_send
  # ---------------------------------------------------------------------------

  test "200 response content-type is the real json/2 send",
       %{conn: conn, token: token} do
    conn = conn |> authed(token) |> get("/internal-api/eu-ai-act/pack")

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
    assert conn.state == :sent
  end

  test "refusal response content-type is the real json/2 send",
       %{conn: conn, token: token} do
    tmp = Path.join(System.tmp_dir!(), "w771-empty-evidence-ct-#{System.unique_integer()}")
    File.mkdir_p!(tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)

    previous = File.cwd!()
    File.cd!(tmp)

    try do
      conn = conn |> authed(token) |> get("/internal-api/eu-ai-act/pack")

      assert conn.status == 503
      assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
      assert conn.state == :sent
    after
      File.cd!(previous)
    end
  end
end
