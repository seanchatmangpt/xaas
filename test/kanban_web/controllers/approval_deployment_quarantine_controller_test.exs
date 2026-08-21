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

  defp json_headers(conn, org_id) do
    conn
    |> put_req_header("authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
    |> put_req_header("content-type", "application/vnd.api+json")
    |> put_req_header("accept", "application/vnd.api+json")
    |> put_req_header("x-org-id", org_id)
  end

  test "POST creates a real pending quarantine, PATCH approves it from a distinct owner", %{
    conn: conn
  } do
    org_id = real_org_slug!()

    create_body = %{
      "data" => %{
        "type" => "approval_deployment_quarantine",
        "attributes" => %{
          "org_id" => org_id,
          "requested_by" => "requester-1",
          "deployment_name" => "checkout-api",
          "environment" => "prod",
          "reason" => "failed_healthcheck"
        }
      }
    }

    created =
      conn
      |> json_headers(org_id)
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
      |> json_headers(org_id)
      |> patch("/api/approval_deployment_quarantine/#{id}", approve_body)
      |> json_response(200)

    assert approved["data"]["attributes"]["approved_by"] == "owner-2"

    persisted = ApprovalDeploymentQuarantine |> Ash.get!(id, authorize?: false, tenant: org_id)
    assert persisted.deployment_name == "checkout-api"
    assert persisted.environment == :prod
  end

  test "PATCH rejects a requester approving their own quarantine", %{conn: conn} do
    requester = "requester-self-#{System.unique_integer([:positive])}"
    org_id = real_org_slug!()

    change =
      ApprovalDeploymentQuarantine
      |> Ash.Changeset.for_create(:create, %{
        org_id: org_id,
        requested_by: requester,
        deployment_name: "billing-worker",
        environment: "staging",
        reason: "manual_hold"
      }, tenant: org_id)
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
      |> json_headers(org_id)
      |> patch("/api/approval_deployment_quarantine/#{change.id}", approve_body)

    assert resp.status == 400

    persisted = ApprovalDeploymentQuarantine |> Ash.get!(change.id, authorize?: false, tenant: org_id)
    assert persisted.approved_by == nil
  end

  test "POST rejects an invalid deployment_quarantine_reason enum value", %{conn: conn} do
    org_id = real_org_slug!()

    create_body = %{
      "data" => %{
        "type" => "approval_deployment_quarantine",
        "attributes" => %{
          "org_id" => org_id,
          "requested_by" => "requester-1",
          "deployment_name" => "checkout-api",
          "environment" => "prod",
          "reason" => "not_a_real_reason"
        }
      }
    }

    resp = conn |> json_headers(org_id) |> post("/api/approval_deployment_quarantine", create_body)
    assert resp.status == 400
  end

  test "POST with a payload org_id of org B while asserting org A really lands under org A, never org B",
       %{conn: conn} do
    # Real, verified finding (this pass): Ash's attribute-strategy
    # multitenancy force-overwrites the changeset's `org_id` attribute
    # with the resolved tenant on `:create` regardless of the payload's
    # own `org_id` -- see `approval_dr_failover_controller_test.exs`'s
    # sibling test for the live-verified repro. The real security
    # property still holds, just via multitenancy normalization instead
    # of a rejected request: the row really lands under the caller's own
    # asserted org, never the target org named in the payload.
    caller_org = real_org_slug!()
    target_org = real_org_slug!()

    create_body = %{
      "data" => %{
        "type" => "approval_deployment_quarantine",
        "attributes" => %{
          "org_id" => target_org,
          "requested_by" => "requester-cross-org",
          "deployment_name" => "checkout-api",
          "environment" => "prod",
          "reason" => "failed_healthcheck"
        }
      }
    }

    resp =
      conn |> json_headers(caller_org) |> post("/api/approval_deployment_quarantine", create_body)

    created = json_response(resp, 201)
    id = created["data"]["id"]

    persisted = ApprovalDeploymentQuarantine |> Ash.get!(id, authorize?: false, tenant: caller_org)
    assert persisted.org_id == caller_org

    assert ApprovalDeploymentQuarantine
           |> Ash.Query.for_read(:read, %{}, authorize?: false, tenant: target_org)
           |> Ash.read!() == []
  end

  test "PATCH rejects approving a DIFFERENT org's real quarantine, not silently allowed",
       %{conn: conn} do
    owner_org = real_org_slug!()
    other_org = real_org_slug!()

    change =
      ApprovalDeploymentQuarantine
      |> Ash.Changeset.for_create(
        :create,
        %{
          org_id: owner_org,
          requested_by: "requester-1",
          deployment_name: "billing-worker",
          environment: "staging",
          reason: "manual_hold"
        },
        tenant: owner_org
      )
      |> Ash.create!(authorize?: false)

    approve_body = %{
      "data" => %{
        "type" => "approval_deployment_quarantine",
        "id" => change.id,
        "attributes" => %{"approved_by" => "hijacker-1"}
      }
    }

    resp =
      conn
      |> json_headers(other_org)
      |> patch("/api/approval_deployment_quarantine/#{change.id}", approve_body)

    assert resp.status in [403, 404]

    persisted =
      ApprovalDeploymentQuarantine |> Ash.get!(change.id, authorize?: false, tenant: owner_org)

    assert persisted.approved_by == nil
  end
end
