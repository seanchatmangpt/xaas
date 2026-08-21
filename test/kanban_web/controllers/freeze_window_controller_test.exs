defmodule KanbanWeb.FreezeWindowControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/freeze_window` POST route (ported from platform-console's real
  `app/app/api/freeze-windows/route.ts` CRUD), real Ash-persisted rows in
  the real sandboxed Postgres (Xaas.Repo). Also covers the real link to
  `Xaas.Governance.ApprovalFreezeOverride.freeze_window_id`, the two
  resources this session found were previously conflated. No mocking.
  """
  use KanbanWeb.ConnCase

  alias Xaas.Governance.ApprovalFreezeOverride
  alias Xaas.Governance.FreezeWindow

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

  test "POST creates a real freeze window and persists the real fields", %{conn: conn} do
    org_id = "org-#{System.unique_integer([:positive])}"

    create_body = %{
      "data" => %{
        "type" => "freeze_window",
        "attributes" => %{
          "org_id" => org_id,
          "starts_at" => "2026-12-20T00:00:00Z",
          "ends_at" => "2027-01-02T00:00:00Z",
          "reason" => "holiday code freeze",
          "allow_emergency_override" => true,
          "created_by" => "owner-1"
        }
      }
    }

    resp = conn |> json_headers() |> post("/api/freeze_window", create_body)
    created = json_response(resp, 201)
    id = created["data"]["id"]

    persisted = FreezeWindow |> Ash.get!(id, authorize?: false)
    assert persisted.org_id == org_id
    assert persisted.reason == "holiday code freeze"
    assert persisted.allow_emergency_override == true
    assert persisted.created_by == "owner-1"
    assert DateTime.compare(persisted.ends_at, persisted.starts_at) == :gt
  end

  test "POST rejects ends_at before starts_at per the real ported validation", %{conn: conn} do
    org_id = "org-bad-#{System.unique_integer([:positive])}"

    create_body = %{
      "data" => %{
        "type" => "freeze_window",
        "attributes" => %{
          "org_id" => org_id,
          "starts_at" => "2026-12-20T00:00:00Z",
          "ends_at" => "2026-12-19T00:00:00Z",
          "reason" => "bad window",
          "created_by" => "owner-1"
        }
      }
    }

    resp = conn |> json_headers() |> post("/api/freeze_window", create_body)
    assert resp.status == 400

    assert FreezeWindow |> Ash.read!(authorize?: false) |> Enum.filter(&(&1.org_id == org_id)) == []
  end

  test "a real ApprovalFreezeOverride can reference a real freeze_window_id" do
    org_id = "org-link-#{System.unique_integer([:positive])}"

    window =
      FreezeWindow
      |> Ash.Changeset.for_create(:create, %{
        org_id: org_id,
        starts_at: DateTime.utc_now(),
        ends_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        reason: "active freeze",
        allow_emergency_override: true,
        created_by: "owner-1"
      })
      |> Ash.create!(authorize?: false)

    override =
      ApprovalFreezeOverride
      |> Ash.Changeset.for_create(:create, %{
        org_id: org_id,
        requested_by: "requester-1",
        freeze_window_id: window.id,
        reason: "emergency hotfix during freeze"
      })
      |> Ash.create!(authorize?: false)

    assert override.freeze_window_id == window.id
  end
end
