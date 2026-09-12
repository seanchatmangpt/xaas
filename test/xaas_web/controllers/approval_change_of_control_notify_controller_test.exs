defmodule XaasWeb.ApprovalChangeOfControlNotifyControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/approval_change_of_control_notify` POST/PATCH routes (issue
  #20, ported from platform-console's real PUT /api/owner/change-of-control
  maker-checker flow), real Ash-persisted rows in the real sandboxed
  Postgres (Xaas.Repo). No mocking.
  """
  use XaasWeb.ConnCase

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
