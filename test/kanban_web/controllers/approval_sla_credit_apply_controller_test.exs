defmodule KanbanWeb.ApprovalSlaCreditApplyControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against
  the real `/api/approval_sla_credit_apply` POST/PATCH routes, real
  `Ash.create!`/`Ash.Changeset` rows in the real sandboxed Postgres
  (`Xaas.Repo`), asserting on the real decoded JSON response body and the
  real persisted state. No mocking of `ApprovalSlaCreditApply`, its
  validation, or the DB.
  """
  use KanbanWeb.ConnCase

  alias Xaas.Billing.ApprovalSlaCreditApply

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp with_internal_api_token(conn) do
    put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
  end

  defp create_pending!(requested_by) do
    ApprovalSlaCreditApply
    |> Ash.Changeset.for_create(:create, %{
      requested_by: requested_by,
      org_id: "org-controller-#{System.unique_integer([:positive])}",
      credit_amount_cents: 1000
    })
    |> Ash.create!(authorize?: false)
  end

  test "POST /api/approval_sla_credit_apply creates a real pending request", %{conn: conn} do
    requester = "requester-#{System.unique_integer([:positive])}"

    body = %{
      "data" => %{
        "type" => "approval_sla_credit_apply",
        "attributes" => %{
          "requested_by" => requester,
          "org_id" => "org-controller-#{System.unique_integer([:positive])}",
          "credit_amount_cents" => 1000
        }
      }
    }

    conn =
      conn
      |> with_internal_api_token()
      |> put_req_header("content-type", "application/vnd.api+json")
      |> post("/api/approval_sla_credit_apply", body)

    response = json_response(conn, 201)
    assert response["data"]["attributes"]["requested_by"] == requester
    assert response["data"]["attributes"]["approved_by"] == nil
  end

  test "POST /api/approval_sla_credit_apply rejects requests without the internal API token", %{conn: conn} do
    body = %{
      "data" => %{
        "type" => "approval_sla_credit_apply",
        "attributes" => %{"requested_by" => "requester-noauth"}
      }
    }

    conn =
      conn
      |> put_req_header("content-type", "application/vnd.api+json")
      |> post("/api/approval_sla_credit_apply", body)

    assert conn.status == 401
  end

  test "PATCH .../:id accepts a real approval from a different approver", %{conn: conn} do
    pending = create_pending!("requester-#{System.unique_integer([:positive])}")

    body = %{
      "data" => %{
        "type" => "approval_sla_credit_apply",
        "id" => pending.id,
        "attributes" => %{"approved_by" => "approver-real-1"}
      }
    }

    conn =
      conn
      |> with_internal_api_token()
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_sla_credit_apply/#{pending.id}", body)

    response = json_response(conn, 200)
    assert response["data"]["attributes"]["approved_by"] == "approver-real-1"

    persisted = ApprovalSlaCreditApply |> Ash.get!(pending.id, authorize?: false)
    assert persisted.approved_by == "approver-real-1"
  end

  test "PATCH .../:id rejects approval missing an approver", %{conn: conn} do
    pending = create_pending!("requester-#{System.unique_integer([:positive])}")

    body = %{
      "data" => %{
        "type" => "approval_sla_credit_apply",
        "id" => pending.id,
        "attributes" => %{"approved_by" => ""}
      }
    }

    conn =
      conn
      |> with_internal_api_token()
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_sla_credit_apply/#{pending.id}", body)

    assert conn.status == 400

    persisted = ApprovalSlaCreditApply |> Ash.get!(pending.id, authorize?: false)
    assert persisted.approved_by == nil
  end

  test "PATCH .../:id rejects a requester approving their own request", %{conn: conn} do
    requester = "requester-#{System.unique_integer([:positive])}"
    pending = create_pending!(requester)

    body = %{
      "data" => %{
        "type" => "approval_sla_credit_apply",
        "id" => pending.id,
        "attributes" => %{"approved_by" => requester}
      }
    }

    conn =
      conn
      |> with_internal_api_token()
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_sla_credit_apply/#{pending.id}", body)

    assert conn.status == 400

    persisted = ApprovalSlaCreditApply |> Ash.get!(pending.id, authorize?: false)
    assert persisted.approved_by == nil
  end

  test "PATCH .../:id rejects requests without the internal API token", %{conn: conn} do
    pending = create_pending!("requester-#{System.unique_integer([:positive])}")

    body = %{
      "data" => %{
        "type" => "approval_sla_credit_apply",
        "id" => pending.id,
        "attributes" => %{"approved_by" => "approver-real-2"}
      }
    }

    conn =
      conn
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_sla_credit_apply/#{pending.id}", body)

    assert conn.status == 401

    persisted = ApprovalSlaCreditApply |> Ash.get!(pending.id, authorize?: false)
    assert persisted.approved_by == nil
  end
end
