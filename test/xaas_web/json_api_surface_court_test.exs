defmodule XaasWeb.JsonApiSurfaceCourtTest do
  @moduledoc """
  W805 composed-surface court for the two generated AshJsonApi routers
  (`lib/xaas_web/internal_api_router.ex` at /internal-api and
  `lib/xaas_web/api_router.ex` at /api) — previously undocketed as a
  composed surface.

  Chicago-style: real ConnCase HTTP through the real mounted routers,
  real sandboxed Postgres rows via real Ash actions. No mocks, no
  interaction assertions.

  Courts this file adds (cross-referencing existing courts):
    (a) one representative READ per router returns a real json-api
        document (data/attributes/links) for real sandboxed rows —
        same resource (`Xaas.Operations.CapabilityLivenessReceipt`,
        json_api type "capability_liveness_receipts") is declared on
        BOTH routers, making it the natural composed-surface probe;
    (b) cross-check of the W743 `ResolveOrgActor` court: a
        NON-special /api resource reads 200 WITHOUT any X-Org-Id
        header — the plug's documented pass-through;
    (c) the W733 org-forgery refusal pattern, over real HTTP on the
        generated surface: POST /api/marketplace_providers with a
        real `X-Org-Id` (org A) but a body `org_id` claiming org B is
        refused by `Xaas.Marketplace.Checks.ActorOrgMatches` -> 403;
    (d) the W739 floor-first ordering on /internal-api: with the real
        `Accept: application/vnd.api+json` header and NO bearer
        token, the auth floor answers 401 — never a 406;
    (e) determinism x2: the (a) /api read and the (d) floor probe are
        each replayed and must be byte-identical in status + body.
  """

  use XaasWeb.ConnCase

  require Ash.Query

  alias Xaas.Accounts.Org
  alias Xaas.Operations.CapabilityLivenessReceipt

  @token System.fetch_env!("INTERNAL_API_TOKEN")

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp auth(conn), do: put_req_header(conn, "authorization", "Bearer " <> @token)
  defp jsonapi(conn), do: put_req_header(conn, "accept", "application/vnd.api+json")

  defp ingest_receipt!(capability) do
    CapabilityLivenessReceipt
    |> Ash.Changeset.for_create(:ingest, %{
      capability: capability,
      authority: "SELECT",
      status: "ALIVE",
      subject: "git:w805-jsonapi-surface-court",
      detail: "real row for w805 composed surface court"
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
  describe "(a) representative READ per router returns real json-api documents" do
    test "GET /internal-api/capability_liveness_receipts returns data/attributes/links", %{
      conn: conn
    } do
      capability = "w805-internal-#{System.unique_integer([:positive])}"
      receipt = ingest_receipt!(capability)

      conn =
        conn
        |> auth()
        |> jsonapi()
        |> get("/internal-api/capability_liveness_receipts?filter[capability]=#{capability}")

      assert conn.status == 200
      body = json_response(conn, 200)

      assert [row] = body["data"]
      assert row["type"] == "capability_liveness_receipts"
      assert row["id"] == to_string(receipt.id)
      assert row["attributes"]["capability"] == capability
      assert row["attributes"]["status"] == "ALIVE"
      assert row["attributes"]["subject"] == "git:w805-jsonapi-surface-court"
      assert is_map(body["links"])
    end

    test "GET /api/capability_liveness_receipts returns the same document shape on /api", %{
      conn: conn
    } do
      capability = "w805-api-#{System.unique_integer([:positive])}"
      receipt = ingest_receipt!(capability)

      conn =
        conn
        |> auth()
        |> jsonapi()
        |> get("/api/capability_liveness_receipts?filter[capability]=#{capability}")

      assert conn.status == 200
      body = json_response(conn, 200)

      assert [row] = body["data"]
      assert row["type"] == "capability_liveness_receipts"
      assert row["id"] == to_string(receipt.id)
      assert row["attributes"]["capability"] == capability
      assert row["attributes"]["status"] == "ALIVE"
      assert is_map(body["links"])
    end
  end

  # --------------------------------------------------------------- (b)
  describe "(b) non-special /api resource reads fine WITHOUT X-Org-Id (W743 pass-through)" do
    test "GET /api/capability_liveness_receipts with no X-Org-Id is a real 200", %{conn: conn} do
      capability = "w805-noheader-#{System.unique_integer([:positive])}"
      receipt = ingest_receipt!(capability)

      # Deliberately NO x-org-id header. "capability_liveness_receipts"
      # is not in ResolveOrgActor's @tenant_scoped_path_segments, so the
      # plug must pass through untouched and the read must succeed.
      conn =
        conn
        |> auth()
        |> jsonapi()
        |> get("/api/capability_liveness_receipts?filter[capability]=#{capability}")

      assert conn.status == 200
      body = json_response(conn, 200)

      assert [row] = body["data"]
      assert row["id"] == to_string(receipt.id)
      assert row["attributes"]["capability"] == capability
      refute get_req_header(conn, "x-org-id") != []
    end
  end

  # --------------------------------------------------------------- (c)
  describe "(c) org-forgery refusal on create via forged org (W733 pattern, over real HTTP)" do
    test "POST /api/marketplace_providers claiming org B under org A's X-Org-Id is 403", %{
      conn: conn
    } do
      org_a = real_org!("w805-org-a")
      org_b = real_org!("w805-org-b")

      conn =
        conn
        |> auth()
        |> jsonapi()
        |> put_req_header("content-type", "application/vnd.api+json")
        # real header asserts org A ...
        |> put_req_header("x-org-id", org_a.slug)
        # ... but the body forges org B's identity
        |> post("/api/marketplace_providers", %{
          "data" => %{
            "type" => "marketplace_provider",
            "attributes" => %{
              "name" => "Impostor",
              "slug" => "w805-impostor-#{System.unique_integer([:positive])}",
              "org_id" => org_b.slug
            }
          }
        })

      assert conn.status == 403

      body = json_response(conn, 403)
      assert body["errors"]

      # and nothing really persisted under either org
      assert Xaas.Marketplace.Provider
             |> Ash.Query.filter(name == "Impostor")
             |> Ash.read!(authorize?: false) == []
    end
  end

  # --------------------------------------------------------------- (d)
  describe "(d) W739 floor-first ordering on /internal-api (401 not 406)" do
    test "unauthenticated GET with Accept: application/vnd.api+json gets the auth floor", %{
      conn: conn
    } do
      conn =
        conn
        |> jsonapi()
        |> get("/internal-api/capability_liveness_receipts")

      assert conn.status == 401
      refute conn.status == 406
    end
  end

  # --------------------------------------------------------------- (e)
  describe "(e) determinism x2" do
    test "the /api read is deterministic across two real replays", %{conn: conn} do
      capability = "w805-det-#{System.unique_integer([:positive])}"
      receipt = ingest_receipt!(capability)

      path = "/api/capability_liveness_receipts?filter[capability]=#{capability}"

      run = fn ->
        conn
        |> auth()
        |> jsonapi()
        |> get(path)
        |> Map.update!(:resp_body, fn body -> body end)
      end

      c1 = run.()
      c2 = run.()

      assert c1.status == 200
      assert c2.status == 200
      assert c1.status == c2.status
      assert c1.resp_body == c2.resp_body

      assert [row] = json_response(c1, 200)["data"]
      assert row["id"] == to_string(receipt.id)
    end

    test "the unauthenticated floor probe is deterministic across two real replays", %{
      conn: conn
    } do
      run = fn ->
        conn
        |> jsonapi()
        |> get("/internal-api/capability_liveness_receipts")
      end

      c1 = run.()
      c2 = run.()

      assert c1.status == 401
      assert c2.status == 401
      assert c1.status == c2.status
      assert c1.resp_body == c2.resp_body
    end
  end
end
