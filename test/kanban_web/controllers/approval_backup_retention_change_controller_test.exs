defmodule KanbanWeb.ApprovalBackupRetentionChangeControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/approval_backup_retention_change/:id` PATCH route (issue #20,
  ported from platform-console's PUT /api/orgs/[id]/backup-policy
  maker-checker flow), real Ash.create!/Ash.Changeset rows in the real
  sandboxed Postgres (Xaas.Repo), asserting on the real decoded JSON
  response body and the real persisted state. No mocking of
  ApprovalBackupRetentionChange, its validation, or the DB.
  """
  use KanbanWeb.ConnCase
  require Ash.Query

  alias Xaas.Accounts.Org
  alias Xaas.Governance.ApprovalBackupRetentionChange
  alias Xaas.Ledger.{Account, Balance}

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp with_internal_api_token(conn) do
    put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
  end

  defp with_org_header(conn, org_id) do
    put_req_header(conn, "x-org-id", org_id)
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

  defp create_pending!(requested_by, opts \\ []) do
    org_id = Keyword.get_lazy(opts, :org_id, &real_org_slug!/0)
    tier = Keyword.get(opts, :tier, :pro)
    days = Keyword.get(opts, :days, 90)

    ApprovalBackupRetentionChange
    |> Ash.Changeset.for_create(
      :create,
      %{
        org_id: org_id,
        requested_by: requested_by,
        requested_retention_days: days,
        tier: tier
      },
      tenant: org_id
    )
    |> Ash.create!(authorize?: false)
  end

  defp real_balance_for(identifier) do
    case Account |> Ash.Query.filter(identifier: identifier) |> Ash.read_one!(authorize?: false) do
      nil ->
        nil

      account ->
        Balance
        |> Ash.Query.filter(account_id: account.id)
        |> Ash.read!(authorize?: false)
        |> Enum.reduce(Money.new(:USD, 0), fn b, acc -> Money.add!(acc, b.balance) end)
    end
  end

  test "PATCH .../:id accepts a real approval from a distinct owner", %{conn: conn} do
    change = create_pending!("requester-#{System.unique_integer([:positive])}")

    body = %{
      "data" => %{
        "type" => "approval_backup_retention_change",
        "id" => change.id,
        "attributes" => %{"approved_by" => "owner-real-1"}
      }
    }

    conn =
      conn
      |> with_internal_api_token()
      |> with_org_header(change.org_id)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_backup_retention_change/#{change.id}", body)

    response = json_response(conn, 200)
    assert response["data"]["attributes"]["approved_by"] == "owner-real-1"

    persisted =
      ApprovalBackupRetentionChange |> Ash.get!(change.id, authorize?: false, tenant: change.org_id)

    assert persisted.approved_by == "owner-real-1"
    assert persisted.requested_retention_days == 90

    # Real AshPaperTrail assertion: a version row exists after :approve.
    versions =
      ApprovalBackupRetentionChange.Version
      |> Ash.Query.filter(version_source_id == ^change.id)
      |> Ash.Query.for_read(:read, %{}, authorize?: false, tenant: change.org_id)
      |> Ash.read!()

    assert length(versions) == 2
    assert Enum.map(versions, & &1.version_action_type) |> Enum.sort() == [:create, :update]
  end

  test "PATCH .../:id rejects approval missing an approver", %{conn: conn} do
    change = create_pending!("requester-#{System.unique_integer([:positive])}")

    body = %{
      "data" => %{
        "type" => "approval_backup_retention_change",
        "id" => change.id,
        "attributes" => %{"approved_by" => ""}
      }
    }

    conn =
      conn
      |> with_internal_api_token()
      |> with_org_header(change.org_id)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_backup_retention_change/#{change.id}", body)

    assert conn.status == 400

    persisted =
      ApprovalBackupRetentionChange |> Ash.get!(change.id, authorize?: false, tenant: change.org_id)

    assert persisted.approved_by == nil
  end

  test "PATCH .../:id rejects the requester approving their own change", %{conn: conn} do
    requester = "requester-#{System.unique_integer([:positive])}"
    change = create_pending!(requester)

    body = %{
      "data" => %{
        "type" => "approval_backup_retention_change",
        "id" => change.id,
        "attributes" => %{"approved_by" => requester}
      }
    }

    conn =
      conn
      |> with_internal_api_token()
      |> with_org_header(change.org_id)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_backup_retention_change/#{change.id}", body)

    assert conn.status == 400

    persisted =
      ApprovalBackupRetentionChange |> Ash.get!(change.id, authorize?: false, tenant: change.org_id)

    assert persisted.approved_by == nil
  end

  test "PATCH .../:id rejects requests without the internal API token", %{conn: conn} do
    change = create_pending!("requester-#{System.unique_integer([:positive])}")

    body = %{
      "data" => %{
        "type" => "approval_backup_retention_change",
        "id" => change.id,
        "attributes" => %{"approved_by" => "owner-real-2"}
      }
    }

    conn =
      conn
      |> with_org_header(change.org_id)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_backup_retention_change/#{change.id}", body)

    assert conn.status == 401

    persisted =
      ApprovalBackupRetentionChange |> Ash.get!(change.id, authorize?: false, tenant: change.org_id)

    assert persisted.approved_by == nil
  end

  test "create rejects a retention request outside the tier's real range" do
    # pro tier's real range is 7-90 days (ported verbatim from
    # platform-console's RETENTION_RANGE) -- 200 is out of range.
    org_id = real_org_slug!()

    result =
      ApprovalBackupRetentionChange
      |> Ash.Changeset.for_create(
        :create,
        %{
          org_id: org_id,
          requested_by: "requester-range-test",
          requested_retention_days: 200,
          tier: :pro
        },
        tenant: org_id
      )
      |> Ash.create(authorize?: false)

    assert {:error, %Ash.Error.Invalid{errors: errors}} = result
    assert Enum.any?(errors, &(&1.field == :requested_retention_days))
  end

  test "approving a change that exceeds the tier default charges a real ledger overage fee",
       %{conn: conn} do
    # pro tier's real default is 30 days; requesting 90 is 60 days of real
    # overage at the invented $0.10/day placeholder rate = $6.00.
    org_id = real_org_slug!()
    change = create_pending!("requester-#{System.unique_integer([:positive])}", org_id: org_id, tier: :pro, days: 90)

    body = %{
      "data" => %{
        "type" => "approval_backup_retention_change",
        "id" => change.id,
        "attributes" => %{"approved_by" => "owner-overage-1"}
      }
    }

    conn
    |> with_internal_api_token()
    |> with_org_header(org_id)
    |> put_req_header("content-type", "application/vnd.api+json")
    |> patch("/api/approval_backup_retention_change/#{change.id}", body)
    |> json_response(200)

    org_balance = real_balance_for(org_id)
    revenue_balance = real_balance_for("platform:revenue:backup-retention-overage")

    assert org_balance != nil, "expected a real Xaas.Ledger.Account/Balance to exist for #{org_id}"
    assert Money.equal?(org_balance, Money.new(:USD, "-6.00"))
    assert Money.compare!(revenue_balance, Money.new(:USD, "0")) == :gt
  end

  test "approving a change within the tier default charges no real overage fee", %{conn: conn} do
    # starter tier's real default is 7 days; requesting 5 (within range,
    # under default) -- no overage, no ledger transfer should be created.
    org_id = real_org_slug!()
    change = create_pending!("requester-#{System.unique_integer([:positive])}", org_id: org_id, tier: :starter, days: 5)

    body = %{
      "data" => %{
        "type" => "approval_backup_retention_change",
        "id" => change.id,
        "attributes" => %{"approved_by" => "owner-no-overage-1"}
      }
    }

    conn
    |> with_internal_api_token()
    |> with_org_header(org_id)
    |> put_req_header("content-type", "application/vnd.api+json")
    |> patch("/api/approval_backup_retention_change/#{change.id}", body)
    |> json_response(200)

    assert real_balance_for(org_id) == nil,
           "expected no real Xaas.Ledger.Account to have been opened for #{org_id} -- no overage occurred"
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

    body = %{
      "data" => %{
        "type" => "approval_backup_retention_change",
        "attributes" => %{
          "org_id" => target_org,
          "requested_by" => "requester-cross-org",
          "requested_retention_days" => 30,
          "tier" => "pro"
        }
      }
    }

    resp =
      conn
      |> with_internal_api_token()
      |> with_org_header(caller_org)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> post("/api/approval_backup_retention_change", body)

    created = json_response(resp, 201)
    id = created["data"]["id"]

    persisted = ApprovalBackupRetentionChange |> Ash.get!(id, authorize?: false, tenant: caller_org)
    assert persisted.org_id == caller_org

    assert ApprovalBackupRetentionChange
           |> Ash.Query.for_read(:read, %{}, authorize?: false, tenant: target_org)
           |> Ash.read!() == []
  end

  test "PATCH .../:id rejects approving a DIFFERENT org's real change, not silently allowed",
       %{conn: conn} do
    owner_org = real_org_slug!()
    other_org = real_org_slug!()
    change = create_pending!("requester-cross-org-patch", org_id: owner_org)

    body = %{
      "data" => %{
        "type" => "approval_backup_retention_change",
        "id" => change.id,
        "attributes" => %{"approved_by" => "hijacker-1"}
      }
    }

    resp =
      conn
      |> with_internal_api_token()
      |> with_org_header(other_org)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_backup_retention_change/#{change.id}", body)

    assert resp.status in [403, 404]

    persisted =
      ApprovalBackupRetentionChange |> Ash.get!(change.id, authorize?: false, tenant: owner_org)

    assert persisted.approved_by == nil
  end
end
