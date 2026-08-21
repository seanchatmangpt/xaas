defmodule KanbanWeb.ApprovalChangeOfControlNotifyControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/approval_change_of_control_notify` POST/PATCH routes (issue
  #20, ported from platform-console's real PUT /api/owner/change-of-control
  maker-checker flow), real Ash-persisted rows in the real sandboxed
  Postgres (Xaas.Repo). No mocking.
  """
  use KanbanWeb.ConnCase

  alias Xaas.Governance.ApprovalChangeOfControlNotify

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

  test "POST creates a real pending notification, PATCH approves it from a distinct owner",
       %{conn: conn} do
    create_body = %{
      "data" => %{
        "type" => "approval_change_of_control_notify",
        "attributes" => %{
          "org_id" => "org-#{System.unique_integer([:positive])}",
          "requested_by" => "requester-1",
          "event_type" => "acquisition",
          "description" => "Acme Corp acquiring 100% of subsidiary",
          "trigger_date" => "2026-09-15",
          "notice_window_days" => 30,
          "notification_method" => "email"
        }
      }
    }

    created =
      conn
      |> json_headers()
      |> post("/api/approval_change_of_control_notify", create_body)
      |> json_response(201)

    id = created["data"]["id"]

    approve_body = %{
      "data" => %{
        "type" => "approval_change_of_control_notify",
        "id" => id,
        "attributes" => %{"approved_by" => "owner-2"}
      }
    }

    approved =
      conn
      |> json_headers()
      |> patch("/api/approval_change_of_control_notify/#{id}", approve_body)
      |> json_response(200)

    assert approved["data"]["attributes"]["approved_by"] == "owner-2"

    persisted = ApprovalChangeOfControlNotify |> Ash.get!(id, authorize?: false)
    assert persisted.event_type == :acquisition
    assert persisted.notification_method == "email"
  end

  test "PATCH rejects a requester approving their own change-of-control notification",
       %{conn: conn} do
    requester = "requester-self-#{System.unique_integer([:positive])}"

    change =
      ApprovalChangeOfControlNotify
      |> Ash.Changeset.for_create(:create, %{
        org_id: "org-x",
        requested_by: requester,
        event_type: :merger,
        description: "test merger notification",
        trigger_date: "2026-10-01",
        notification_method: "email"
      })
      |> Ash.create!(authorize?: false)

    approve_body = %{
      "data" => %{
        "type" => "approval_change_of_control_notify",
        "id" => change.id,
        "attributes" => %{"approved_by" => requester}
      }
    }

    resp =
      conn
      |> json_headers()
      |> patch("/api/approval_change_of_control_notify/#{change.id}", approve_body)

    assert resp.status == 400

    persisted = ApprovalChangeOfControlNotify |> Ash.get!(change.id, authorize?: false)
    assert persisted.approved_by == nil
  end

  test "POST rejects an invalid event_type outside the acquisition/merger/ownership_change enum",
       %{conn: conn} do
    create_body = %{
      "data" => %{
        "type" => "approval_change_of_control_notify",
        "attributes" => %{
          "org_id" => "org-#{System.unique_integer([:positive])}",
          "requested_by" => "requester-1",
          "event_type" => "hostile_takeover",
          "description" => "not a real enum value",
          "trigger_date" => "2026-09-15",
          "notification_method" => "email"
        }
      }
    }

    resp = conn |> json_headers() |> post("/api/approval_change_of_control_notify", create_body)
    assert resp.status == 400
  end
end
