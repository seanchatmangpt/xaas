defmodule KanbanWeb.RouteProjectsBackupsControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/route_projects_backups` POST route (ported from
  platform-console's `POST /api/orgs/[id]/backups`), real Ash-persisted
  rows in the real sandboxed Postgres (Xaas.Repo). No mocking.
  """
  use KanbanWeb.ConnCase

  alias Xaas.Platform.RouteProjectsBackups

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

  test "POST creates a real backup record with real fields", %{conn: conn} do
    org_id = "org-#{System.unique_integer([:positive])}"
    taken_at = DateTime.utc_now() |> DateTime.truncate(:second)
    retain_until = DateTime.add(taken_at, 30, :day)

    create_body = %{
      "data" => %{
        "type" => "route_projects_backups",
        "attributes" => %{
          "org_id" => org_id,
          "namespace" => "ns-#{org_id}",
          "project_name" => "my-real-project",
          "job_name" => "backup-job-1",
          "taken_at" => DateTime.to_iso8601(taken_at),
          "size_bytes" => 0,
          "retain_until" => DateTime.to_iso8601(retain_until)
        }
      }
    }

    resp = conn |> json_headers() |> post("/api/route_projects_backups", create_body)
    created = json_response(resp, 201)
    id = created["data"]["id"]

    persisted = RouteProjectsBackups |> Ash.get!(id, authorize?: false)
    assert persisted.org_id == org_id
    assert persisted.namespace == "ns-#{org_id}"
    assert persisted.project_name == "my-real-project"
    assert persisted.job_name == "backup-job-1"
    assert persisted.taken_at == taken_at
    assert persisted.size_bytes == 0
    assert persisted.retain_until == retain_until
    assert persisted.status == :pending
  end

  test "POST rejects a real invalid project_name", %{conn: conn} do
    org_id = "org-invalid-#{System.unique_integer([:positive])}"
    taken_at = DateTime.utc_now() |> DateTime.truncate(:second)
    retain_until = DateTime.add(taken_at, 30, :day)

    create_body = %{
      "data" => %{
        "type" => "route_projects_backups",
        "attributes" => %{
          "org_id" => org_id,
          "namespace" => "ns-#{org_id}",
          "project_name" => "   ",
          "job_name" => "backup-job-1",
          "taken_at" => DateTime.to_iso8601(taken_at),
          "size_bytes" => 0,
          "retain_until" => DateTime.to_iso8601(retain_until)
        }
      }
    }

    resp = conn |> json_headers() |> post("/api/route_projects_backups", create_body)
    assert resp.status == 400
  end
end
