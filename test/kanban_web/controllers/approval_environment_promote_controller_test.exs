defmodule KanbanWeb.ApprovalEnvironmentPromoteControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/approval_environment_promote` POST/PATCH routes (issue #20,
  ported from platform-console's real POST /api/projects/[name]/promote
  maker-checker flow), real Ash-persisted rows in the real sandboxed
  Postgres (Xaas.Repo). No mocking.
  """
  use KanbanWeb.ConnCase

  alias Xaas.Governance.ApprovalEnvironmentPromote

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

  test "POST creates a real pending promotion request, PATCH approves it from a distinct owner",
       %{conn: conn} do
    create_body = %{
      "data" => %{
        "type" => "approval_environment_promote",
        "attributes" => %{
          "org_id" => "org-#{System.unique_integer([:positive])}",
          "requested_by" => "requester-1",
          "project_name" => "checkout-service",
          "from_environment" => "staging",
          "to_environment" => "prod"
        }
      }
    }

    created =
      conn
      |> json_headers()
      |> post("/api/approval_environment_promote", create_body)
      |> json_response(201)

    id = created["data"]["id"]

    approve_body = %{
      "data" => %{
        "type" => "approval_environment_promote",
        "id" => id,
        "attributes" => %{"approved_by" => "owner-2"}
      }
    }

    approved =
      conn
      |> json_headers()
      |> patch("/api/approval_environment_promote/#{id}", approve_body)
      |> json_response(200)

    assert approved["data"]["attributes"]["approved_by"] == "owner-2"

    persisted = ApprovalEnvironmentPromote |> Ash.get!(id, authorize?: false)
    assert persisted.project_name == "checkout-service"
    assert persisted.from_environment == :staging
    assert persisted.to_environment == :prod
  end

  test "PATCH rejects a requester approving their own promotion", %{conn: conn} do
    requester = "requester-self-#{System.unique_integer([:positive])}"

    change =
      ApprovalEnvironmentPromote
      |> Ash.Changeset.for_create(:create, %{
        org_id: "org-x",
        requested_by: requester,
        project_name: "checkout-service",
        from_environment: :staging,
        to_environment: :prod
      })
      |> Ash.create!(authorize?: false)

    approve_body = %{
      "data" => %{
        "type" => "approval_environment_promote",
        "id" => change.id,
        "attributes" => %{"approved_by" => requester}
      }
    }

    resp =
      conn
      |> json_headers()
      |> patch("/api/approval_environment_promote/#{change.id}", approve_body)

    assert resp.status == 400

    persisted = ApprovalEnvironmentPromote |> Ash.get!(change.id, authorize?: false)
    assert persisted.approved_by == nil
  end

  test "POST rejects a promotion that skips a stage (dev straight to prod)", %{conn: conn} do
    create_body = %{
      "data" => %{
        "type" => "approval_environment_promote",
        "attributes" => %{
          "org_id" => "org-#{System.unique_integer([:positive])}",
          "requested_by" => "requester-1",
          "project_name" => "checkout-service",
          "from_environment" => "dev",
          "to_environment" => "prod"
        }
      }
    }

    resp = conn |> json_headers() |> post("/api/approval_environment_promote", create_body)
    assert resp.status == 400
  end
end
