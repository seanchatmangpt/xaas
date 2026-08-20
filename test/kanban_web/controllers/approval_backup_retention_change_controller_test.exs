defmodule KanbanWeb.ApprovalBackupRetentionChangeControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/approval_backup_retention_change/:id` PATCH route (issue #20,
  ported from platform-console's PUT /api/orgs/[id]/backup-policy
  maker-checker flow), real Ash.create!/Ash.Changeset rows in the real
  sandboxed Postgres (Xaas.Repo), asserting on the real decoded JSON
  response body and the real persisted state. No mocking of
  ApprovalBackupRetentionChange, its validation, or the DB.
  """
  use KanbanWeb.ConnCase

  alias Xaas.Governance.ApprovalBackupRetentionChange

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp with_internal_api_token(conn) do
    put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
  end

  defp create_pending!(requested_by) do
    ApprovalBackupRetentionChange
    |> Ash.Changeset.for_create(:create, %{
      org_id: "org-#{System.unique_integer([:positive])}",
      requested_by: requested_by,
      requested_retention_days: 90
    })
    |> Ash.create!(authorize?: false)
  end

  test "PATCH .../:id accepts a real approval from a distinct owner", %{conn: conn} do
    change = create_pending!("requester-#{System.unique_integer([:positive])}")

    body = %{
      "data" => %{
        "type" => "approval_backup_retention_change",
        "id" => change.id,
        "attributes" => %{"approved_by" => "owner-real-1"}
      }
    }

    conn =
      conn
      |> with_internal_api_token()
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_backup_retention_change/#{change.id}", body)

    response = json_response(conn, 200)
    assert response["data"]["attributes"]["approved_by"] == "owner-real-1"

    persisted = ApprovalBackupRetentionChange |> Ash.get!(change.id, authorize?: false)
    assert persisted.approved_by == "owner-real-1"
    assert persisted.requested_retention_days == 90
  end

  test "PATCH .../:id rejects approval missing an approver", %{conn: conn} do
    change = create_pending!("requester-#{System.unique_integer([:positive])}")

    body = %{
      "data" => %{
        "type" => "approval_backup_retention_change",
        "id" => change.id,
        "attributes" => %{"approved_by" => ""}
      }
    }

    conn =
      conn
      |> with_internal_api_token()
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_backup_retention_change/#{change.id}", body)

    assert conn.status == 400

    persisted = ApprovalBackupRetentionChange |> Ash.get!(change.id, authorize?: false)
    assert persisted.approved_by == nil
  end

  test "PATCH .../:id rejects the requester approving their own change", %{conn: conn} do
    requester = "requester-#{System.unique_integer([:positive])}"
    change = create_pending!(requester)

    body = %{
      "data" => %{
        "type" => "approval_backup_retention_change",
        "id" => change.id,
        "attributes" => %{"approved_by" => requester}
      }
    }

    conn =
      conn
      |> with_internal_api_token()
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_backup_retention_change/#{change.id}", body)

    assert conn.status == 400

    persisted = ApprovalBackupRetentionChange |> Ash.get!(change.id, authorize?: false)
    assert persisted.approved_by == nil
  end

  test "PATCH .../:id rejects requests without the internal API token", %{conn: conn} do
    change = create_pending!("requester-#{System.unique_integer([:positive])}")

    body = %{
      "data" => %{
        "type" => "approval_backup_retention_change",
        "id" => change.id,
        "attributes" => %{"approved_by" => "owner-real-2"}
      }
    }

    conn =
      conn
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_backup_retention_change/#{change.id}", body)

    assert conn.status == 401

    persisted = ApprovalBackupRetentionChange |> Ash.get!(change.id, authorize?: false)
    assert persisted.approved_by == nil
  end
end
