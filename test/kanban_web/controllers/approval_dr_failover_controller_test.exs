defmodule KanbanWeb.ApprovalDrFailoverControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/approval_dr_failover` POST/PATCH routes (issue #20, ported
  from platform-console's POST /api/dr/initiate-failover maker-checker
  flow), real Ash-persisted rows in the real sandboxed Postgres
  (Xaas.Repo). No mocking.
  """
  use KanbanWeb.ConnCase

  alias Xaas.Governance.ApprovalDrFailover

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

  test "POST creates a real pending failover request, PATCH approves it from a distinct owner",
       %{conn: conn} do
    create_body = %{
      "data" => %{
        "type" => "approval_dr_failover",
        "attributes" => %{
          "org_id" => "org-#{System.unique_integer([:positive])}",
          "requested_by" => "requester-1",
          "from_region" => "us-east-1",
          "to_region" => "us-west-2",
          "reason" => "region degradation"
        }
      }
    }

    create_resp = conn |> json_headers() |> post("/api/approval_dr_failover", create_body)
    created = json_response(create_resp, 201)
    id = created["data"]["id"]

    approve_body = %{
      "data" => %{
        "type" => "approval_dr_failover",
        "id" => id,
        "attributes" => %{"approved_by" => "owner-2"}
      }
    }

    approve_resp = conn |> json_headers() |> patch("/api/approval_dr_failover/#{id}", approve_body)
    approved = json_response(approve_resp, 200)
    assert approved["data"]["attributes"]["approved_by"] == "owner-2"

    persisted = ApprovalDrFailover |> Ash.get!(id, authorize?: false)
    assert persisted.from_region == "us-east-1"
    assert persisted.to_region == "us-west-2"
  end

  test "PATCH rejects a requester approving their own failover", %{conn: conn} do
    requester = "requester-self-#{System.unique_integer([:positive])}"

    change =
      ApprovalDrFailover
      |> Ash.Changeset.for_create(:create, %{
        org_id: "org-x",
        requested_by: requester,
        from_region: "us-east-1",
        to_region: "us-west-2",
        reason: "test"
      })
      |> Ash.create!(authorize?: false)

    approve_body = %{
      "data" => %{
        "type" => "approval_dr_failover",
        "id" => change.id,
        "attributes" => %{"approved_by" => requester}
      }
    }

    resp = conn |> json_headers() |> patch("/api/approval_dr_failover/#{change.id}", approve_body)
    assert resp.status == 400

    persisted = ApprovalDrFailover |> Ash.get!(change.id, authorize?: false)
    assert persisted.approved_by == nil
  end
end
