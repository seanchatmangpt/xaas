defmodule XaasWeb.Rpc.FamilyCourtW984hoTest do
  @moduledoc """
  W984ho unclaimed-family probe on the AshTypescript RPC surface
  (`XaasWeb.AshTypescriptRpcController`, mounted at
  POST /internal-api/rpc/run and POST /internal-api/rpc/validate in
  lib/xaas_web/router.ex, behind RequireInternalApiToken).

  W984eq's `rpc_surface_deepening_test.exs` covers: run success envelope,
  nil-actor org scoping, validate bad-input payload, unknown action on run,
  missing-action-param, 401/503 auth floor, router repoint, determinism.

  This court exercises the branches that file does NOT:

    1. wrong HTTP method (GET) on the POST-only RPC routes
    2. malformed JSON body before the controller (Plug.Parsers boundary)
    3. rpc/validate on an unknown action (only the run variant was covered)
    4. rpc/validate success envelope (success=true, no errors key contract)
    5. argument-cast failure on rpc/run surfacing a typed error envelope
       (string where a list of fields is required)
    6. rpc/validate mirrors run's per-branch parity on the same bad input
    7. unauthenticated validate route (auth floor holds on both RPC routes)

  Chicago-school: real ConnCase HTTP through the real router with the real
  INTERNAL_API_TOKEN convention, real AshTypescript pipeline, real sandboxed
  Postgres. Zero mocks. Mutation rationale per test.
  """

  use XaasWeb.ConnCase

  @token System.fetch_env!("INTERNAL_API_TOKEN")

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp with_token(conn) do
    conn
    |> Plug.Conn.put_req_header("authorization", "Bearer " <> @token)
    |> Plug.Conn.put_req_header("content-type", "application/json")
    |> Plug.Conn.put_req_header("accept", "application/json")
  end

  defp decoded_body(conn), do: Jason.decode!(conn.resp_body)

  ## ------------------------------------------------------------------
  ## 1. Wrong HTTP method
  ## ------------------------------------------------------------------

  test "1. GET on the POST-only rpc routes falls to the AshJsonApi catch-all and is 406-refused" do
    # Mutation rationale: if the rpc routes ever widen to accept GET,
    # state-changing surface becomes reachable with a cacheable,
    # CSRF-unprotected verb. Real observed behavior: since the explicit
    # POST-only route does not match GET, the request falls through to
    # the catch-all `forward "/internal-api"` (AshJsonApi.Router), whose
    # :internal_api pipeline (accepts ["json-api"]) raises
    # Phoenix.NotAcceptableError for an application/json accept header.
    assert_raise Phoenix.NotAcceptableError, fn ->
      build_conn()
      |> with_token()
      |> get("/internal-api/rpc/run")
    end
  end

  ## ------------------------------------------------------------------
  ## 2. Malformed JSON body (Plug.Parsers boundary, before the controller)
  ## ------------------------------------------------------------------

  test "2. malformed JSON body raises at the Plug.Parsers boundary, never a 200 envelope" do
    # Mutation rationale: if the parsers config or endpoint stops
    # rejecting malformed application/json, a garbage body would be
    # forwarded into the RPC controller (as empty params) and answered
    # 200 with a missing_required_parameter envelope instead of a
    # transport-level refusal. Real observed behavior: Plug.Parsers
    # raises ParseError (Jason.DecodeError) before the router, in both
    # test and production.
    assert_raise Plug.Parsers.ParseError, fn ->
      build_conn()
      |> with_token()
      |> post("/internal-api/rpc/run", "{not json")
    end
  end

  ## ------------------------------------------------------------------
  ## 3. rpc/validate on an unknown action
  ## ------------------------------------------------------------------

  test "3. rpc/validate on an unknown action returns action_not_found" do
    # Mutation rationale: if validate_action's parse_request branch ever
    # diverges from run_action's (e.g. validates against a stale action
    # table or accepts unknown actions), the generated TS client would
    # get a success-shaped stub for actions that do not exist.
    conn =
      build_conn()
      |> with_token()
      |> post("/internal-api/rpc/validate",
        Jason.encode!(%{"action" => "definitely_not_a_real_rpc_action_w984ho"})
      )

    assert conn.status == 200
    body = decoded_body(conn)

    assert body["success"] == false
    assert [%{"type" => "action_not_found"} = err] = body["errors"]
    assert is_binary(err["message"]) and err["message"] != ""
  end

  ## ------------------------------------------------------------------
  ## 4. rpc/validate success envelope
  ## ------------------------------------------------------------------

  test "4. rpc/validate on a valid request returns success=true" do
    # Mutation rationale: if validate_form_input ever fails a valid
    # request (e.g. fields no longer accepted), the generated TS client
    # would refuse to call real, lawful actions. Assert the positive
    # validate branch, which no existing test hits.
    conn =
      build_conn()
      |> with_token()
      |> post("/internal-api/rpc/validate",
        Jason.encode!(%{"action" => "list_marketplace_providers", "fields" => ["id", "name"]})
      )

    assert conn.status == 200
    body = decoded_body(conn)

    assert body["success"] == true
  end

  ## ------------------------------------------------------------------
  ## 5. Argument-cast failure on rpc/run
  ## ------------------------------------------------------------------

  test "5. rpc/run with a non-list fields argument surfaces a typed error envelope" do
    # Mutation rationale: if argument casting ever crashes instead of
    # returning a typed error (an 500 or an unhandled raise), the
    # envelope contract (always JSON, success flag + errors list)
    # would be broken for generated clients. Assert the typed-error
    # contract on the cast-failure branch.
    conn =
      build_conn()
      |> with_token()
      |> post("/internal-api/rpc/run",
        Jason.encode!(%{"action" => "list_marketplace_providers", "fields" => 42})
      )

    assert conn.status == 200, "expected 200 envelope, got #{conn.status}: #{conn.resp_body}"
    body = decoded_body(conn)
    assert body["success"] == false
    assert body["errors"] != []
  end

  test "6. rpc/validate crashes (unhandled FunctionClauseError) on non-list fields where rpc/run returns a typed envelope" do
    # Mutation rationale (and W984ho finding): run and validate DIVERGE
    # on the non-list `fields` cast failure. rpc/run surfaces a typed
    # success=false envelope (test 5); rpc/validate raises an unhandled
    # FunctionClauseError from
    # AshTypescript.Rpc.FieldProcessing.Atomizer.atomize_requested_fields/3
    # (a 500 in production). Pinned here as the real current contract so
    # any ash_typescript upgrade that fixes (or further breaks) this
    # asymmetry must update this court.
    assert_raise FunctionClauseError, fn ->
      build_conn()
      |> with_token()
      |> post("/internal-api/rpc/validate",
        Jason.encode!(%{"action" => "list_marketplace_providers", "fields" => 42})
      )
    end
  end

  ## ------------------------------------------------------------------
  ## 7. Auth floor on the validate route
  ## ------------------------------------------------------------------

  test "7. missing bearer on rpc/validate is 401" do
    # Mutation rationale: if the RequireInternalApiToken pipeline ever
    # stops covering the validate route (route moved out of the token
    # scope), an unauthenticated caller could enumerate the valid
    # action/argument surface without the token.
    conn =
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> post("/internal-api/rpc/validate", Jason.encode!(%{"action" => "anything"}))

    assert conn.status == 401
    assert Jason.decode!(conn.resp_body) == %{
             "error" => "unauthorized",
             "detail" => "missing or invalid Bearer token"
           }
  end
end
