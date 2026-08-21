defmodule KanbanWeb.ApprovalCmekKeyBindingControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/approval_cmek_key_binding` POST/PATCH routes (issue #20,
  ported from platform-console's PUT /api/orgs/[id]/cmek maker-checker
  flow), real Ash-persisted rows in the real sandboxed Postgres
  (Xaas.Repo). No mocking.
  """
  use KanbanWeb.ConnCase

  alias Xaas.Governance.ApprovalCmekKeyBinding

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp with_internal_api_token(conn) do
    put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
  end

  defp json_headers(conn) do
    conn
    |> with_internal_api_token()
    |> put_req_header("content-type", "application/vnd.api+json")
    |> put_req_header("accept", "application/vnd.api+json")
  end

  test "POST creates a real pending key-binding request, PATCH approves it from a distinct owner",
       %{conn: conn} do
    create_body = %{
      "data" => %{
        "type" => "approval_cmek_key_binding",
        "attributes" => %{
          "org_id" => "org-#{System.unique_integer([:positive])}",
          "requested_by" => "requester-1",
          "provider" => "aws_kms",
          "key_ref" => "arn:aws:kms:us-east-1:123456789012:key/real-key",
          "reason" => "customer-managed key required for compliance"
        }
      }
    }

    create_resp = conn |> json_headers() |> post("/api/approval_cmek_key_binding", create_body)
    created = json_response(create_resp, 201)
    id = created["data"]["id"]

    approve_body = %{
      "data" => %{
        "type" => "approval_cmek_key_binding",
        "id" => id,
        "attributes" => %{"approved_by" => "owner-2"}
      }
    }

    approve_resp =
      conn |> json_headers() |> patch("/api/approval_cmek_key_binding/#{id}", approve_body)

    approved = json_response(approve_resp, 200)
    assert approved["data"]["attributes"]["approved_by"] == "owner-2"

    persisted = ApprovalCmekKeyBinding |> Ash.get!(id, authorize?: false)
    assert persisted.provider == :aws_kms
  end

  test "PATCH rejects approval missing an approver", %{conn: conn} do
    change =
      ApprovalCmekKeyBinding
      |> Ash.Changeset.for_create(:create, %{
        org_id: "org-x",
        requested_by: "requester-1",
        provider: :gcp_kms,
        key_ref: "projects/p/locations/l/keyRings/r/cryptoKeys/k",
        reason: "test"
      })
      |> Ash.create!(authorize?: false)

    approve_body = %{
      "data" => %{
        "type" => "approval_cmek_key_binding",
        "id" => change.id,
        "attributes" => %{"approved_by" => ""}
      }
    }

    resp =
      conn |> json_headers() |> patch("/api/approval_cmek_key_binding/#{change.id}", approve_body)

    assert resp.status == 400
  end
end
