defmodule KanbanWeb.ApprovalDsarErasureControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/approval_dsar_erasure` POST/PATCH routes (issue #20, ported
  from platform-console's POST /api/privacy/request-erasure maker-checker
  flow), real Ash-persisted rows in the real sandboxed Postgres
  (Xaas.Repo). No mocking.
  """
  use KanbanWeb.ConnCase

  alias Xaas.Governance.ApprovalDsarErasure

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

  test "POST creates a real pending erasure request, PATCH approves it from a distinct owner",
       %{conn: conn} do
    create_body = %{
      "data" => %{
        "type" => "approval_dsar_erasure",
        "attributes" => %{
          "org_id" => "org-#{System.unique_integer([:positive])}",
          "requested_by" => "requester-1",
          "subject_email" => "subject@example.com"
        }
      }
    }

    create_resp = conn |> json_headers() |> post("/api/approval_dsar_erasure", create_body)
    created = json_response(create_resp, 201)
    id = created["data"]["id"]

    approve_body = %{
      "data" => %{
        "type" => "approval_dsar_erasure",
        "id" => id,
        "attributes" => %{"approved_by" => "owner-2"}
      }
    }

    approve_resp = conn |> json_headers() |> patch("/api/approval_dsar_erasure/#{id}", approve_body)
    approved = json_response(approve_resp, 200)
    assert approved["data"]["attributes"]["approved_by"] == "owner-2"

    persisted = ApprovalDsarErasure |> Ash.get!(id, authorize?: false)
    assert persisted.subject_email == "subject@example.com"
  end

  test "POST rejects a real malformed email (ported EMAIL_RE)", %{conn: conn} do
    create_body = %{
      "data" => %{
        "type" => "approval_dsar_erasure",
        "attributes" => %{
          "org_id" => "org-#{System.unique_integer([:positive])}",
          "requested_by" => "requester-1",
          "subject_email" => "not-an-email"
        }
      }
    }

    resp = conn |> json_headers() |> post("/api/approval_dsar_erasure", create_body)
    assert resp.status == 400
  end
end
