defmodule KanbanWeb.ApprovalLeRequestRespondControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/approval_le_request_respond` POST/PATCH routes, ported from
  platform-console's POST /api/internal/le-requests + PUT
  /api/owner/le-requests maker-checker flow, real Ash-persisted rows in the
  real sandboxed Postgres (Xaas.Repo). No mocking.
  """
  use KanbanWeb.ConnCase

  alias Xaas.Governance.ApprovalLeRequestRespond

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

  test "POST creates a real pending LE request, PATCH approves it from a distinct owner",
       %{conn: conn} do
    create_body = %{
      "data" => %{
        "type" => "approval_le_request_respond",
        "attributes" => %{
          "org_id" => "org-#{System.unique_integer([:positive])}",
          "requested_by" => "requester-1",
          "request_type" => "subpoena",
          "requesting_authority" => "FBI",
          "jurisdiction" => "US-NY",
          "summary" => "request for account metadata",
          "reference_number" => "REF-12345"
        }
      }
    }

    created =
      conn
      |> json_headers()
      |> post("/api/approval_le_request_respond", create_body)
      |> json_response(201)

    id = created["data"]["id"]

    approve_body = %{
      "data" => %{
        "type" => "approval_le_request_respond",
        "id" => id,
        "attributes" => %{
          "approved_by" => "owner-2",
          "status" => "disclosed",
          "response_summary" => "provided metadata per valid subpoena"
        }
      }
    }

    approved =
      conn
      |> json_headers()
      |> patch("/api/approval_le_request_respond/#{id}", approve_body)
      |> json_response(200)

    assert approved["data"]["attributes"]["approved_by"] == "owner-2"

    persisted = ApprovalLeRequestRespond |> Ash.get!(id, authorize?: false)
    assert persisted.requesting_authority == "FBI"
    assert persisted.status == :disclosed
  end

  test "PATCH rejects a requester approving their own logged request", %{conn: conn} do
    requester = "requester-self-#{System.unique_integer([:positive])}"

    change =
      ApprovalLeRequestRespond
      |> Ash.Changeset.for_create(:create, %{
        org_id: "org-x",
        requested_by: requester,
        request_type: :warrant,
        requesting_authority: "DEA",
        jurisdiction: "US-CA",
        summary: "request for records"
      })
      |> Ash.create!(authorize?: false)

    approve_body = %{
      "data" => %{
        "type" => "approval_le_request_respond",
        "id" => change.id,
        "attributes" => %{"approved_by" => requester, "status" => "disclosed"}
      }
    }

    resp =
      conn
      |> json_headers()
      |> patch("/api/approval_le_request_respond/#{change.id}", approve_body)

    assert resp.status == 400

    persisted = ApprovalLeRequestRespond |> Ash.get!(change.id, authorize?: false)
    assert persisted.approved_by == nil
  end

  test "PATCH rejects when approved_by is missing entirely", %{conn: conn} do
    requester = "requester-#{System.unique_integer([:positive])}"

    change =
      ApprovalLeRequestRespond
      |> Ash.Changeset.for_create(:create, %{
        org_id: "org-x",
        requested_by: requester,
        request_type: :court_order,
        requesting_authority: "US Marshals",
        jurisdiction: "US-TX",
        summary: "request for logs"
      })
      |> Ash.create!(authorize?: false)

    approve_body = %{
      "data" => %{
        "type" => "approval_le_request_respond",
        "id" => change.id,
        "attributes" => %{"status" => "disclosed"}
      }
    }

    resp =
      conn
      |> json_headers()
      |> patch("/api/approval_le_request_respond/#{change.id}", approve_body)

    assert resp.status == 400

    persisted = ApprovalLeRequestRespond |> Ash.get!(change.id, authorize?: false)
    assert persisted.approved_by == nil
  end
end
