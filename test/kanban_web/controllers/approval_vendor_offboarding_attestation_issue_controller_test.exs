defmodule KanbanWeb.ApprovalVendorOffboardingAttestationIssueControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/approval_vendor_offboarding_attestation_issue` POST/PATCH
  routes, ported from platform-console's real POST /api/owner/vendor-
  offboarding maker-checker flow, real Ash-persisted rows in the real
  sandboxed Postgres (Xaas.Repo). No mocking.
  """
  use KanbanWeb.ConnCase

  alias Xaas.Governance.ApprovalVendorOffboardingAttestationIssue

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

  test "POST creates a real pending attestation issue, PATCH approves it from a distinct owner",
       %{conn: conn} do
    create_body = %{
      "data" => %{
        "type" => "approval_vendor_offboarding_attestation_issue",
        "attributes" => %{
          "org_id" => "org-#{System.unique_integer([:positive])}",
          "requested_by" => "requester-1",
          "termination_date" => "2026-06-30",
          "contractual_sla_days" => 30
        }
      }
    }

    created =
      conn
      |> json_headers()
      |> post("/api/approval_vendor_offboarding_attestation_issue", create_body)
      |> json_response(201)

    id = created["data"]["id"]

    approve_body = %{
      "data" => %{
        "type" => "approval_vendor_offboarding_attestation_issue",
        "id" => id,
        "attributes" => %{"approved_by" => "owner-2"}
      }
    }

    approved =
      conn
      |> json_headers()
      |> patch("/api/approval_vendor_offboarding_attestation_issue/#{id}", approve_body)
      |> json_response(200)

    assert approved["data"]["attributes"]["approved_by"] == "owner-2"

    persisted = ApprovalVendorOffboardingAttestationIssue |> Ash.get!(id, authorize?: false)
    assert persisted.contractual_sla_days == 30
    assert persisted.termination_date == ~D[2026-06-30]
  end

  test "PATCH rejects a requester approving their own attestation issuance", %{conn: conn} do
    requester = "requester-self-#{System.unique_integer([:positive])}"

    change =
      ApprovalVendorOffboardingAttestationIssue
      |> Ash.Changeset.for_create(:create, %{
        org_id: "org-x",
        requested_by: requester,
        termination_date: ~D[2026-06-30],
        contractual_sla_days: 30
      })
      |> Ash.create!(authorize?: false)

    approve_body = %{
      "data" => %{
        "type" => "approval_vendor_offboarding_attestation_issue",
        "id" => change.id,
        "attributes" => %{"approved_by" => requester}
      }
    }

    resp =
      conn
      |> json_headers()
      |> patch("/api/approval_vendor_offboarding_attestation_issue/#{change.id}", approve_body)

    assert resp.status == 400

    persisted = ApprovalVendorOffboardingAttestationIssue |> Ash.get!(change.id, authorize?: false)
    assert persisted.approved_by == nil
  end

  test "PATCH rejects when approved_by is missing", %{conn: conn} do
    change =
      ApprovalVendorOffboardingAttestationIssue
      |> Ash.Changeset.for_create(:create, %{
        org_id: "org-y",
        requested_by: "requester-missing-approver",
        termination_date: ~D[2026-07-15],
        contractual_sla_days: 45
      })
      |> Ash.create!(authorize?: false)

    approve_body = %{
      "data" => %{
        "type" => "approval_vendor_offboarding_attestation_issue",
        "id" => change.id,
        "attributes" => %{}
      }
    }

    resp =
      conn
      |> json_headers()
      |> patch("/api/approval_vendor_offboarding_attestation_issue/#{change.id}", approve_body)

    assert resp.status == 400
  end
end
