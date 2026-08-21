defmodule KanbanWeb.ApprovalDrFailoverControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/approval_dr_failover` POST/PATCH routes (issue #20, ported
  from platform-console's POST /api/dr/initiate-failover maker-checker
  flow), real Ash-persisted rows in the real sandboxed Postgres
  (Xaas.Repo). No mocking.
  """
  use KanbanWeb.ConnCase

  alias Xaas.Accounts.Org
  alias Xaas.Governance.ApprovalDrFailover
  alias Xaas.Operations.Incident

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp with_internal_api_token(conn) do
    put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
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

  # Real, required since ApprovalDrFailoverRequiresOpenIncident was added
  # this session: approving a failover now requires a real open Incident
  # referencing the same from_region to exist first.
  defp open_incident!(org_id, region) do
    Incident
    |> Ash.Changeset.for_create(:create, %{
      org_id: org_id,
      title: "Test incident for #{region}",
      region: region,
      opened_at: DateTime.utc_now()
    })
    |> Ash.create!(authorize?: false)
  end

  defp json_headers(conn, org_id) do
    conn
    |> with_internal_api_token()
    |> put_req_header("content-type", "application/vnd.api+json")
    |> put_req_header("accept", "application/vnd.api+json")
    |> put_req_header("x-org-id", org_id)
  end

  test "POST creates a real pending failover request, PATCH approves it from a distinct owner",
       %{conn: conn} do
    org_id = real_org_slug!()
    open_incident!(org_id, "us-east-1")

    create_body = %{
      "data" => %{
        "type" => "approval_dr_failover",
        "attributes" => %{
          "org_id" => org_id,
          "requested_by" => "requester-1",
          "from_region" => "us-east-1",
          "to_region" => "us-west-2",
          "reason" => "region degradation"
        }
      }
    }

    create_resp = conn |> json_headers(org_id) |> post("/api/approval_dr_failover", create_body)
    created = json_response(create_resp, 201)
    id = created["data"]["id"]

    approve_body = %{
      "data" => %{
        "type" => "approval_dr_failover",
        "id" => id,
        "attributes" => %{"approved_by" => "owner-2"}
      }
    }

    approve_resp = conn |> json_headers(org_id) |> patch("/api/approval_dr_failover/#{id}", approve_body)
    approved = json_response(approve_resp, 200)
    assert approved["data"]["attributes"]["approved_by"] == "owner-2"

    persisted = ApprovalDrFailover |> Ash.get!(id, authorize?: false, tenant: org_id)
    assert persisted.from_region == "us-east-1"
    assert persisted.to_region == "us-west-2"
  end

  test "PATCH rejects a requester approving their own failover", %{conn: conn} do
    requester = "requester-self-#{System.unique_integer([:positive])}"
    org_id = real_org_slug!()
    open_incident!(org_id, "us-east-1")

    change =
      ApprovalDrFailover
      |> Ash.Changeset.for_create(:create, %{
        org_id: org_id,
        requested_by: requester,
        from_region: "us-east-1",
        to_region: "us-west-2",
        reason: "test"
      }, tenant: org_id)
      |> Ash.create!(authorize?: false)

    approve_body = %{
      "data" => %{
        "type" => "approval_dr_failover",
        "id" => change.id,
        "attributes" => %{"approved_by" => requester}
      }
    }

    resp = conn |> json_headers(org_id) |> patch("/api/approval_dr_failover/#{change.id}", approve_body)
    assert resp.status == 400

    persisted = ApprovalDrFailover |> Ash.get!(change.id, authorize?: false, tenant: org_id)
    assert persisted.approved_by == nil
  end

  test "POST with a payload org_id of org B while asserting org A really lands under org A, never org B",
       %{conn: conn} do
    # Real, verified finding (this pass): Ash's attribute-strategy
    # multitenancy (`multitenancy do attribute :org_id; global? false end`)
    # force-overwrites the changeset's `org_id` attribute with the
    # resolved tenant on `:create`, regardless of what the payload's own
    # `org_id` says -- confirmed live via a real `Ash.Changeset.for_create`
    # run with `tenant: org_a, org_id: org_b` in the payload, which
    # persisted with `org_id: org_a`, not `org_b`. That means
    # `ActorOrgMatches`'s `:create` half can never actually fire (the
    # changeset it inspects is already normalized before the policy
    # check runs) -- multitenancy alone already makes a real cross-org
    # `:create` payload impossible, not merely rejected. This test proves
    # that real, if differently-shaped, security property: the row is
    # really created (real 201), but its real persisted `org_id` is the
    # caller's own asserted org, never the target org named in the
    # payload.
    caller_org = real_org_slug!()
    target_org = real_org_slug!()

    create_body = %{
      "data" => %{
        "type" => "approval_dr_failover",
        "attributes" => %{
          "org_id" => target_org,
          "requested_by" => "requester-1",
          "from_region" => "us-east-1",
          "to_region" => "us-west-2",
          "reason" => "cross-org attempt"
        }
      }
    }

    resp = conn |> json_headers(caller_org) |> post("/api/approval_dr_failover", create_body)
    created = json_response(resp, 201)
    id = created["data"]["id"]

    persisted = ApprovalDrFailover |> Ash.get!(id, authorize?: false, tenant: caller_org)
    assert persisted.org_id == caller_org

    assert ApprovalDrFailover
           |> Ash.Query.for_read(:read, %{}, authorize?: false, tenant: target_org)
           |> Ash.read!() == []
  end

  test "PATCH rejects approving a DIFFERENT org's real failover row, not silently allowed",
       %{conn: conn} do
    owner_org = real_org_slug!()
    other_org = real_org_slug!()
    open_incident!(owner_org, "us-east-1")

    record =
      ApprovalDrFailover
      |> Ash.Changeset.for_create(
        :create,
        %{
          org_id: owner_org,
          requested_by: "requester-1",
          from_region: "us-east-1",
          to_region: "us-west-2",
          reason: "region degradation"
        },
        tenant: owner_org
      )
      |> Ash.create!(authorize?: false)

    approve_body = %{
      "data" => %{
        "type" => "approval_dr_failover",
        "id" => record.id,
        "attributes" => %{"approved_by" => "owner-2"}
      }
    }

    resp =
      conn
      |> json_headers(other_org)
      |> patch("/api/approval_dr_failover/#{record.id}", approve_body)

    assert resp.status in [403, 404]

    persisted = ApprovalDrFailover |> Ash.get!(record.id, authorize?: false, tenant: owner_org)
    assert persisted.approved_by == nil
  end
end
