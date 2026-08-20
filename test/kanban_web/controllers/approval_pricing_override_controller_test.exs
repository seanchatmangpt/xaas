defmodule KanbanWeb.ApprovalPricingOverrideControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/approval_pricing_override/:id` PATCH route (issue #20's first
  real mutation route), real Ash.create!/Ash.Changeset rows in the real
  sandboxed Postgres (Xaas.Repo), asserting on the real decoded JSON
  response body and the real persisted state. No mocking of
  ApprovalPricingOverride, its validation, or the DB.
  """
  use KanbanWeb.ConnCase

  alias Xaas.Billing.ApprovalPricingOverride

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp with_internal_api_token(conn) do
    put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
  end

  defp create_pending!(requested_by) do
    ApprovalPricingOverride
    |> Ash.Changeset.for_create(:create, %{requested_by: requested_by})
    |> Ash.create!(authorize?: false)
  end

  test "PATCH .../:id accepts a real approval from a different approver", %{conn: conn} do
    override = create_pending!("requester-#{System.unique_integer([:positive])}")

    body = %{
      "data" => %{
        "type" => "approval_pricing_override",
        "id" => override.id,
        "attributes" => %{"approved_by" => "approver-real-1"}
      }
    }

    conn =
      conn
      |> with_internal_api_token()
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_pricing_override/#{override.id}", body)

    response = json_response(conn, 200)
    assert response["data"]["attributes"]["approved_by"] == "approver-real-1"

    persisted =
      ApprovalPricingOverride
      |> Ash.get!(override.id, authorize?: false)

    assert persisted.approved_by == "approver-real-1"
  end

  test "PATCH .../:id rejects approval missing an approver", %{conn: conn} do
    override = create_pending!("requester-#{System.unique_integer([:positive])}")

    body = %{
      "data" => %{
        "type" => "approval_pricing_override",
        "id" => override.id,
        "attributes" => %{"approved_by" => ""}
      }
    }

    conn =
      conn
      |> with_internal_api_token()
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_pricing_override/#{override.id}", body)

    assert conn.status == 400

    persisted = ApprovalPricingOverride |> Ash.get!(override.id, authorize?: false)
    assert persisted.approved_by == nil
  end

  test "PATCH .../:id rejects a requester approving their own request", %{conn: conn} do
    requester = "requester-#{System.unique_integer([:positive])}"
    override = create_pending!(requester)

    body = %{
      "data" => %{
        "type" => "approval_pricing_override",
        "id" => override.id,
        "attributes" => %{"approved_by" => requester}
      }
    }

    conn =
      conn
      |> with_internal_api_token()
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_pricing_override/#{override.id}", body)

    assert conn.status == 400

    persisted = ApprovalPricingOverride |> Ash.get!(override.id, authorize?: false)
    assert persisted.approved_by == nil
  end

  test "PATCH .../:id rejects requests without the internal API token", %{conn: conn} do
    override = create_pending!("requester-#{System.unique_integer([:positive])}")

    body = %{
      "data" => %{
        "type" => "approval_pricing_override",
        "id" => override.id,
        "attributes" => %{"approved_by" => "approver-real-2"}
      }
    }

    conn =
      conn
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_pricing_override/#{override.id}", body)

    assert conn.status == 401

    persisted = ApprovalPricingOverride |> Ash.get!(override.id, authorize?: false)
    assert persisted.approved_by == nil
  end
end
