defmodule XaasWeb.ApprovalSsoRoleMappingUpdateControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/approval_sso_role_mapping_update` POST/PATCH routes (issue
  #20, ported from platform-console's real PUT /api/orgs/[id]/sso-role-mapping
  maker-checker flow), real Ash-persisted rows in the real sandboxed
  Postgres (Xaas.Repo). No mocking.
  """
  use XaasWeb.ConnCase

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
