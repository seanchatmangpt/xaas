defmodule XaasWeb.JsonapiContentNegotiationTest do
  @moduledoc """
  W817 — dedicated JSON:API content-negotiation court for the two
  generated AshJsonApi surfaces (`lib/xaas_web/internal_api_router.ex` at
  /internal-api and `lib/xaas_web/api_router.ex` at /api), where the
  W723/W739 406-leak class lives.

  Post-W739 contract being courted (pipeline order = plug order in
  `lib/xaas_web/router.ex`):
    /internal-api forward: :require_internal_api_token -> :internal_api
      (accepts ["json-api"]) -> :set_internal_api_system_actor
    /api forward:          :require_internal_api_token -> :internal_api ->
      :resolve_org_actor -> :set_internal_api_system_actor

  So the negotiation matrix is:
    - unauthenticated + any Accept -> the auth floor (401), never 406
      (W739/W299c/W150 floor-first fix);
    - authenticated + Accept: application/vnd.api+json -> 200 (happy cell);
    - authenticated + incompatible Accept -> Phoenix.NotAcceptableError
      (the json-api :accepts check still enforces negotiation post-auth);
    - POST with a non-JSON:API Content-Type -> the real AshJsonApi
      UnsupportedMediaType behavior.

  Chicago-style: real ConnCase dispatch through the real mounted routers,
  real sandboxed Postgres rows via real Ash actions, zero mocks.
  """

  use XaasWeb.ConnCase

  alias Xaas.Accounts.Org
  alias Xaas.Operations.CapabilityLivenessReceipt

  @token System.fetch_env!("INTERNAL_API_TOKEN")

  @unauthorized_body %{
    "error" => "unauthorized",
    "detail" => "missing or invalid Bearer token"
  }

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp auth(conn), do: put_req_header(conn, "authorization", "Bearer " <> @token)
  defp jsonapi_accept(conn), do: put_req_header(conn, "accept", "application/vnd.api+json")
  defp jsonapi_ctype(conn), do: put_req_header(conn, "content-type", "application/vnd.api+json")

  defp ingest_receipt!(capability) do
    CapabilityLivenessReceipt
    |> Ash.Changeset.for_create(:ingest, %{
      capability: capability,
      authority: "SELECT",
      status: "ALIVE",
      subject: "git:w817-negotiation-court",
      detail: "real row for w817 negotiation court"
    })
    |> Ash.create!(authorize?: false)
  end

  defp real_org!(prefix) do
    Org
    |> Ash.Changeset.for_create(:create, %{
      name: "#{prefix} #{System.unique_integer([:positive])}",
      slug: "#{prefix}-#{System.unique_integer([:positive])}"
    })
    |> Ash.create!(authorize?: false)
  end

  # --------------------------------------------------------------- (a)
  describe "(a) happy cell: authenticated json-api Accept reads 200 on both scopes" do
    @tag :w817
    test "GET /internal-api with Accept: application/vnd.api+json returns a real json-api document",
         %{conn: conn} do
      capability = "w817-internal-#{System.unique_integer([:positive])}"
      receipt = ingest_receipt!(capability)

      conn =
        conn
        |> auth()
        |> jsonapi_accept()
        |> get("/internal-api/capability_liveness_receipts?filter[capability]=#{capability}")

      assert conn.status == 200
      body = json_response(conn, 200)

      assert [row] = body["data"]
      assert row["type"] == "capability_liveness_receipts"
      assert row["id"] == to_string(receipt.id)
      assert row["attributes"]["capability"] == capability
      assert get_resp_header(conn, "content-type")
             |> Enum.any?(&String.contains?(&1, "application/vnd.api+json"))
    end

    @tag :w817
    test "GET /api with Accept: application/vnd.api+json returns the same json-api document shape",
         %{conn: conn} do
      capability = "w817-api-#{System.unique_integer([:positive])}"
      receipt = ingest_receipt!(capability)

      conn =
        conn
        |> auth()
        |> jsonapi_accept()
        |> get("/api/capability_liveness_receipts?filter[capability]=#{capability}")

      assert conn.status == 200
      body = json_response(conn, 200)

      assert [row] = body["data"]
      assert row["type"] == "capability_liveness_receipts"
      assert row["id"] == to_string(receipt.id)
      assert get_resp_header(conn, "content-type")
             |> Enum.any?(&String.contains?(&1, "application/vnd.api+json"))
    end
  end

  # --------------------------------------------------------------- (b)
  describe "(b) authenticated with Accept: application/json — the real post-W739 behavior" do
    @tag :w817
    test "authenticated application/json Accept raises Phoenix.NotAcceptableError on /internal-api",
         %{conn: conn} do
      # The floor passes the authenticated request through to the same
      # :accepts(["json-api"]) check, which raises for application/json.
      assert_raise Phoenix.NotAcceptableError, ~r/Expected one of \["json-api"\]/, fn ->
        conn
        |> auth()
        |> put_req_header("accept", "application/json")
        |> get("/internal-api/capability_liveness_receipts")
      end
    end

    @tag :w817
    test "authenticated application/json Accept raises Phoenix.NotAcceptableError on /api too",
         %{conn: conn} do
      assert_raise Phoenix.NotAcceptableError, ~r/Expected one of \["json-api"\]/, fn ->
        conn
        |> auth()
        |> put_req_header("accept", "application/json")
        |> get("/api/capability_liveness_receipts")
      end
    end

    @tag :w817
    test "UNauthenticated application/json Accept gets the auth floor, never 406 (W739 cell)",
         %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> get("/internal-api/capability_liveness_receipts")

      assert conn.status == 401
      refute conn.status == 406
      assert Jason.decode!(conn.resp_body) == @unauthorized_body
    end

    @tag :w817
    test "UNauthenticated application/json Accept on /api gets the auth floor, never 406 (W299c cell)",
         %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> get("/api/capability_liveness_receipts")

      assert conn.status == 401
      refute conn.status == 406
      assert Jason.decode!(conn.resp_body) == @unauthorized_body
    end
  end

  # --------------------------------------------------------------- (c)
  describe "(c) POST Content-Type discipline (JSON:API media-type rules)" do
    @tag :w817
    test "POST /api/marketplace_providers with Content-Type: application/json is refused (415 class)",
         %{conn: conn} do
      org = real_org!("w817-org")

      conn =
        conn
        |> auth()
        |> jsonapi_accept()
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-org-id", org.slug)
        |> post("/api/marketplace_providers", Jason.encode!(%{
          "data" => %{
            "type" => "marketplace_provider",
            "attributes" => %{
              "name" => "WrongCtype",
              "slug" => "w817-ctype-#{System.unique_integer([:positive])}"
            }
          }
        }))

      assert conn.status == 415

      body = json_response(conn, 415)
      assert body["errors"]
    end

    @tag :w817
    test "POST with the correct application/vnd.api+json Content-Type is NOT refused for media type",
         %{conn: conn} do
      org = real_org!("w817-org-ok")

      conn =
        conn
        |> auth()
        |> jsonapi_accept()
        |> jsonapi_ctype()
        |> put_req_header("x-org-id", org.slug)
        |> post("/api/marketplace_providers", Jason.encode!(%{
          "data" => %{
            "type" => "marketplace_provider",
            "attributes" => %{
              "name" => "W817 CorrectCtype",
              "slug" => "w817-ok-#{System.unique_integer([:positive])}",
              "org_id" => org.slug
            }
          }
        }))

      # The exact downstream outcome (201 or a validation refusal) is the
      # resource's business; what this cell pins is that the request is NOT
      # killed by content negotiation. 415 is the only banned outcome.
      refute conn.status == 415
      assert conn.status in [201, 403, 422]
    end

    @tag :w817
    test "POST /api/marketplace_providers with Content-Type: text/plain raises UnsupportedMediaTypeError",
         %{conn: conn} do
      # Run-discovered split: `application/json` reaches AshJsonApi, which
      # answers a real 415 document; `text/plain` never gets that far —
      # Plug.Parsers (via the AshJsonApi router's parser) raises before any
      # controller/document code runs. Both are the real refusal; this cell
      # pins the raised-exception half exactly.
      org = real_org!("w817-org-plain")

      assert_raise Plug.Parsers.UnsupportedMediaTypeError, ~r/unsupported media type text\/plain/,
                   fn ->
                     conn
                     |> auth()
                     |> jsonapi_accept()
                     |> put_req_header("content-type", "text/plain")
                     |> put_req_header("x-org-id", org.slug)
                     |> post("/api/marketplace_providers", "not json at all")
                   end
    end
  end

  # --------------------------------------------------------------- (d)
  describe "(d) /api forward scope negotiation (W299c side)" do
    @tag :w817
    test "unauthenticated GET with the correct json-api Accept still gets the auth floor (401)",
         %{conn: conn} do
      conn =
        conn
        |> jsonapi_accept()
        |> get("/api/capability_liveness_receipts")

      assert conn.status == 401
      refute conn.status == 406
      assert Jason.decode!(conn.resp_body) == @unauthorized_body
    end

    @tag :w817
    test "no Accept header at all defaults to json-api and hits the auth floor on /api",
         %{conn: conn} do
      conn =
        conn
        |> get("/api/capability_liveness_receipts")

      assert conn.status in [401]
      refute conn.status == 406
    end

    @tag :w817
    test "text/plain Accept unauthenticated on /api: floor first (401), not 406", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "text/plain")
        |> get("/api/capability_liveness_receipts")

      assert conn.status == 401
      refute conn.status == 406
    end

    @tag :w817
    test "authenticated text/plain Accept on /api raises the same NotAcceptableError", %{
      conn: conn
    } do
      assert_raise Phoenix.NotAcceptableError, ~r/Expected one of \["json-api"\]/, fn ->
        conn
        |> auth()
        |> put_req_header("accept", "text/plain")
        |> get("/api/capability_liveness_receipts")
      end
    end
  end

  # --------------------------------------------------------------- (e)
  describe "(e) determinism" do
    @tag :w817
    test "the (a) happy read is byte-identical across two real replays", %{conn: conn} do
      capability = "w817-det-#{System.unique_integer([:positive])}"
      ingest_receipt!(capability)
      path = "/internal-api/capability_liveness_receipts?filter[capability]=#{capability}"

      run = fn ->
        conn
        |> auth()
        |> jsonapi_accept()
        |> get(path)
      end

      c1 = run.()
      c2 = run.()

      assert c1.status == 200 and c2.status == 200
      assert c1.resp_body == c2.resp_body
    end

    @tag :w817
    test "the unauthenticated application/json floor cell is byte-identical across two replays",
         %{conn: conn} do
      run = fn ->
        conn
        |> put_req_header("accept", "application/json")
        |> get("/internal-api/capability_liveness_receipts")
      end

      c1 = run.()
      c2 = run.()

      assert c1.status == 401 and c2.status == 401
      assert c1.resp_body == c2.resp_body
    end

    @tag :w817
    test "the /api floor cell is byte-identical across two replays", %{conn: conn} do
      run = fn ->
        conn
        |> jsonapi_accept()
        |> get("/api/capability_liveness_receipts")
      end

      c1 = run.()
      c2 = run.()

      assert c1.status == 401 and c2.status == 401
      assert c1.resp_body == c2.resp_body
    end
  end
end
