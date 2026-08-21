defmodule KanbanWeb.ResolveOrgActorTest do
  @moduledoc """
  Real Chicago-style tests proving cross-org isolation for the 4 real
  non-global-multitenancy governance resources
  (`ApprovalDrFailover`/`ApprovalLegalHoldRelease`/
  `ApprovalDeploymentQuarantine`/`ApprovalBackupRetentionChange`), wired
  through the real `KanbanWeb.Plugs.ResolveOrgActor` plug and Ash's real
  attribute-strategy multitenancy (`global? false`). Real Phoenix
  ConnCase HTTP requests against the real `/api` routes, real Ash-
  persisted rows in the real sandboxed Postgres (Xaas.Repo). No mocking.

  Uses `ApprovalDrFailover` as the representative resource (same
  multitenancy/plug wiring as the other 3) plus one smoke assertion per
  sibling resource so the isolation proof isn't accidentally
  resource-specific.
  """
  use KanbanWeb.ConnCase

  alias Xaas.Accounts.Org
  alias Xaas.Governance.ApprovalDeploymentQuarantine
  alias Xaas.Governance.ApprovalDrFailover
  alias Xaas.Governance.ApprovalLegalHoldRelease
  alias Xaas.Operations.Incident

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp with_internal_api_token(conn) do
    put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
  end

  defp json_headers(conn, org_id) do
    conn
    |> with_internal_api_token()
    |> put_req_header("content-type", "application/vnd.api+json")
    |> put_req_header("accept", "application/vnd.api+json")
    |> put_req_header("x-org-id", org_id)
  end

  defp real_org! do
    Org
    |> Ash.Changeset.for_create(:create, %{
      name: "Org #{System.unique_integer([:positive])}",
      slug: "org-#{System.unique_integer([:positive])}"
    })
    |> Ash.create!(authorize?: false)
  end

  defp open_incident!(org_slug, region) do
    Incident
    |> Ash.Changeset.for_create(:create, %{
      org_id: org_slug,
      title: "Test incident for #{region}",
      region: region,
      opened_at: DateTime.utc_now()
    })
    |> Ash.create!(authorize?: false)
  end

  defp create_dr_failover!(org_slug, requested_by) do
    ApprovalDrFailover
    |> Ash.Changeset.for_create(
      :create,
      %{
        org_id: org_slug,
        requested_by: requested_by,
        from_region: "us-east-1",
        to_region: "us-west-2",
        reason: "cross-org isolation test"
      },
      tenant: org_slug
    )
    |> Ash.create!(authorize?: false)
  end

  test "GET rejects a request with no X-Org-Id header (400, not silently allowed)", %{conn: conn} do
    org_a = real_org!()
    open_incident!(org_a.slug, "us-east-1")
    row = create_dr_failover!(org_a.slug, "requester-a")

    resp =
      conn
      |> with_internal_api_token()
      |> put_req_header("accept", "application/vnd.api+json")
      |> get("/api/approval_dr_failover/#{row.id}")

    assert resp.status == 400
    assert json_response(resp, 400)["error"] == "missing_org_id"
  end

  test "GET rejects a request with an X-Org-Id that resolves to no real Org (404)", %{conn: conn} do
    org_a = real_org!()
    open_incident!(org_a.slug, "us-east-1")
    row = create_dr_failover!(org_a.slug, "requester-a")

    resp =
      conn
      |> with_internal_api_token()
      |> put_req_header("accept", "application/vnd.api+json")
      |> put_req_header("x-org-id", "does-not-exist-#{System.unique_integer([:positive])}")
      |> get("/api/approval_dr_failover/#{row.id}")

    assert resp.status == 404
    assert json_response(resp, 404)["error"] == "org_not_found"
  end

  test "org A, acting as org A, can real-read its own row via the tenant-scoped route", %{
    conn: conn
  } do
    org_a = real_org!()
    open_incident!(org_a.slug, "us-east-1")
    row_a = create_dr_failover!(org_a.slug, "requester-a")

    resp =
      conn
      |> json_headers(org_a.slug)
      |> get("/api/approval_dr_failover/#{row_a.id}")

    body = json_response(resp, 200)
    assert body["data"]["id"] == row_a.id
    assert body["data"]["attributes"]["from_region"] == "us-east-1"
  end

  test "org A, acting as org A, CANNOT real-read org B's row via the tenant-scoped route (real 404, not silently empty/allowed)",
       %{conn: conn} do
    org_a = real_org!()
    org_b = real_org!()
    open_incident!(org_b.slug, "us-east-1")
    row_b = create_dr_failover!(org_b.slug, "requester-b")

    resp =
      conn
      |> json_headers(org_a.slug)
      |> get("/api/approval_dr_failover/#{row_b.id}")

    assert resp.status == 404
  end

  test "org A, acting as org A, CANNOT real-approve org B's row via the tenant-scoped route",
       %{conn: conn} do
    org_a = real_org!()
    org_b = real_org!()
    open_incident!(org_b.slug, "us-east-1")
    row_b = create_dr_failover!(org_b.slug, "requester-b")

    approve_body = %{
      "data" => %{
        "type" => "approval_dr_failover",
        "id" => row_b.id,
        "attributes" => %{"approved_by" => "owner-a"}
      }
    }

    resp =
      conn
      |> json_headers(org_a.slug)
      |> patch("/api/approval_dr_failover/#{row_b.id}", approve_body)

    assert resp.status == 404

    persisted = ApprovalDrFailover |> Ash.get!(row_b.id, authorize?: false, tenant: org_b.slug)
    assert persisted.approved_by == nil
  end

  test "org A's index only real-lists org A's rows, never org B's", %{conn: conn} do
    org_a = real_org!()
    org_b = real_org!()
    open_incident!(org_a.slug, "us-east-1")
    open_incident!(org_b.slug, "us-east-1")

    row_a = create_dr_failover!(org_a.slug, "requester-a")
    _row_b = create_dr_failover!(org_b.slug, "requester-b")

    resp = conn |> json_headers(org_a.slug) |> get("/api/approval_dr_failover")
    body = json_response(resp, 200)
    ids = Enum.map(body["data"], & &1["id"])

    assert row_a.id in ids
    assert length(ids) == 1
  end

  # Smoke coverage on the other 3 tenant-scoped resources, proving the
  # same real isolation isn't specific to ApprovalDrFailover.

  test "cross-org isolation also holds for ApprovalLegalHoldRelease", %{conn: conn} do
    org_a = real_org!()
    org_b = real_org!()

    row_b =
      ApprovalLegalHoldRelease
      |> Ash.Changeset.for_create(
        :create,
        %{
          org_id: org_b.slug,
          requested_by: "requester-b",
          hold_id: "hold-x",
          release_reason: "test release"
        },
        tenant: org_b.slug
      )
      |> Ash.create!(authorize?: false)

    resp =
      conn
      |> json_headers(org_a.slug)
      |> get("/api/approval_legal_hold_release/#{row_b.id}")

    assert resp.status == 404
  end

  test "cross-org isolation also holds for ApprovalDeploymentQuarantine", %{conn: conn} do
    org_a = real_org!()
    org_b = real_org!()

    row_b =
      ApprovalDeploymentQuarantine
      |> Ash.Changeset.for_create(
        :create,
        %{
          org_id: org_b.slug,
          requested_by: "requester-b",
          deployment_name: "billing-worker",
          environment: "staging",
          reason: "manual_hold"
        },
        tenant: org_b.slug
      )
      |> Ash.create!(authorize?: false)

    resp =
      conn
      |> json_headers(org_a.slug)
      |> get("/api/approval_deployment_quarantine/#{row_b.id}")

    assert resp.status == 404
  end

  test "cross-org isolation also holds for ApprovalBackupRetentionChange", %{conn: conn} do
    org_a = real_org!()
    org_b = real_org!()

    row_b =
      Xaas.Governance.ApprovalBackupRetentionChange
      |> Ash.Changeset.for_create(
        :create,
        %{
          org_id: org_b.slug,
          requested_by: "requester-b",
          requested_retention_days: 30,
          tier: :pro
        },
        tenant: org_b.slug
      )
      |> Ash.create!(authorize?: false)

    resp =
      conn
      |> json_headers(org_a.slug)
      |> get("/api/approval_backup_retention_change/#{row_b.id}")

    assert resp.status == 404
  end
end
