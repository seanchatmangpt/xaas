defmodule XaasWeb.RequireInternalApiTokenDeepeningTest do
  @moduledoc """
  W723 deepening court for the single auth floor
  (lib/xaas_web/plugs/require_internal_api_token.ex) — the plug invoked
  DIRECTLY (real plug invocation, real env var, real sandboxed Postgres,
  no mocks) so every branch is pinned at the unit boundary, plus
  full-router requests pinning the real content-negotiation matrix
  (W699/W299c finding class: an Accept header that fails `:accepts` can
  preempt the auth floor with 406).

  Cases:
    (a) absent env + no header -> 503 exact documented body
    (b) absent env + wrong bearer -> still 503 (fail-closed wins over auth)
    (c) present env + missing header -> 401 exact
    (d) present env + wrong token -> 401 exact
    (e) valid token -> passes through (downstream reachable)
    (f) Bearer scheme case/whitespace discipline per the real parse
    (g) content-negotiation matrix pinned as the real contract
  """

  use XaasWeb.ConnCase

  alias XaasWeb.Plugs.RequireInternalApiToken

  @unauthorized_body %{
    "error" => "unauthorized",
    "detail" => "missing or invalid Bearer token"
  }

  @misconfigured_body %{
    "error" => "internal_api_misconfigured",
    "detail" => "INTERNAL_API_TOKEN is not set on the server"
  }

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  # The env var is process-wide; every manipulation restores the real value
  # in on_exit (same idiom as require_internal_api_token_test.exs).
  defp with_env(nil, fun), do: swap_env(nil, fun)

  defp with_env(value, fun) when is_binary(value) do
    swap_env(value, fun)
  end

  defp swap_env(new_value, fun) do
    previous = System.get_env("INTERNAL_API_TOKEN")

    if new_value do
      System.put_env("INTERNAL_API_TOKEN", new_value)
    else
      System.delete_env("INTERNAL_API_TOKEN")
    end

    on_exit(fn ->
      if previous do
        System.put_env("INTERNAL_API_TOKEN", previous)
      else
        System.delete_env("INTERNAL_API_TOKEN")
      end
    end)

    try do
      fun.()
    after
      if previous do
        System.put_env("INTERNAL_API_TOKEN", previous)
      else
        System.delete_env("INTERNAL_API_TOKEN")
      end
    end
  end

  defp direct_conn do
    Phoenix.ConnTest.build_conn()
    |> Plug.Conn.put_private(:phoenix_endpoint, XaasWeb.Endpoint)
    |> Plug.Conn.put_private(:phoenix_router, XaasWeb.Router)
    |> Plug.Conn.put_private(:phoenix_format, "json")
  end

  defp call_plug(conn) do
    RequireInternalApiToken.call(conn, nil)
  end

  # ---------------------------------------------------------------------
  # (a) absent env + no header -> 503 exact documented body
  # ---------------------------------------------------------------------
  test "a. absent env + no bearer header fails closed 503 with the exact documented body" do
    with_env(nil, fn ->
      conn = call_plug(direct_conn())

      assert conn.status == 503
      assert conn.halted

      assert Jason.decode!(conn.resp_body) == @misconfigured_body

      refute conn.assigns[:current_org]
    end)
  end

  # ---------------------------------------------------------------------
  # (b) absent env + wrong bearer -> still 503 (fail-closed wins over auth)
  # ---------------------------------------------------------------------
  test "b. absent env + wrong bearer is still 503 (misconfiguration outranks authentication)" do
    with_env(nil, fn ->
      conn =
        direct_conn()
        |> Plug.Conn.put_req_header("authorization", "Bearer definitely-not-the-token")
        |> call_plug()

      assert conn.status == 503
      assert conn.halted
      assert Jason.decode!(conn.resp_body) == @misconfigured_body
      refute conn.assigns[:current_org]
    end)
  end

  # ---------------------------------------------------------------------
  # (c) present env + missing header -> 401 exact
  # ---------------------------------------------------------------------
  test "c. present env + no bearer header is 401 with the exact body" do
    token = System.fetch_env!("INTERNAL_API_TOKEN")

    with_env(token, fn ->
      conn = call_plug(direct_conn())

      assert conn.status == 401
      assert conn.halted
      assert Jason.decode!(conn.resp_body) == @unauthorized_body
      refute conn.assigns[:current_org]
    end)
  end

  # ---------------------------------------------------------------------
  # (d) present env + wrong token -> 401 exact
  # ---------------------------------------------------------------------
  test "d. present env + wrong bearer token is 401 with the exact body" do
    token = System.fetch_env!("INTERNAL_API_TOKEN")

    with_env(token, fn ->
      conn =
        direct_conn()
        |> Plug.Conn.put_req_header("authorization", "Bearer wrong-token-#{System.unique_integer()}")
        |> call_plug()

      assert conn.status == 401
      assert conn.halted
      assert Jason.decode!(conn.resp_body) == @unauthorized_body
      refute conn.assigns[:current_org]
    end)
  end

  # ---------------------------------------------------------------------
  # (e) valid token -> passes through (downstream reachable)
  # ---------------------------------------------------------------------
  test "e. valid env token passes through the plug unhaltered, downstream reachable" do
    token = System.fetch_env!("INTERNAL_API_TOKEN")

    with_env(token, fn ->
      conn =
        direct_conn()
        |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
        |> call_plug()

      # The plug assigns and passes through -- it must NOT halt or set a status.
      refute conn.halted
      refute conn.status
      assert conn.assigns[:current_org] == nil

      # Real downstream reachability: a full dispatch with the valid token
      # gets past the floor and reaches a real /internal-api route.
      routed =
        Phoenix.ConnTest.build_conn()
        |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
        |> Plug.Conn.put_req_header("accept", "application/vnd.api+json")
        |> get("/internal-api/capability_liveness_receipts")

      refute routed.status == 401
      refute routed.status == 503
    end)
  end

  # ---------------------------------------------------------------------
  # (f) Bearer scheme case/whitespace discipline per the real parse
  #     (bearer_token/1 matches exactly ["Bearer " <> token] with
  #     byte_size(token) > 0)
  # ---------------------------------------------------------------------
  test "f1. lowercase 'bearer' scheme does not parse and is 401" do
    token = System.fetch_env!("INTERNAL_API_TOKEN")

    with_env(token, fn ->
      conn =
        direct_conn()
        |> Plug.Conn.put_req_header("authorization", "bearer " <> token)
        |> call_plug()

      assert conn.status == 401
      assert conn.halted
    end)
  end

  test "f2. ALL-CAPS 'BEARER' scheme does not parse and is 401" do
    token = System.fetch_env!("INTERNAL_API_TOKEN")

    with_env(token, fn ->
      conn =
        direct_conn()
        |> Plug.Conn.put_req_header("authorization", "BEARER " <> token)
        |> call_plug()

      assert conn.status == 401
      assert conn.halted
    end)
  end

  test "f3. extra whitespace between scheme and token does not match the env token" do
    token = System.fetch_env!("INTERNAL_API_TOKEN")

    with_env(token, fn ->
      conn =
        direct_conn()
        |> Plug.Conn.put_req_header("authorization", "Bearer  " <> token)
        |> call_plug()

      assert conn.status == 401
      assert conn.halted
    end)
  end

  test "f4. empty credentials ('Bearer ' with zero-length token) is treated as no header -> 401 when env set, 503 when absent" do
    token = System.fetch_env!("INTERNAL_API_TOKEN")

    with_env(token, fn ->
      conn =
        direct_conn()
        |> Plug.Conn.put_req_header("authorization", "Bearer ")
        |> call_plug()

      assert conn.status == 401
      assert conn.halted
    end)

    with_env(nil, fn ->
      conn =
        direct_conn()
        |> Plug.Conn.put_req_header("authorization", "Bearer ")
        |> call_plug()

      assert conn.status == 503
      assert conn.halted
      assert Jason.decode!(conn.resp_body) == @misconfigured_body
    end)
  end

  test "f5. no leading space at all ('Bearertoken') does not parse -> 401" do
    token = System.fetch_env!("INTERNAL_API_TOKEN")

    with_env(token, fn ->
      conn =
        direct_conn()
        |> Plug.Conn.put_req_header("authorization", "Bearer" <> token)
        |> call_plug()

      assert conn.status == 401
      assert conn.halted
    end)
  end

  test "f6. header-name case cannot even reach the plug: Plug test mode refuses non-lowercase keys" do
    token = System.fetch_env!("INTERNAL_API_TOKEN")

    with_env(token, fn ->
      # Real observed (raised in a real run): Plug.Conn.put_req_header/3
      # validates header keys are lowercase in test mode, so a
      # mixed-case header name is unconstructible here -- the plug is
      # guaranteed to only ever see lowercase "authorization". Pin the
      # guard itself as the case-discipline contract.
      assert_raise Plug.Conn.InvalidHeaderError, ~r/not lowercase/i, fn ->
        Plug.Conn.put_req_header(direct_conn(), "AUTHORIZATION", "Bearer " <> token)
      end

      # And get_req_header/2's lookup is case-SENSITIVE in the Conn
      # structure: the stored key is lowercase and a different-case
      # lookup misses.
      conn = Plug.Conn.put_req_header(direct_conn(), "authorization", "Bearer " <> token)

      assert Plug.Conn.get_req_header(conn, "AUTHORIZATION") == []
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer " <> token]
    end)
  end

  test "f7. duplicate authorization headers collapse to one (put_req_header replaces); the last value wins" do
    token = System.fetch_env!("INTERNAL_API_TOKEN")

    with_env(token, fn ->
      conn =
        direct_conn()
        |> Plug.Conn.put_req_header("authorization", "Bearer bogus-first-value")
        |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
        |> call_plug()

      # Real plug semantics: put_req_header/3 REPLACES the same-named
      # header, so only one authorization header ever exists and the
      # valid second value authenticates. (A wire-level duplicate-header
      # request would arrive as ["Bearer a", "Bearer b"] and fail the
      # single-element match -> 401; not constructible via put_req_header.)
      refute conn.halted
      refute conn.status
    end)
  end

  # ---------------------------------------------------------------------
  # (g) content-negotiation matrix as the real contract (W699/W299c class)
  # ---------------------------------------------------------------------
  test "g1. no Accept header + no token on /internal-api answers the auth floor, not 406" do
    conn =
      build_conn()
      |> get("/internal-api/capability_liveness_receipts")

    assert conn.status in [401, 503]
    refute conn.status == 406
  end

  test "g2. Accept: application/json + no token on /internal-api gets the auth floor, NOT 406 (W739 fix)" do
    # W739 (W699/W299c/W150 class): BEFORE the fix, the :internal_api
    # pipeline's plug(:accepts, ["json-api"]) ran before the token floor and
    # raised Phoenix.NotAcceptableError (406, leaking the accepted content
    # type list) to any unauthenticated probe. After the W739 reorder, the
    # token floor runs first: the probe gets the floor response.
    #
    # MUTATION RATIONALE: reverting the router reorder
    # (lib/xaas_web/router.ex, the forward("/internal-api") scope:
    # moving :internal_api back above :require_internal_api_token) makes
    # this dispatch raise Phoenix.NotAcceptableError instead of returning
    # the floor body -- the exact-body assert below is the assert that
    # fails.
    token = System.fetch_env!("INTERNAL_API_TOKEN")

    with_env(token, fn ->
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> get("/internal-api/capability_liveness_receipts")

      assert conn.status == 401
      refute conn.status == 406
      assert Jason.decode!(conn.resp_body) == @unauthorized_body
    end)
  end

  test "g3. Accept: text/plain + no token on /internal-api — same floor-first contract" do
    token = System.fetch_env!("INTERNAL_API_TOKEN")

    with_env(token, fn ->
      conn =
        build_conn()
        |> put_req_header("accept", "text/plain")
        |> get("/internal-api/capability_liveness_receipts")

      assert conn.status == 401
      refute conn.status == 406
      assert Jason.decode!(conn.resp_body) == @unauthorized_body
    end)
  end

  test "g4. with a VALID token, Accept: application/vnd.api+json is required on the json-api router (406 class otherwise)" do
    token = System.fetch_env!("INTERNAL_API_TOKEN")

    assert_raise Phoenix.NotAcceptableError, fn ->
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token)
      |> put_req_header("accept", "text/plain")
      |> get("/internal-api/capability_liveness_receipts")
    end
  end
end
