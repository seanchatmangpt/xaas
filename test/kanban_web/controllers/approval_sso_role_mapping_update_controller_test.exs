defmodule KanbanWeb.ApprovalSsoRoleMappingUpdateControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/approval_sso_role_mapping_update` POST/PATCH routes (issue
  #20, ported from platform-console's real PUT /api/orgs/[id]/sso-role-mapping
  maker-checker flow), real Ash-persisted rows in the real sandboxed
  Postgres (Xaas.Repo). No mocking.
  """
  use KanbanWeb.ConnCase

  alias Xaas.Governance.ApprovalSsoRoleMappingUpdate

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

  test "POST creates a real pending mapping update, PATCH approves it from a distinct owner",
       %{conn: conn} do
    create_body = %{
      "data" => %{
        "type" => "approval_sso_role_mapping_update",
        "attributes" => %{
          "org_id" => "org-#{System.unique_integer([:positive])}",
          "requested_by" => "requester-1",
          "requested_mappings" => [
            %{"ssoGroup" => "engineering", "role" => "member"},
            %{"ssoGroup" => "platform-admins", "role" => "owner"}
          ]
        }
      }
    }

    created =
      conn
      |> json_headers()
      |> post("/api/approval_sso_role_mapping_update", create_body)
      |> json_response(201)

    id = created["data"]["id"]

    approve_body = %{
      "data" => %{
        "type" => "approval_sso_role_mapping_update",
        "id" => id,
        "attributes" => %{"approved_by" => "owner-2"}
      }
    }

    approved =
      conn
      |> json_headers()
      |> patch("/api/approval_sso_role_mapping_update/#{id}", approve_body)
      |> json_response(200)

    assert approved["data"]["attributes"]["approved_by"] == "owner-2"

    persisted = ApprovalSsoRoleMappingUpdate |> Ash.get!(id, authorize?: false)
    assert persisted.approved_by == "owner-2"

    assert persisted.requested_mappings == [
             %{"ssoGroup" => "engineering", "role" => "member"},
             %{"ssoGroup" => "platform-admins", "role" => "owner"}
           ]
  end

  test "PATCH rejects a requester approving their own mapping update", %{conn: conn} do
    requester = "requester-self-#{System.unique_integer([:positive])}"

    change =
      ApprovalSsoRoleMappingUpdate
      |> Ash.Changeset.for_create(:create, %{
        org_id: "org-x",
        requested_by: requester,
        requested_mappings: [%{"ssoGroup" => "engineering", "role" => "member"}]
      })
      |> Ash.create!(authorize?: false)

    approve_body = %{
      "data" => %{
        "type" => "approval_sso_role_mapping_update",
        "id" => change.id,
        "attributes" => %{"approved_by" => requester}
      }
    }

    resp =
      conn
      |> json_headers()
      |> patch("/api/approval_sso_role_mapping_update/#{change.id}", approve_body)

    assert resp.status == 400

    persisted = ApprovalSsoRoleMappingUpdate |> Ash.get!(change.id, authorize?: false)
    assert persisted.approved_by == nil
  end

  test "POST rejects a mapping entry with a role outside the valid OrgRole set", %{conn: conn} do
    create_body = %{
      "data" => %{
        "type" => "approval_sso_role_mapping_update",
        "attributes" => %{
          "org_id" => "org-#{System.unique_integer([:positive])}",
          "requested_by" => "requester-1",
          "requested_mappings" => [
            %{"ssoGroup" => "engineering", "role" => "superadmin"}
          ]
        }
      }
    }

    resp = conn |> json_headers() |> post("/api/approval_sso_role_mapping_update", create_body)
    assert resp.status == 400
  end
end
