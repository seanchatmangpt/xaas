defmodule KanbanWeb.ApprovalPersonnelAttestationRecordControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/approval_personnel_attestation_record` POST/PATCH routes,
  ported from platform-console's real POST /api/compliance/personnel-
  attestation maker-checker flow, real Ash-persisted rows in the real
  sandboxed Postgres (Xaas.Repo). No mocking.
  """
  use KanbanWeb.ConnCase

  alias Xaas.Governance.ApprovalPersonnelAttestationRecord

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

  test "POST creates a real pending attestation, PATCH approves it from a distinct owner",
       %{conn: conn} do
    create_body = %{
      "data" => %{
        "type" => "approval_personnel_attestation_record",
        "attributes" => %{
          "org_id" => "org-#{System.unique_integer([:positive])}",
          "requested_by" => "requester-1",
          "attestation_statement" => "annual security training and background check attested",
          "overrides" => [
            %{
              "identifier" => "employee-42",
              "securityTrainingCompleted" => true,
              "backgroundCheckStatus" => "cleared"
            }
          ]
        }
      }
    }

    created =
      conn
      |> json_headers()
      |> post("/api/approval_personnel_attestation_record", create_body)
      |> json_response(201)

    id = created["data"]["id"]

    approve_body = %{
      "data" => %{
        "type" => "approval_personnel_attestation_record",
        "id" => id,
        "attributes" => %{"approved_by" => "owner-2"}
      }
    }

    approved =
      conn
      |> json_headers()
      |> patch("/api/approval_personnel_attestation_record/#{id}", approve_body)
      |> json_response(200)

    assert approved["data"]["attributes"]["approved_by"] == "owner-2"

    persisted = ApprovalPersonnelAttestationRecord |> Ash.get!(id, authorize?: false)
    assert persisted.approved_by == "owner-2"
    assert persisted.attestation_statement ==
             "annual security training and background check attested"
  end

  test "PATCH rejects a requester approving their own attestation", %{conn: conn} do
    requester = "requester-self-#{System.unique_integer([:positive])}"

    change =
      ApprovalPersonnelAttestationRecord
      |> Ash.Changeset.for_create(:create, %{
        org_id: "org-x",
        requested_by: requester,
        attestation_statement: "test attestation"
      })
      |> Ash.create!(authorize?: false)

    approve_body = %{
      "data" => %{
        "type" => "approval_personnel_attestation_record",
        "id" => change.id,
        "attributes" => %{"approved_by" => requester}
      }
    }

    resp =
      conn
      |> json_headers()
      |> patch("/api/approval_personnel_attestation_record/#{change.id}", approve_body)

    assert resp.status == 400

    persisted = ApprovalPersonnelAttestationRecord |> Ash.get!(change.id, authorize?: false)
    assert persisted.approved_by == nil
  end

  test "PATCH rejects approval when approved_by is missing", %{conn: conn} do
    change =
      ApprovalPersonnelAttestationRecord
      |> Ash.Changeset.for_create(:create, %{
        org_id: "org-x",
        requested_by: "requester-missing-approver",
        attestation_statement: "test attestation"
      })
      |> Ash.create!(authorize?: false)

    approve_body = %{
      "data" => %{
        "type" => "approval_personnel_attestation_record",
        "id" => change.id,
        "attributes" => %{}
      }
    }

    resp =
      conn
      |> json_headers()
      |> patch("/api/approval_personnel_attestation_record/#{change.id}", approve_body)

    assert resp.status == 400

    persisted = ApprovalPersonnelAttestationRecord |> Ash.get!(change.id, authorize?: false)
    assert persisted.approved_by == nil
  end
end
