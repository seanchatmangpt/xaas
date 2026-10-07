defmodule XaasWeb.EndpointBodyLimitTest do
  @moduledoc """
  Boundary tests for the explicit `:length` cap on the endpoint's
  `Plug.Parsers` (V5 finding: the cap was Plug's implicit 8 MiB default,
  not an admitted bound). Proves the cap is enforced at the endpoint,
  before any router/controller execution: an under-limit JSON POST parses
  and dispatches normally; an over-limit POST is refused with the typed
  `Plug.Parsers.RequestTooLargeError` (plug_status 413) before it can
  reach any route.
  """

  use XaasWeb.ConnCase, async: true

  @limit 8_000_000

  describe "explicit request-body cap" do
    test "under-limit JSON body parses and dispatches (no 413)" do
      payload = Jason.encode!(%{"event" => "ping", "padding" => String.duplicate("x", 1_000)})

      conn =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> post("/webhooks/stripe", payload)

      # Parsers passed the body through: whatever the route answered with,
      # it was NOT refused for size.
      refute conn.status == 413
    end

    test "over-limit JSON body is refused at the parsers layer, before execution" do
      oversized = String.duplicate("x", @limit + 1_000)

      # The real boundary: Plug.Conn.read_body returns {:more, ..} past the
      # explicit cap, XaasWeb.Plugs.StripeRawBodyReader propagates it, and
      # Plug.Parsers raises its typed RequestTooLargeError (plug_status 413)
      # on the endpoint stack, BEFORE the router runs (no route/controller
      # ever executes).
      assert_raise Plug.Parsers.RequestTooLargeError, fn ->
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> post("/webhooks/stripe", oversized)
      end
    end

    test "over-limit refusal happens before the router (no execution)" do
      oversized = String.duplicate("x", @limit + 1_000)

      assert_raise Plug.Parsers.RequestTooLargeError, fn ->
        conn =
          build_conn()
          |> put_req_header("content-type", "application/json")
          |> post("/webhooks/stripe", oversized)

        # If dispatch ever completes, the parsers layer did NOT enforce the
        # cap and the request reached execution — the invariant is broken.
        flunk("over-limit request reached execution: status #{conn.status}")
      end
    end
  end
end
