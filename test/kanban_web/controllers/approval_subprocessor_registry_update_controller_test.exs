defmodule KanbanWeb.ApprovalSubprocessorRegistryUpdateControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/approval_subprocessor_registry_update` POST/PATCH routes (issue
  #20, ported from platform-console's POST/PUT/DELETE /api/subprocessors
  "subprocessor.registry.update" maker-checker flow), real Ash-persisted
  rows in the real sandboxed Postgres (Xaas.Repo). No mocking.
  """
  use KanbanWeb.ConnCase

  alias Xaas.Governance.ApprovalSubprocessorRegistryUpdate

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

  test "POST creates a real pending registry update, PATCH approves it from a distinct owner",
       %{conn: conn} do
    create_body = %{
      "data" => %{
        "type" => "approval_subprocessor_registry_update",
        "attributes" => %{
          "requested_by" => "requester-1",
          "change_action" => "added",
          "subprocessor_id" => "acme-cloud-storage",
          "name" => "Acme Cloud Storage",
          "category" => "cloud-infrastructure",
          "regions" => ["us-east-1", "eu-west-1"],
          "purpose" => "durable object storage for customer file uploads",
          "data_categories" => ["file-contents", "file-metadata"]
        }
      }
    }

    created =
      conn
      |> json_headers()
      |> post("/api/approval_subprocessor_registry_update", create_body)
      |> json_response(201)

    id = created["data"]["id"]

    approve_body = %{
      "data" => %{
        "type" => "approval_subprocessor_registry_update",
        "id" => id,
        "attributes" => %{"approved_by" => "owner-2"}
      }
    }

    approved =
      conn
      |> json_headers()
      |> patch("/api/approval_subprocessor_registry_update/#{id}", approve_body)
      |> json_response(200)

    assert approved["data"]["attributes"]["approved_by"] == "owner-2"

    persisted = ApprovalSubprocessorRegistryUpdate |> Ash.get!(id, authorize?: false)
    assert persisted.subprocessor_id == "acme-cloud-storage"
    assert persisted.change_action == :added
    assert persisted.category == :"cloud-infrastructure"
  end

  test "PATCH rejects a requester approving their own registry update", %{conn: conn} do
    requester = "requester-self-#{System.unique_integer([:positive])}"

    change =
      ApprovalSubprocessorRegistryUpdate
      |> Ash.Changeset.for_create(:create, %{
        requested_by: requester,
        change_action: :added,
        subprocessor_id: "acme-cloud-storage",
        name: "Acme Cloud Storage",
        category: :"cloud-infrastructure",
        purpose: "durable object storage for customer file uploads"
      })
      |> Ash.create!(authorize?: false)

    approve_body = %{
      "data" => %{
        "type" => "approval_subprocessor_registry_update",
        "id" => change.id,
        "attributes" => %{"approved_by" => requester}
      }
    }

    resp =
      conn
      |> json_headers()
      |> patch("/api/approval_subprocessor_registry_update/#{change.id}", approve_body)

    assert resp.status == 400

    persisted = ApprovalSubprocessorRegistryUpdate |> Ash.get!(change.id, authorize?: false)
    assert persisted.approved_by == nil
  end

  test "POST rejects a subprocessor_id that is not ConfigMap-key-safe", %{conn: conn} do
    create_body = %{
      "data" => %{
        "type" => "approval_subprocessor_registry_update",
        "attributes" => %{
          "requested_by" => "requester-1",
          "change_action" => "added",
          "subprocessor_id" => "not a valid id!",
          "name" => "Acme Cloud Storage",
          "category" => "cloud-infrastructure",
          "purpose" => "durable object storage for customer file uploads"
        }
      }
    }

    resp =
      conn
      |> json_headers()
      |> post("/api/approval_subprocessor_registry_update", create_body)

    assert resp.status == 400
  end
end
