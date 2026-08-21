defmodule KanbanWeb.ApprovalLegalHoldReleaseControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/approval_legal_hold_release` POST/PATCH routes, ported from
  platform-console's real `PUT /api/owner/legal-hold` maker-checker flow,
  real Ash-persisted rows in the real sandboxed Postgres (Xaas.Repo). No
  mocking.
  """
  use KanbanWeb.ConnCase

  alias Xaas.Accounts.Org
  alias Xaas.Governance.ApprovalLegalHoldRelease

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp with_internal_api_token(conn) do
    put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
  end

  # Real, required since this resource's real Ash-core multitenancy
  # wiring: org_id is now a real FK to orgs.slug, so every test needs a
  # real Org row to reference, not just a made-up string.
  defp real_org_slug! do
    Org
    |> Ash.Changeset.for_create(:create, %{
      name: "Test Org",
      slug: "org-#{System.unique_integer([:positive])}"
    })
    |> Ash.create!(authorize?: false)
    |> Map.fetch!(:slug)
  end

  defp json_headers(conn, org_id) do
    conn
    |> with_internal_api_token()
    |> put_req_header("content-type", "application/vnd.api+json")
    |> put_req_header("accept", "application/vnd.api+json")
    |> put_req_header("x-org-id", org_id)
  end

  test "POST creates a real pending legal hold release, PATCH approves it from a distinct owner",
       %{conn: conn} do
    org_id = real_org_slug!()

    create_body = %{
      "data" => %{
        "type" => "approval_legal_hold_release",
        "attributes" => %{
          "org_id" => org_id,
          "requested_by" => "owner-1",
          "hold_id" => "hold-#{System.unique_integer([:positive])}",
          "release_reason" => "litigation concluded, hold no longer required"
        }
      }
    }

    create_resp =
      conn |> json_headers(org_id) |> post("/api/approval_legal_hold_release", create_body)

    created = json_response(create_resp, 201)
    id = created["data"]["id"]

    approve_body = %{
      "data" => %{
        "type" => "approval_legal_hold_release",
        "id" => id,
        "attributes" => %{"approved_by" => "owner-2"}
      }
    }

    approve_resp =
      conn
      |> json_headers(org_id)
      |> patch("/api/approval_legal_hold_release/#{id}", approve_body)

    approved = json_response(approve_resp, 200)
    assert approved["data"]["attributes"]["approved_by"] == "owner-2"

    persisted = ApprovalLegalHoldRelease |> Ash.get!(id, authorize?: false, tenant: org_id)
    assert persisted.release_reason == "litigation concluded, hold no longer required"
  end

  test "PATCH rejects an owner approving their own legal hold release", %{conn: conn} do
    requester = "owner-self-#{System.unique_integer([:positive])}"
    org_id = real_org_slug!()

    change =
      ApprovalLegalHoldRelease
      |> Ash.Changeset.for_create(:create, %{
        org_id: org_id,
        requested_by: requester,
        hold_id: "hold-x",
        release_reason: "test release"
      }, tenant: org_id)
      |> Ash.create!(authorize?: false)

    approve_body = %{
      "data" => %{
        "type" => "approval_legal_hold_release",
        "id" => change.id,
        "attributes" => %{"approved_by" => requester}
      }
    }

    resp =
      conn
      |> json_headers(org_id)
      |> patch("/api/approval_legal_hold_release/#{change.id}", approve_body)

    assert resp.status == 400

    persisted = ApprovalLegalHoldRelease |> Ash.get!(change.id, authorize?: false, tenant: org_id)
    assert persisted.approved_by == nil
  end

  test "PATCH rejects when approved_by is missing", %{conn: conn} do
    requester = "owner-missing-#{System.unique_integer([:positive])}"
    org_id = real_org_slug!()

    change =
      ApprovalLegalHoldRelease
      |> Ash.Changeset.for_create(:create, %{
        org_id: org_id,
        requested_by: requester,
        hold_id: "hold-y",
        release_reason: "test release"
      }, tenant: org_id)
      |> Ash.create!(authorize?: false)

    approve_body = %{
      "data" => %{
        "type" => "approval_legal_hold_release",
        "id" => change.id,
        "attributes" => %{"approved_by" => ""}
      }
    }

    resp =
      conn
      |> json_headers(org_id)
      |> patch("/api/approval_legal_hold_release/#{change.id}", approve_body)

    assert resp.status == 400

    persisted = ApprovalLegalHoldRelease |> Ash.get!(change.id, authorize?: false, tenant: org_id)
    assert persisted.approved_by == nil
  end
end
