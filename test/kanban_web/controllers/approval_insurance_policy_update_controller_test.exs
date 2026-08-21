defmodule KanbanWeb.ApprovalInsurancePolicyUpdateControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/approval_insurance_policy_update` POST/PATCH routes (issue
  #20, ported from platform-console's real PUT
  /api/owner/insurance-attestation maker-checker flow), real Ash-persisted
  rows in the real sandboxed Postgres (Xaas.Repo). No mocking.
  """
  use KanbanWeb.ConnCase

  alias Xaas.Governance.ApprovalInsurancePolicyUpdate

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

  test "POST creates a real pending policy update, PATCH approves it from a distinct owner",
       %{conn: conn} do
    create_body = %{
      "data" => %{
        "type" => "approval_insurance_policy_update",
        "attributes" => %{
          "org_id" => "org-#{System.unique_integer([:positive])}",
          "requested_by" => "requester-1",
          "coverage_type" => "cyber",
          "carrier" => "Chubb",
          "policy_number" => "POL-2026-0042",
          "coverage_limit_usd" => "5000000.00",
          "effective_date" => "2026-09-01",
          "expiry_date" => "2027-09-01",
          "am_best_rating" => "A++"
        }
      }
    }

    create_resp =
      conn |> json_headers() |> post("/api/approval_insurance_policy_update", create_body)

    created = json_response(create_resp, 201)
    id = created["data"]["id"]

    approve_body = %{
      "data" => %{
        "type" => "approval_insurance_policy_update",
        "id" => id,
        "attributes" => %{"approved_by" => "owner-2"}
      }
    }

    approve_resp =
      conn
      |> json_headers()
      |> patch("/api/approval_insurance_policy_update/#{id}", approve_body)

    approved = json_response(approve_resp, 200)
    assert approved["data"]["attributes"]["approved_by"] == "owner-2"

    persisted = ApprovalInsurancePolicyUpdate |> Ash.get!(id, authorize?: false)
    assert persisted.carrier == "Chubb"
    assert persisted.policy_number == "POL-2026-0042"
  end

  test "PATCH rejects a requester approving their own policy update", %{conn: conn} do
    requester = "requester-self-#{System.unique_integer([:positive])}"

    change =
      ApprovalInsurancePolicyUpdate
      |> Ash.Changeset.for_create(:create, %{
        org_id: "org-x",
        requested_by: requester,
        coverage_type: :general_liability,
        carrier: "Travelers",
        policy_number: "POL-2026-0099",
        coverage_limit_usd: Decimal.new("1000000.00"),
        effective_date: ~D[2026-09-01],
        expiry_date: ~D[2027-09-01]
      })
      |> Ash.create!(authorize?: false)

    approve_body = %{
      "data" => %{
        "type" => "approval_insurance_policy_update",
        "id" => change.id,
        "attributes" => %{"approved_by" => requester}
      }
    }

    resp =
      conn
      |> json_headers()
      |> patch("/api/approval_insurance_policy_update/#{change.id}", approve_body)

    assert resp.status == 400

    persisted = ApprovalInsurancePolicyUpdate |> Ash.get!(change.id, authorize?: false)
    assert persisted.approved_by == nil
  end

  test "POST rejects when expiry_date is not after effective_date", %{conn: conn} do
    create_body = %{
      "data" => %{
        "type" => "approval_insurance_policy_update",
        "attributes" => %{
          "org_id" => "org-#{System.unique_integer([:positive])}",
          "requested_by" => "requester-1",
          "coverage_type" => "errors_omissions",
          "carrier" => "AIG",
          "policy_number" => "POL-2026-0100",
          "coverage_limit_usd" => "2500000.00",
          "effective_date" => "2026-09-01",
          "expiry_date" => "2026-09-01"
        }
      }
    }

    resp = conn |> json_headers() |> post("/api/approval_insurance_policy_update", create_body)
    assert resp.status == 400
  end
end
