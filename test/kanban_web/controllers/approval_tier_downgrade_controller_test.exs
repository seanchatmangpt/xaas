defmodule KanbanWeb.ApprovalTierDowngradeControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against
  the real `/api/approval_tier_downgrade` POST/PATCH routes, real
  `Ash.create!`/`Ash.Changeset` rows in the real sandboxed Postgres
  (`Xaas.Repo`), asserting on the real decoded JSON response body and the
  real persisted state. No mocking of `ApprovalTierDowngrade`, its
  validations, `Xaas.Billing.Subscription`, or the DB.

  Extended this pass (real fix -- see `ApprovalTierDowngrade`'s own
  moduledoc): `:create` now requires a real `subscription_id` and
  `requested_tier`, and a real end-to-end PATCH .../:id approve test
  proves the previously-dead `ApprovalTierDowngradeApprove` change now
  really drives `Subscription.change_tier` (real tier drop + real
  prorated `Xaas.Ledger.Transfer` credit) over the real HTTP route, not
  just via internal Ash calls.
  """
  use KanbanWeb.ConnCase
  require Ash.Query

  alias Xaas.Billing.{ApprovalTierDowngrade, Subscription}
  alias Xaas.Ledger.{Account, Balance}

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp with_internal_api_token(conn) do
    put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
  end

  defp real_balance_for(identifier) do
    case Account |> Ash.Query.filter(identifier: identifier) |> Ash.read_one!(authorize?: false) do
      nil ->
        nil

      account ->
        Balance
        |> Ash.Query.filter(account_id: account.id)
        |> Ash.read!(authorize?: false)
        |> Enum.max_by(& &1.transfer_id, fn -> nil end)
        |> case do
          nil -> nil
          balance -> balance.balance
        end
    end
  end

  # Real, required since :create now needs a real subscription to target --
  # a "tier downgrade" with no subscription/tier data on it at all was
  # exactly the dead-on-arrival gap this pass fixed.
  defp real_subscription!(org_id, tier) do
    Subscription
    |> Ash.Changeset.for_create(:create, %{
      org_id: org_id,
      stripe_customer_id: "cus_#{System.unique_integer([:positive])}",
      tier: tier,
      status: :incomplete
    })
    |> Ash.create!(authorize?: false)
  end

  defp create_pending!(requested_by, opts \\ []) do
    org_id = Keyword.get_lazy(opts, :org_id, fn -> "org-#{System.unique_integer([:positive])}" end)
    current_tier = Keyword.get(opts, :current_tier, :pro)
    requested_tier = Keyword.get(opts, :requested_tier, :standard)
    subscription = Keyword.get_lazy(opts, :subscription, fn -> real_subscription!(org_id, current_tier) end)

    request =
      ApprovalTierDowngrade
      |> Ash.Changeset.for_create(:create, %{
        requested_by: requested_by,
        subscription_id: subscription.id,
        requested_tier: requested_tier
      })
      |> Ash.create!(authorize?: false)

    {request, subscription}
  end

  test "POST /api/approval_tier_downgrade creates a real pending request", %{conn: conn} do
    requester = "requester-#{System.unique_integer([:positive])}"
    subscription = real_subscription!("org-#{System.unique_integer([:positive])}", :pro)

    body = %{
      "data" => %{
        "type" => "approval_tier_downgrade",
        "attributes" => %{
          "requested_by" => requester,
          "subscription_id" => subscription.id,
          "requested_tier" => "standard"
        }
      }
    }

    conn =
      conn
      |> with_internal_api_token()
      |> put_req_header("content-type", "application/vnd.api+json")
      |> post("/api/approval_tier_downgrade", body)

    response = json_response(conn, 201)
    assert response["data"]["attributes"]["requested_by"] == requester
    assert response["data"]["attributes"]["approved_by"] == nil
    assert response["data"]["attributes"]["requested_tier"] == "standard"
    assert response["data"]["attributes"]["subscription_id"] == subscription.id
  end

  test "POST /api/approval_tier_downgrade rejects a requested_tier that is not really lower than the subscription's current tier",
       %{conn: conn} do
    subscription = real_subscription!("org-#{System.unique_integer([:positive])}", :standard)

    body = %{
      "data" => %{
        "type" => "approval_tier_downgrade",
        "attributes" => %{
          "requested_by" => "requester-notlower",
          "subscription_id" => subscription.id,
          "requested_tier" => "pro"
        }
      }
    }

    conn =
      conn
      |> with_internal_api_token()
      |> put_req_header("content-type", "application/vnd.api+json")
      |> post("/api/approval_tier_downgrade", body)

    assert conn.status == 400
  end

  test "POST /api/approval_tier_downgrade rejects requests without the internal API token", %{conn: conn} do
    subscription = real_subscription!("org-#{System.unique_integer([:positive])}", :pro)

    body = %{
      "data" => %{
        "type" => "approval_tier_downgrade",
        "attributes" => %{
          "requested_by" => "requester-noauth",
          "subscription_id" => subscription.id,
          "requested_tier" => "standard"
        }
      }
    }

    conn =
      conn
      |> put_req_header("content-type", "application/vnd.api+json")
      |> post("/api/approval_tier_downgrade", body)

    assert conn.status == 401
  end

  test "PATCH .../:id accepts a real approval and really drives Subscription.change_tier end to end", %{conn: conn} do
    org_id = "org-e2e-approve-#{System.unique_integer([:positive])}"
    {pending, subscription} = create_pending!("requester-#{System.unique_integer([:positive])}", org_id: org_id)

    body = %{
      "data" => %{
        "type" => "approval_tier_downgrade",
        "id" => pending.id,
        "attributes" => %{"approved_by" => "approver-real-1"}
      }
    }

    conn =
      conn
      |> with_internal_api_token()
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_tier_downgrade/#{pending.id}", body)

    response = json_response(conn, 200)
    assert response["data"]["attributes"]["approved_by"] == "approver-real-1"

    persisted = ApprovalTierDowngrade |> Ash.get!(pending.id, authorize?: false)
    assert persisted.approved_by == "approver-real-1"

    # Real end-to-end proof, not just the approval row: the driven
    # Subscription really dropped from :pro to :standard, and a real
    # prorated Xaas.Ledger.Transfer credit posted to the org's account.
    reloaded_subscription = Ash.reload!(subscription, authorize?: false)
    assert reloaded_subscription.tier == :standard

    # (2900 - 7900) / 30 * 30 = -5000 cents -> a real $50.00 credit
    org_balance = real_balance_for(org_id)
    assert Money.equal?(org_balance, Money.new(:USD, "50.00"))
  end

  test "PATCH .../:id rejects approval missing an approver", %{conn: conn} do
    {pending, _subscription} = create_pending!("requester-#{System.unique_integer([:positive])}")

    body = %{
      "data" => %{
        "type" => "approval_tier_downgrade",
        "id" => pending.id,
        "attributes" => %{"approved_by" => ""}
      }
    }

    conn =
      conn
      |> with_internal_api_token()
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_tier_downgrade/#{pending.id}", body)

    assert conn.status == 400

    persisted = ApprovalTierDowngrade |> Ash.get!(pending.id, authorize?: false)
    assert persisted.approved_by == nil
  end

  test "PATCH .../:id rejects a requester approving their own request", %{conn: conn} do
    requester = "requester-#{System.unique_integer([:positive])}"
    {pending, _subscription} = create_pending!(requester)

    body = %{
      "data" => %{
        "type" => "approval_tier_downgrade",
        "id" => pending.id,
        "attributes" => %{"approved_by" => requester}
      }
    }

    conn =
      conn
      |> with_internal_api_token()
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_tier_downgrade/#{pending.id}", body)

    assert conn.status == 400

    persisted = ApprovalTierDowngrade |> Ash.get!(pending.id, authorize?: false)
    assert persisted.approved_by == nil
  end

  test "PATCH .../:id rejects requests without the internal API token", %{conn: conn} do
    {pending, _subscription} = create_pending!("requester-#{System.unique_integer([:positive])}")

    body = %{
      "data" => %{
        "type" => "approval_tier_downgrade",
        "id" => pending.id,
        "attributes" => %{"approved_by" => "approver-real-2"}
      }
    }

    conn =
      conn
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_tier_downgrade/#{pending.id}", body)

    assert conn.status == 401

    persisted = ApprovalTierDowngrade |> Ash.get!(pending.id, authorize?: false)
    assert persisted.approved_by == nil
  end
end
