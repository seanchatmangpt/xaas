defmodule KanbanWeb.ApprovalDeniedPartyOverrideControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/approval_denied_party_override` POST/PATCH routes, real
  Ash-persisted rows in the real sandboxed Postgres (Xaas.Repo). No
  mocking.
  """
  use KanbanWeb.ConnCase

  alias Xaas.Governance.ApprovalDeniedPartyOverride

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

  test "POST creates a real pending override request, PATCH approves it from a distinct owner",
       %{conn: conn} do
    create_body = %{
      "data" => %{
        "type" => "approval_denied_party_override",
        "attributes" => %{
          "org_id" => "org-#{System.unique_integer([:positive])}",
          "requested_by" => "requester-1",
          "screening_record_id" => "screening-#{System.unique_integer([:positive])}",
          "decision" => "cleared_to_proceed",
          "justification" => "manual review confirmed false positive match"
        }
      }
    }

    create_resp =
      conn |> json_headers() |> post("/api/approval_denied_party_override", create_body)

    created = json_response(create_resp, 201)
    id = created["data"]["id"]

    approve_body = %{
      "data" => %{
        "type" => "approval_denied_party_override",
        "id" => id,
        "attributes" => %{"approved_by" => "owner-2"}
      }
    }

    approve_resp =
      conn
      |> json_headers()
      |> patch("/api/approval_denied_party_override/#{id}", approve_body)

    approved = json_response(approve_resp, 200)
    assert approved["data"]["attributes"]["approved_by"] == "owner-2"

    persisted = ApprovalDeniedPartyOverride |> Ash.get!(id, authorize?: false)
    assert persisted.decision == :cleared_to_proceed
    assert persisted.justification == "manual review confirmed false positive match"
  end

  test "PATCH rejects a requester approving their own override", %{conn: conn} do
    requester = "requester-self-#{System.unique_integer([:positive])}"

    change =
      ApprovalDeniedPartyOverride
      |> Ash.Changeset.for_create(:create, %{
        org_id: "org-x",
        requested_by: requester,
        screening_record_id: "screening-x",
        decision: "confirmed_blocked",
        justification: "test justification"
      })
      |> Ash.create!(authorize?: false)

    approve_body = %{
      "data" => %{
        "type" => "approval_denied_party_override",
        "id" => change.id,
        "attributes" => %{"approved_by" => requester}
      }
    }

    resp =
      conn
      |> json_headers()
      |> patch("/api/approval_denied_party_override/#{change.id}", approve_body)

    assert resp.status == 400

    persisted = ApprovalDeniedPartyOverride |> Ash.get!(change.id, authorize?: false)
    assert persisted.approved_by == nil
  end

  test "POST rejects an invalid decision enum value", %{conn: conn} do
    create_body = %{
      "data" => %{
        "type" => "approval_denied_party_override",
        "attributes" => %{
          "org_id" => "org-#{System.unique_integer([:positive])}",
          "requested_by" => "requester-1",
          "screening_record_id" => "screening-#{System.unique_integer([:positive])}",
          "decision" => "not_a_real_decision",
          "justification" => "manual review"
        }
      }
    }

    resp = conn |> json_headers() |> post("/api/approval_denied_party_override", create_body)
    assert resp.status == 400
  end
end
