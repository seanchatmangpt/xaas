defmodule XaasWeb.Controllers.InternalApiCourtW984lvTest do
  @moduledoc """
  Lane W984lv — unclaimed-family probe court on the `/internal-api`
  AshJsonApi catch-all forward (`XaasWeb.InternalApiRouter`).

  Census finding: every explicitly-declared controller route on the
  internal-api scope (capability_regressions, ocel_summary, eu-ai-act,
  prometheus, health, rpc, execution fabric, bounded fabric, sparql,
  workbench) is already courted. The genuinely unexercised REST surface
  is the AshJsonApi routes the catch-all router serves for the
  `Xaas.Operations` resources that declare `routes do` blocks but whose
  `/internal-api/...` paths appear in zero test files:

  - GET  /internal-api/incidents           (index :read)
  - GET  /internal-api/incidents/:id       (get :read)
  - POST /internal-api/incidents           (post :create — ActorOrgMatches)
  - GET  /internal-api/audit_log_entries   (index :read)
  - GET  /internal-api/audit_log_entries/:id (get :read)
  - GET  /internal-api/route_castle_deploy (index :read)
  - GET  /internal-api/approval_castle_verb_schedule (index :read)
  - GET  /internal-api/castle_verb_inventory_goals   (index :read)

  Real Chicago-style: real HTTP through the real main router with the
  real bearer token, real Ash actions / real Postgres rows (sandboxed),
  zero mocks. Each test names the mutant class it kills.
  """

  use XaasWeb.ConnCase

  alias Xaas.Operations.{
    ApprovalCastleVerbSchedule,
    AuditLogEntry,
    CastleVerbInventoryGoals,
    Incident,
    RouteCastleDeploy
  }

  alias Xaas.Repo

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp with_internal_api_token(conn) do
    put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
  end

  defp json_api_conn(conn) do
    conn
    |> put_req_header("accept", "application/vnd.api+json")
    |> put_req_header("content-type", "application/vnd.api+json")
  end

  # --- fixtures: real rows via the real internal write paths ---

  defp real_incident!(attrs \\ %{}) do
    inc =
      Incident
      |> Ash.Changeset.for_create(
        :create,
        %{
          org_id: "org-w984lv",
          title: "W984lv probe incident",
          region: "us-east-1",
          opened_at: DateTime.utc_now() |> DateTime.truncate(:second)
        }
        |> Map.merge(attrs)
      )
      |> Ash.create!(authorize?: false, return_notifications?: false)

    inc
  end

  defp real_audit_entry! do
    entry =
      AuditLogEntry
      |> Ash.Changeset.for_create(:create, %{
        actor_id: "w984lv-actor",
        action: "w984lv.census",
        resource_type: "internal_api_surface",
        resource_id: "w984lv",
        occurred_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
      |> Ash.create!(authorize?: false)

    entry
  end

  # Read-only generated projections have no Ash create action; a real
  # Postgres row via the real repo struct path is the real state, not a
  # double of anything.
  defp projection_row!(schema, extra \\ %{}) do
    struct!(schema, %{id: Ecto.UUID.generate(), requested_by: "w984lv-probe"})
    |> Map.merge(extra)
    |> Repo.insert!()
  end

  # --- incidents ---

  test "a. GET /internal-api/incidents (index) returns the real incident row — kills the mutant that drops the catch-all router's incidents index route",
       %{conn: conn} do
    inc = real_incident!()

    body =
      conn
      |> with_internal_api_token()
      |> json_api_conn()
      |> get("/internal-api/incidents")
      |> json_response(200)

    ids =
      body["data"]
      |> Enum.map(& &1["id"])

    assert inc.id in ids

    attrs = Enum.find(body["data"], &(&1["id"] == inc.id))["attributes"]
    assert attrs["org_id"] == "org-w984lv"
    assert attrs["title"] == "W984lv probe incident"
    assert attrs["region"] == "us-east-1"
  end

  test "a2. GET /internal-api/incidents/:id returns the exact real row; an unknown id is a real 404 — kills the mutant that breaks read routing/id scoping on the catch-all",
       %{conn: conn} do
    inc = real_incident!()

    body =
      conn
      |> with_internal_api_token()
      |> json_api_conn()
      |> get("/internal-api/incidents/#{inc.id}")
      |> json_response(200)

    assert body["data"]["id"] == inc.id
    assert body["data"]["attributes"]["status"] == "open"

    conn
    |> with_internal_api_token()
    |> json_api_conn()
    |> get("/internal-api/incidents/#{Ecto.UUID.generate()}")
    |> json_response(404)
  end

  test "a3. POST /internal-api/incidents with no resolvable org actor is fail-closed 403 (ActorOrgMatches) — kills the mutant that re-opens the create bypass on the internal-api tier",
       %{conn: conn} do
    # The internal-api scope carries no ResolveOrgActor pipeline, so no
    # request here can have a resolved org actor: the check must refuse,
    # not silently create an org-less row (the exact escalation the
    # seventeenth-pass fix closed).
    conn =
      conn
      |> with_internal_api_token()
      |> json_api_conn()
      |> post("/internal-api/incidents", %{
        "data" => %{
          "type" => "incidents",
          "attributes" => %{
            "org_id" => "org-w984lv",
            "title" => "should be refused",
            "region" => "us-east-1",
            "opened_at" => DateTime.to_iso8601(DateTime.utc_now())
          }
        }
      })

    assert conn.status == 403
  end

  # --- audit_log_entries ---

  test "b. GET /internal-api/audit_log_entries (index + read) returns the real audit row — kills the mutant that drops the audit-log read surface from the catch-all router",
       %{conn: conn} do
    entry = real_audit_entry!()

    index_body =
      conn
      |> with_internal_api_token()
      |> json_api_conn()
      |> get("/internal-api/audit_log_entries")
      |> json_response(200)

    assert Enum.any?(index_body["data"], &(&1["id"] == entry.id))

    read_body =
      conn
      |> with_internal_api_token()
      |> json_api_conn()
      |> get("/internal-api/audit_log_entries/#{entry.id}")
      |> json_response(200)

    assert read_body["data"]["id"] == entry.id
    assert read_body["data"]["attributes"]["action"] == "w984lv.census"
  end

  # --- read-only castle projections ---

  test "c. GET /internal-api/route_castle_deploy (index + read) returns the real projection row — kills the mutant that breaks the route-castle projection read surface",
       %{conn: conn} do
    row = projection_row!(RouteCastleDeploy)

    index_body =
      conn
      |> with_internal_api_token()
      |> json_api_conn()
      |> get("/internal-api/route_castle_deploy")
      |> json_response(200)

    assert Enum.any?(index_body["data"], &(&1["id"] == row.id))

    read_body =
      conn
      |> with_internal_api_token()
      |> json_api_conn()
      |> get("/internal-api/route_castle_deploy/#{row.id}")
      |> json_response(200)

    assert read_body["data"]["id"] == row.id
    # requested_by is not public? on this projection, so JSON:API omits it
    # from the rendered attributes -- the id match is the real wire shape.
    assert read_body["data"]["attributes"] != nil
  end

  test "d. GET /internal-api/approval_castle_verb_schedule (index) returns the real schedule row — kills the mutant that drops the schedule read surface",
       %{conn: conn} do
    row =
      ApprovalCastleVerbSchedule
      |> Ash.Changeset.for_create(:create, %{requested_by: "w984lv-probe"})
      |> Ash.create!(authorize?: false)

    body =
      conn
      |> with_internal_api_token()
      |> json_api_conn()
      |> get("/internal-api/approval_castle_verb_schedule")
      |> json_response(200)

    assert Enum.any?(body["data"], &(&1["id"] == row.id))
  end

  test "e. GET /internal-api/castle_verb_inventory_goals (index) returns the real goals row — kills the mutant that drops the inventory-goals read surface",
       %{conn: conn} do
    row = projection_row!(CastleVerbInventoryGoals)

    body =
      conn
      |> with_internal_api_token()
      |> json_api_conn()
      |> get("/internal-api/castle_verb_inventory_goals")
      |> json_response(200)

    assert Enum.any?(body["data"], &(&1["id"] == row.id))
  end

  # --- auth floor over the newly-courted paths ---

  test "f. no bearer on the newly-courted catch-all routes is 401 — kills the mutant that exempts the AshJsonApi catch-all from the token floor",
       %{conn: conn} do
    for path <- [
          "/internal-api/incidents",
          "/internal-api/audit_log_entries",
          "/internal-api/route_castle_deploy"
        ] do
      conn
      |> json_api_conn()
      |> get(path)
      |> json_response(401)
    end
  end
end
