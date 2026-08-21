defmodule KanbanWeb.ApprovalProviderStatusChangeControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/approval_provider_status_change` POST/PATCH routes (the real
  maker-checker flow gating `Xaas.Marketplace.Provider` status
  transitions), real Ash-persisted rows in the real sandboxed Postgres
  (Xaas.Repo). No mocking.
  """
  use KanbanWeb.ConnCase

  alias Xaas.Accounts.Org
  alias Xaas.Marketplace.{ApprovalProviderStatusChange, Provider}

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp real_org_slug! do
    Org
    |> Ash.Changeset.for_create(:create, %{
      name: "Test Org",
      slug: "org-#{System.unique_integer([:positive])}"
    })
    |> Ash.create!(authorize?: false)
    |> Map.fetch!(:slug)
  end

  defp create_provider!(org_id, status) do
    Provider
    |> Ash.Changeset.for_create(:create, %{
      name: "Test Provider",
      slug: "provider-#{System.unique_integer([:positive])}",
      org_id: org_id,
      status: status
    })
    |> Ash.create!(authorize?: false)
  end

  defp json_headers(conn, org_id) do
    conn
    |> put_req_header("authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
    |> put_req_header("content-type", "application/vnd.api+json")
    |> put_req_header("accept", "application/vnd.api+json")
    |> put_req_header("x-org-id", org_id)
  end

  test "POST creates a real pending status-change request, PATCH approves from a distinct actor and really flips the Provider's status",
       %{conn: conn} do
    org_id = real_org_slug!()
    provider = create_provider!(org_id, :pending)

    create_body = %{
      "data" => %{
        "type" => "approval_provider_status_change",
        "attributes" => %{
          "org_id" => org_id,
          "provider_id" => provider.id,
          "requested_by" => "requester-1",
          "requested_status" => "active"
        }
      }
    }

    create_resp =
      conn |> json_headers(org_id) |> post("/api/approval_provider_status_change", create_body)

    created = json_response(create_resp, 201)
    id = created["data"]["id"]

    persisted_provider_before = Provider |> Ash.get!(provider.id, authorize?: false)
    assert persisted_provider_before.status == :pending

    approve_body = %{
      "data" => %{
        "type" => "approval_provider_status_change",
        "id" => id,
        "attributes" => %{"approved_by" => "owner-2"}
      }
    }

    approve_resp =
      conn
      |> json_headers(org_id)
      |> patch("/api/approval_provider_status_change/#{id}", approve_body)

    approved = json_response(approve_resp, 200)
    assert approved["data"]["attributes"]["approved_by"] == "owner-2"

    persisted_request = ApprovalProviderStatusChange |> Ash.get!(id, authorize?: false)
    assert persisted_request.requested_status == :active

    persisted_provider_after = Provider |> Ash.get!(provider.id, authorize?: false)
    assert persisted_provider_after.status == :active
  end

  test "PATCH rejects a requester approving their own status-change request, and the Provider's status is untouched",
       %{conn: conn} do
    org_id = real_org_slug!()
    provider = create_provider!(org_id, :active)
    requester = "requester-self-#{System.unique_integer([:positive])}"

    request =
      ApprovalProviderStatusChange
      |> Ash.Changeset.for_create(:create, %{
        org_id: org_id,
        provider_id: provider.id,
        requested_by: requester,
        requested_status: :suspended
      })
      |> Ash.create!(authorize?: false)

    approve_body = %{
      "data" => %{
        "type" => "approval_provider_status_change",
        "id" => request.id,
        "attributes" => %{"approved_by" => requester}
      }
    }

    resp =
      conn
      |> json_headers(org_id)
      |> patch("/api/approval_provider_status_change/#{request.id}", approve_body)

    assert resp.status == 400

    persisted_request = ApprovalProviderStatusChange |> Ash.get!(request.id, authorize?: false)
    assert persisted_request.approved_by == nil

    persisted_provider = Provider |> Ash.get!(provider.id, authorize?: false)
    assert persisted_provider.status == :active
  end

  test "PATCH rejects approving a DIFFERENT org's real status-change request, not silently allowed, and the Provider's status is untouched",
       %{conn: conn} do
    owner_org = real_org_slug!()
    other_org = real_org_slug!()
    provider = create_provider!(owner_org, :pending)

    request =
      ApprovalProviderStatusChange
      |> Ash.Changeset.for_create(:create, %{
        org_id: owner_org,
        provider_id: provider.id,
        requested_by: "requester-1",
        requested_status: :active
      })
      |> Ash.create!(authorize?: false)

    approve_body = %{
      "data" => %{
        "type" => "approval_provider_status_change",
        "id" => request.id,
        "attributes" => %{"approved_by" => "owner-2"}
      }
    }

    resp =
      conn
      |> json_headers(other_org)
      |> patch("/api/approval_provider_status_change/#{request.id}", approve_body)

    assert resp.status in [403, 404]

    persisted_request = ApprovalProviderStatusChange |> Ash.get!(request.id, authorize?: false)
    assert persisted_request.approved_by == nil

    persisted_provider = Provider |> Ash.get!(provider.id, authorize?: false)
    assert persisted_provider.status == :pending
  end

  test "POST rejects a provider_id belonging to a DIFFERENT org, even when the actor's own org_id genuinely matches on both create and approve -- the real, twenty-third-pass ERRC grid fix",
       %{conn: conn} do
    attacker_org = real_org_slug!()
    victim_org = real_org_slug!()
    victim_provider = create_provider!(victim_org, :pending)

    create_body = %{
      "data" => %{
        "type" => "approval_provider_status_change",
        "attributes" => %{
          "org_id" => attacker_org,
          "provider_id" => victim_provider.id,
          "requested_by" => "attacker-requester",
          "requested_status" => "active"
        }
      }
    }

    create_resp =
      conn
      |> json_headers(attacker_org)
      |> post("/api/approval_provider_status_change", create_body)

    assert create_resp.status == 400

    # No real cross-org request row was persisted.
    persisted =
      ApprovalProviderStatusChange
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&(&1.org_id == attacker_org))

    assert persisted == []

    # The victim's real Provider status was never touched.
    victim_after = Provider |> Ash.get!(victim_provider.id, authorize?: false)
    assert victim_after.status == :pending
  end

  test "POST without X-Org-Id really 400s", %{conn: conn} do
    org_id = real_org_slug!()
    provider = create_provider!(org_id, :pending)

    body = %{
      "data" => %{
        "type" => "approval_provider_status_change",
        "attributes" => %{
          "org_id" => org_id,
          "provider_id" => provider.id,
          "requested_by" => "requester-1",
          "requested_status" => "active"
        }
      }
    }

    resp =
      conn
      |> put_req_header("authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
      |> put_req_header("content-type", "application/vnd.api+json")
      |> put_req_header("accept", "application/vnd.api+json")
      |> post("/api/approval_provider_status_change", body)

    assert resp.status == 400
  end
end
