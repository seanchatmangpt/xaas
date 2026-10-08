defmodule XaasWeb.RouterChainCourtW984hqTest do
  @moduledoc """
  W984hq unclaimed-family probe: pipeline-level behavior of
  lib/xaas_web/router.ex + endpoint.ex branches not exercised elsewhere
  (census in docs/sjira/v26.10.6/plans/w984hq-probe.md).

  Real ConnCase through the real endpoint, real bearer token convention
  (`System.fetch_env!("INTERNAL_API_TOKEN")`), zero mocks. Each test names
  the router mutation it kills.
  """

  use XaasWeb.ConnCase

  @token System.fetch_env!("INTERNAL_API_TOKEN")
  defp auth(conn), do: put_req_header(conn, "authorization", "Bearer " <> @token)

  describe "browser pipeline negotiation (scope \"/\" pipe_through :browser)" do
    # Mutation: `plug(:accepts, ["html"])` -> `plug(:accepts, ["json"])` on
    # :browser (or dropping :accepts) would answer GET / with a 200 for a
    # JSON-Accept client instead of the coded 406.
    test "a JSON-Accept GET / is refused 406 by the browser pipeline's :accepts" do
      assert_raise Phoenix.NotAcceptableError, fn ->
        build_conn()
        |> put_req_header("accept", "application/json")
        |> get("/")
      end
    end

    # Mutation: dropping put_secure_browser_headers from :browser removes the
    # security header set while keeping a 200 — silent regression, only this
    # assertion observes it.
    test "GET / carries the secure browser headers from :browser pipeline" do
      conn =
        build_conn()
        |> get("/")

      assert html_response(conn, 200)
      assert get_resp_header(conn, "x-frame-options") != []
      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    end

    # Mutation: removing plug(Plug.Head) from the endpoint makes HEAD / match
    # no route (Phoenix matches the rewritten GET), producing a no-route
    # error instead of the coded 200.
    test "HEAD / is converted to GET by the endpoint's Plug.Head and answers 200" do
      conn =
        build_conn()
        |> head("/")

      assert conn.status == 200
    end
  end

  describe "webhooks scope (POST /webhooks/stripe, :api pipeline)" do
    # Mutation: dropping plug(:accepts, ["json"]) from the :api pipeline (or
    # reordering the pipeline after the controller dispatch) lets an
    # html-Accept webhook POST reach StripeWebhookController instead of the
    # coded 406.
    test "html-Accept POST /webhooks/stripe is refused 406 at scope negotiation" do
      assert_raise Phoenix.NotAcceptableError, fn ->
        build_conn()
        |> put_req_header("accept", "text/html")
        |> post("/webhooks/stripe", %{"type" => "ping"})
      end
    end

    # Mutation: registering the /webhooks scope with :browser instead of :api
    # (or dropping the scope) changes negotiation/forgery behavior; a
    # default-Accept JSON POST must keep flowing to the real signature check,
    # i.e. reach the controller (400 missing-signature, never 404/406).
    test "default-Accept POST /webhooks/stripe dispatches into the controller (400 class)" do
      conn =
        build_conn()
        |> post("/webhooks/stripe", %{"type" => "ping"})

      assert conn.status in [400, 500]
      refute conn.status == 404
      refute conn.status == 406
    end
  end

  describe "internal-api catch-all floor (scope \"/\" forward, json-api negotiation)" do
    # W739-class cell, authenticated side. Mutation: reordering
    # :require_internal_api_token after :internal_api in the catch-all
    # scope's pipe_through answers an authenticated text/plain probe with 401
    # instead of the coded 406 (negotiation ran before the actor pipeline).
    test "authenticated text/plain Accept on /internal-api forward is 406 (floor passed it through)" do
      assert_raise Phoenix.NotAcceptableError, fn ->
        build_conn()
        |> auth()
        |> put_req_header("accept", "text/plain")
        |> get("/internal-api/health")
      end
    end
  end
end
