defmodule XaasWeb.ApprovalSubprocessorRegistryUpdateControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/approval_subprocessor_registry_update` POST/PATCH routes (issue
  #20, ported from platform-console's POST/PUT/DELETE /api/subprocessors
  "subprocessor.registry.update" maker-checker flow), real Ash-persisted
  rows in the real sandboxed Postgres (Xaas.Repo). No mocking.
  """
  use XaasWeb.ConnCase

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
