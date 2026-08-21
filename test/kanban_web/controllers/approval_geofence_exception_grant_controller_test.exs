defmodule KanbanWeb.ApprovalGeofenceExceptionGrantControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/approval_geofence_exception_grant` POST/PATCH routes, ported
  from platform-console's real POST /api/owner/geofence-policy
  `geofence.exception.grant` maker-checker flow, real Ash-persisted rows in
  the real sandboxed Postgres (Xaas.Repo). No mocking.
  """
  use KanbanWeb.ConnCase

  alias Xaas.Governance.ApprovalGeofenceExceptionGrant

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp json_headers(conn) do
    conn
    |> put_req_header("authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
    |> put_req_header("content-type", "application/vnd.api+json")
    |> put_req_header("accept", "application/vnd.api+json")
  end

  test "POST creates a real pending geofence exception grant, PATCH approves it from a distinct owner",
       %{conn: conn} do
    create_body = %{
      "data" => %{
        "type" => "approval_geofence_exception_grant",
        "attributes" => %{
          "org_id" => "org-#{System.unique_integer([:positive])}",
          "requested_by" => "requester-1",
          "identifier_or_cidr" => "203.0.113.0/24",
          "reason" => "temporary vendor access from restricted region",
          "ttl_hours" => 24
        }
      }
    }

    created =
      conn
      |> json_headers()
      |> post("/api/approval_geofence_exception_grant", create_body)
      |> json_response(201)

    id = created["data"]["id"]

    approve_body = %{
      "data" => %{
        "type" => "approval_geofence_exception_grant",
        "id" => id,
        "attributes" => %{"approved_by" => "owner-2"}
      }
    }

    approved =
      conn
      |> json_headers()
      |> patch("/api/approval_geofence_exception_grant/#{id}", approve_body)
      |> json_response(200)

    assert approved["data"]["attributes"]["approved_by"] == "owner-2"

    persisted = ApprovalGeofenceExceptionGrant |> Ash.get!(id, authorize?: false)
    assert persisted.identifier_or_cidr == "203.0.113.0/24"
    assert persisted.ttl_hours == 24
  end

  test "PATCH rejects a requester approving their own geofence exception grant", %{conn: conn} do
    requester = "requester-self-#{System.unique_integer([:positive])}"

    change =
      ApprovalGeofenceExceptionGrant
      |> Ash.Changeset.for_create(:create, %{
        org_id: "org-x",
        requested_by: requester,
        identifier_or_cidr: "198.51.100.0/24",
        reason: "test",
        ttl_hours: 12
      })
      |> Ash.create!(authorize?: false)

    approve_body = %{
      "data" => %{
        "type" => "approval_geofence_exception_grant",
        "id" => change.id,
        "attributes" => %{"approved_by" => requester}
      }
    }

    resp =
      conn
      |> json_headers()
      |> patch("/api/approval_geofence_exception_grant/#{change.id}", approve_body)

    assert resp.status == 400

    persisted = ApprovalGeofenceExceptionGrant |> Ash.get!(change.id, authorize?: false)
    assert persisted.approved_by == nil
  end

  test "POST rejects a ttl_hours outside the bounded one-week range", %{conn: conn} do
    create_body = %{
      "data" => %{
        "type" => "approval_geofence_exception_grant",
        "attributes" => %{
          "org_id" => "org-#{System.unique_integer([:positive])}",
          "requested_by" => "requester-1",
          "identifier_or_cidr" => "203.0.113.0/24",
          "reason" => "exceeds max ttl",
          "ttl_hours" => 200
        }
      }
    }

    resp = conn |> json_headers() |> post("/api/approval_geofence_exception_grant", create_body)
    assert resp.status == 400
  end
end
