defmodule KanbanWeb.ApprovalBreakGlassJustificationReviewControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/approval_break_glass_justification_review` POST/PATCH routes
  (issue #20, ported from platform-console's real POST
  /api/support/break-glass/[grantId]/justify two-person-integrity flow),
  real Ash-persisted rows in the real sandboxed Postgres (Xaas.Repo). No
  mocking.
  """
  use KanbanWeb.ConnCase

  alias Xaas.Governance.ApprovalBreakGlassJustificationReview

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

  test "POST creates a real pending break-glass justification review, PATCH approves it from a distinct admin",
       %{conn: conn} do
    create_body = %{
      "data" => %{
        "type" => "approval_break_glass_justification_review",
        "attributes" => %{
          "org_id" => "org-#{System.unique_integer([:positive])}",
          "requested_by" => "oncall-engineer-1",
          "grant_id" => "grant-#{System.unique_integer([:positive])}",
          "justification" => "Restarted payments-db primary during outage INC-4821 to restore writes."
        }
      }
    }

    create_resp =
      conn |> json_headers() |> post("/api/approval_break_glass_justification_review", create_body)

    created = json_response(create_resp, 201)
    id = created["data"]["id"]

    approve_body = %{
      "data" => %{
        "type" => "approval_break_glass_justification_review",
        "id" => id,
        "attributes" => %{"approved_by" => "platform-admin-2"}
      }
    }

    approve_resp =
      conn
      |> json_headers()
      |> patch("/api/approval_break_glass_justification_review/#{id}", approve_body)

    approved = json_response(approve_resp, 200)
    assert approved["data"]["attributes"]["approved_by"] == "platform-admin-2"

    persisted = ApprovalBreakGlassJustificationReview |> Ash.get!(id, authorize?: false)
    assert persisted.grant_id != nil
    assert persisted.justification == "Restarted payments-db primary during outage INC-4821 to restore writes."
  end

  test "PATCH rejects an on-call engineer approving their own justification review", %{conn: conn} do
    requester = "oncall-self-#{System.unique_integer([:positive])}"

    change =
      ApprovalBreakGlassJustificationReview
      |> Ash.Changeset.for_create(:create, %{
        org_id: "org-x",
        requested_by: requester,
        grant_id: "grant-self-review",
        justification: "Rotated compromised deploy key after suspected leak."
      })
      |> Ash.create!(authorize?: false)

    approve_body = %{
      "data" => %{
        "type" => "approval_break_glass_justification_review",
        "id" => change.id,
        "attributes" => %{"approved_by" => requester}
      }
    }

    resp =
      conn
      |> json_headers()
      |> patch("/api/approval_break_glass_justification_review/#{change.id}", approve_body)

    assert resp.status == 400

    persisted = ApprovalBreakGlassJustificationReview |> Ash.get!(change.id, authorize?: false)
    assert persisted.approved_by == nil
  end

  test "PATCH rejects approval when approved_by is missing", %{conn: conn} do
    change =
      ApprovalBreakGlassJustificationReview
      |> Ash.Changeset.for_create(:create, %{
        org_id: "org-x",
        requested_by: "oncall-engineer-missing-approver",
        grant_id: "grant-missing-approver",
        justification: "Manually failed over cache cluster to clear a hot key."
      })
      |> Ash.create!(authorize?: false)

    approve_body = %{
      "data" => %{
        "type" => "approval_break_glass_justification_review",
        "id" => change.id,
        "attributes" => %{"approved_by" => ""}
      }
    }

    resp =
      conn
      |> json_headers()
      |> patch("/api/approval_break_glass_justification_review/#{change.id}", approve_body)

    assert resp.status == 400

    persisted = ApprovalBreakGlassJustificationReview |> Ash.get!(change.id, authorize?: false)
    assert persisted.approved_by == nil
  end
end
