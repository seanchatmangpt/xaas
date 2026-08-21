defmodule KanbanWeb.ApprovalSourceEscrowSnapshotControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/approval_source_escrow_snapshot` POST/PATCH routes (issue #20,
  ported from platform-console's POST /api/compliance/source-escrow
  maker-checker flow), real Ash-persisted rows in the real sandboxed
  Postgres (Xaas.Repo). No mocking.
  """
  use KanbanWeb.ConnCase

  alias Xaas.Governance.ApprovalSourceEscrowSnapshot

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

  test "POST creates a real pending source-escrow snapshot request, PATCH approves it from a distinct owner",
       %{conn: conn} do
    create_body = %{
      "data" => %{
        "type" => "approval_source_escrow_snapshot",
        "attributes" => %{
          "org_id" => "org-#{System.unique_integer([:positive])}",
          "requested_by" => "requester-1",
          "namespace" => "platform-console"
        }
      }
    }

    create_resp =
      conn |> json_headers() |> post("/api/approval_source_escrow_snapshot", create_body)

    created = json_response(create_resp, 201)
    id = created["data"]["id"]

    approve_body = %{
      "data" => %{
        "type" => "approval_source_escrow_snapshot",
        "id" => id,
        "attributes" => %{"approved_by" => "owner-2"}
      }
    }

    approve_resp =
      conn
      |> json_headers()
      |> patch("/api/approval_source_escrow_snapshot/#{id}", approve_body)

    approved = json_response(approve_resp, 200)
    assert approved["data"]["attributes"]["approved_by"] == "owner-2"

    persisted = ApprovalSourceEscrowSnapshot |> Ash.get!(id, authorize?: false)
    assert persisted.namespace == "platform-console"
    assert persisted.requested_by == "requester-1"
  end

  test "PATCH rejects a requester approving their own snapshot", %{conn: conn} do
    requester = "requester-self-#{System.unique_integer([:positive])}"

    change =
      ApprovalSourceEscrowSnapshot
      |> Ash.Changeset.for_create(:create, %{
        org_id: "org-x",
        requested_by: requester,
        namespace: "platform-console"
      })
      |> Ash.create!(authorize?: false)

    approve_body = %{
      "data" => %{
        "type" => "approval_source_escrow_snapshot",
        "id" => change.id,
        "attributes" => %{"approved_by" => requester}
      }
    }

    resp =
      conn
      |> json_headers()
      |> patch("/api/approval_source_escrow_snapshot/#{change.id}", approve_body)

    assert resp.status == 400

    persisted = ApprovalSourceEscrowSnapshot |> Ash.get!(change.id, authorize?: false)
    assert persisted.approved_by == nil
  end

  test "PATCH rejects approval with a blank approved_by", %{conn: conn} do
    change =
      ApprovalSourceEscrowSnapshot
      |> Ash.Changeset.for_create(:create, %{
        org_id: "org-y",
        requested_by: "requester-2",
        namespace: "platform-console"
      })
      |> Ash.create!(authorize?: false)

    approve_body = %{
      "data" => %{
        "type" => "approval_source_escrow_snapshot",
        "id" => change.id,
        "attributes" => %{"approved_by" => ""}
      }
    }

    resp =
      conn
      |> json_headers()
      |> patch("/api/approval_source_escrow_snapshot/#{change.id}", approve_body)

    assert resp.status == 400

    persisted = ApprovalSourceEscrowSnapshot |> Ash.get!(change.id, authorize?: false)
    assert persisted.approved_by == nil
  end
end
