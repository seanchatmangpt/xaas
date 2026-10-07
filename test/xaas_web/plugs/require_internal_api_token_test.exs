defmodule XaasWeb.Plugs.RequireInternalApiTokenTest do
  @moduledoc """
  Negative-path qualification for the auth floor
  (lib/xaas_web/plugs/require_internal_api_token.ex) — the CLAUDE.md
  declared floor whose 401 / 503 fail-closed branches previously had zero
  direct tests (vector2-refusal-coverage § D).

  Real ConnCase requests through the real router, real env var, real
  sandboxed Postgres. No mocks. Asserts the exact wire status, the exact
  JSON body, halt, and that no authenticated identity was ever attached
  (`assigns[:current_org]` stays nil on every refusal).
  """

  use XaasWeb.ConnCase

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  # The env var is process-wide; every manipulation restores the real value
  # in on_exit (same pattern as execution_fabric_controller_test.exs).
  defp without_env_token(fun) do
    previous = System.fetch_env!("INTERNAL_API_TOKEN")
    System.delete_env("INTERNAL_API_TOKEN")

    try do
      fun.()
    after
      System.put_env("INTERNAL_API_TOKEN", previous)
    end
  end

  defp receipts_before do
    Ash.count(Xaas.Operations.ActuationReceipt, authorize?: false)
  end

  test "no bearer header with INTERNAL_API_TOKEN set is refused 401", %{conn: conn} do
    count_before = receipts_before()

    conn = get(conn, "/internal-api/capability_liveness_receipts")

    assert conn.status == 401
    assert conn.halted

    assert json_response(conn, 401) == %{
             "error" => "unauthorized",
             "detail" => "missing or invalid Bearer token"
           }

    refute conn.assigns[:current_org]
    assert Ash.count(Xaas.Operations.ActuationReceipt, authorize?: false) == count_before
  end

  test "wrong bearer token with INTERNAL_API_TOKEN set is refused 401", %{conn: conn} do
    count_before = receipts_before()

    conn =
      conn
      |> put_req_header("authorization", "Bearer not-the-real-token")
      |> get("/internal-api/capability_liveness_receipts")

    assert conn.status == 401
    assert conn.halted

    assert json_response(conn, 401) == %{
             "error" => "unauthorized",
             "detail" => "missing or invalid Bearer token"
           }

    refute conn.assigns[:current_org]
    assert Ash.count(Xaas.Operations.ActuationReceipt, authorize?: false) == count_before
  end

  test "unset INTERNAL_API_TOKEN with no header fails closed with 503", %{conn: conn} do
    count_before = receipts_before()

    conn =
      without_env_token(fn ->
        conn
        |> get("/internal-api/capability_liveness_receipts")
      end)

    assert conn.status == 503
    assert conn.halted

    assert json_response(conn, 503) == %{
             "error" => "internal_api_misconfigured",
             "detail" => "INTERNAL_API_TOKEN is not set on the server"
           }

    refute conn.assigns[:current_org]
    assert Ash.count(Xaas.Operations.ActuationReceipt, authorize?: false) == count_before
  end

  test "unset INTERNAL_API_TOKEN with a wrong bearer token also fails closed with 503", %{
    conn: conn
  } do
    conn =
      without_env_token(fn ->
        conn
        |> put_req_header("authorization", "Bearer not-the-real-token")
        |> get("/internal-api/capability_liveness_receipts")
      end)

    assert conn.status == 503
    assert conn.halted
    refute conn.assigns[:current_org]
  end

  test "empty bearer token (\"Bearer \") is refused 401, never treated as present", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer ")
      |> get("/internal-api/capability_liveness_receipts")

    assert conn.status == 401
    assert conn.halted
    refute conn.assigns[:current_org]
  end

  # w414 mutation kill (w382 gap): this is the only cell that distinguishes
  # `byte_size(token) > 0` from `>= 0`. With the guard weakened, an empty
  # "Bearer " token flows into the env-compare path; with INTERNAL_API_TOKEN
  # unset that path must still 503 (fail-closed misconfiguration), NOT fall
  # through as 401. Every other empty-bearer test 401s identically under
  # both operator versions.
  test "empty bearer token with INTERNAL_API_TOKEN unset fails closed with 503, not 401", %{
    conn: conn
  } do
    conn =
      without_env_token(fn ->
        conn
        |> put_req_header("authorization", "Bearer ")
        |> get("/internal-api/capability_liveness_receipts")
      end)

    assert conn.status == 503
    assert conn.halted

    assert json_response(conn, 503) == %{
             "error" => "internal_api_misconfigured",
             "detail" => "INTERNAL_API_TOKEN is not set on the server"
           }

    refute conn.assigns[:current_org]
  end

  # w414 mutation kill: this is the cell that actually distinguishes
  # `byte_size(token) > 0` from the mutant `>= 0` at the bearer guard.
  # Under the mutant, an empty "Bearer " token reaches
  # `Plug.Crypto.secure_compare("", "")` when INTERNAL_API_TOKEN is set but
  # EMPTY, which returns true and authenticates the request (200). The real
  # operator must refuse 401. (The unset-env cell is NOT distinguishing:
  # both versions 503 there.)
  test "empty bearer token with INTERNAL_API_TOKEN set to empty string is refused 401, never authenticated", %{
    conn: conn
  } do
    previous = System.fetch_env!("INTERNAL_API_TOKEN")
    System.put_env("INTERNAL_API_TOKEN", "")

    try do
      conn =
        conn
        |> put_req_header("authorization", "Bearer ")
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/internal-api/capability_liveness_receipts?filter[capability]=nonexistent")

      assert conn.status == 401
      assert conn.halted
      refute conn.assigns[:current_org]
    after
      System.put_env("INTERNAL_API_TOKEN", previous)
    end
  end

  test "non-bearer authorization scheme is refused 401", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Basic dXNlcjpwYXNz")
      |> get("/internal-api/capability_liveness_receipts")

    assert conn.status == 401
    assert conn.halted
    refute conn.assigns[:current_org]
  end

  test "correct env token authenticates and attaches no org (legacy tier)", %{conn: conn} do
    conn =
      conn
      |> put_req_header(
        "authorization",
        "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN")
      )
      |> put_req_header("accept", "application/vnd.api+json")
      |> get("/internal-api/capability_liveness_receipts?filter[capability]=nonexistent")

    assert conn.status == 200
    assert conn.assigns[:current_org] |> is_nil()
  end
end
