defmodule KanbanWeb.ApprovalDeploymentQuarantineControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/approval_deployment_quarantine` POST/PATCH routes, real
  Ash-persisted rows in the real sandboxed Postgres (Xaas.Repo). No
  mocking.
  """
  use KanbanWeb.ConnCase

  alias Xaas.Accounts.Org
  alias Xaas.Governance.ApprovalDeploymentQuarantine

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
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

  defp json_headers(conn) do
    conn
    |> put_req_header("authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
    |> put_req_header("content-type", "application/vnd.api+json")
    |> put_req_header("accept", "application/vnd.api+json")
  end

  test "POST creates a real pending quarantine, PATCH approves it from a distinct owner", %{
    conn: conn
  } do
    create_body = %{
      "data" => %{
        "type" => "approval_deployment_quarantine",
        "attributes" => %{
          "org_id" => real_org_slug!(),
          "requested_by" => "requester-1",
          "deployment_name" => "checkout-api",
          "environment" => "prod",
          "reason" => "failed_healthcheck"
        }
      }
    }

    created =
      conn
      |> json_headers()
      |> post("/api/approval_deployment_quarantine", create_body)
      |> json_response(201)

    id = created["data"]["id"]

    approve_body = %{
      "data" => %{
        "type" => "approval_deployment_quarantine",
        "id" => id,
        "attributes" => %{"approved_by" => "owner-2"}
      }
    }

    approved =
      conn
      |> json_headers()
      |> patch("/api/approval_deployment_quarantine/#{id}", approve_body)
      |> json_response(200)

    assert approved["data"]["attributes"]["approved_by"] == "owner-2"

    persisted = ApprovalDeploymentQuarantine |> Ash.get!(id, authorize?: false)
    assert persisted.deployment_name == "checkout-api"
    assert persisted.environment == :prod
  end

  test "PATCH rejects a requester approving their own quarantine", %{conn: conn} do
    requester = "requester-self-#{System.unique_integer([:positive])}"

    change =
      ApprovalDeploymentQuarantine
      |> Ash.Changeset.for_create(:create, %{
        org_id: real_org_slug!(),
        requested_by: requester,
        deployment_name: "billing-worker",
        environment: "staging",
        reason: "manual_hold"
      })
      |> Ash.create!(authorize?: false)

    approve_body = %{
      "data" => %{
        "type" => "approval_deployment_quarantine",
        "id" => change.id,
        "attributes" => %{"approved_by" => requester}
      }
    }

    resp =
      conn
      |> json_headers()
      |> patch("/api/approval_deployment_quarantine/#{change.id}", approve_body)

    assert resp.status == 400

    persisted = ApprovalDeploymentQuarantine |> Ash.get!(change.id, authorize?: false)
    assert persisted.approved_by == nil
  end

  test "POST rejects an invalid deployment_quarantine_reason enum value", %{conn: conn} do
    create_body = %{
      "data" => %{
        "type" => "approval_deployment_quarantine",
        "attributes" => %{
          "org_id" => real_org_slug!(),
          "requested_by" => "requester-1",
          "deployment_name" => "checkout-api",
          "environment" => "prod",
          "reason" => "not_a_real_reason"
        }
      }
    }

    resp = conn |> json_headers() |> post("/api/approval_deployment_quarantine", create_body)
    assert resp.status == 400
  end
end
