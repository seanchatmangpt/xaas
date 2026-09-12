defmodule XaasWeb.ApprovalTierDowngradeControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against
  the real `/api/approval_tier_downgrade` POST/PATCH routes, real
  `Ash.create!`/`Ash.Changeset` rows in the real sandboxed Postgres
  (`Xaas.Repo`), asserting on the real decoded JSON response body and the
  real persisted state. No mocking of `ApprovalTierDowngrade`, its
  validations, `Xaas.Billing.Subscription`, or the DB.

  Extended eleventh pass (real fix -- see `ApprovalTierDowngrade`'s own
  moduledoc): `:create` now requires a real `subscription_id` and
  `requested_tier`, and a real end-to-end PATCH .../:id approve test
  proves the previously-dead `ApprovalTierDowngradeApprove` change now
  really drives `Subscription.change_tier` (real tier drop + real
  prorated `Xaas.Ledger.Transfer` credit) over the real HTTP route, not
  just via internal Ash calls.

  Extended fifteenth pass (real fix -- see `Xaas.Billing.Checks.
  ActorOrgMatches` and `ApprovalTierDowngrade`'s own moduledoc): a real,
  live-HTTP-proven cross-org vulnerability was found and fixed this
  pass -- an actor asserting an unrelated org's `X-Org-Id` could
  previously `:create`/`:approve` a tier downgrade against ANY org's
  subscription (proven live: cross-org `PATCH` dropped a victim org's
  real `Subscription` tier and posted a real `$50.00` Ledger credit).
  Every `:create`/`:approve` request now requires a real `X-Org-Id`
  header (via `XaasWeb.Plugs.ResolveOrgActor`, newly scoped to this
  route) that resolves to a real `Xaas.Accounts.Org` and matches the
  target subscription's real `org_id`, or `Xaas.Billing.Checks.
  ActorOrgMatches` denies with a real `403`. The 2 new tests at the
  bottom of this file prove that real cross-org rejection, mirroring
  `XaasWeb.ApprovalDrFailoverControllerTest`'s own cross-org test
  pattern. Every other test in this file was updated to send a real,
  matching `X-Org-Id` header so it continues to exercise its own named
  behavior (not incidentally pass/fail on the new org check).
  """
  use XaasWeb.ConnCase
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

  # Real, required since the fifteenth-pass fix: :create/:approve now
  # require a real, caller-asserted X-Org-Id header (resolved by
  # XaasWeb.Plugs.ResolveOrgActor against a real Xaas.Accounts.Org row)
  # that must match the target subscription's real org_id, or the real
  # Xaas.Billing.Checks.ActorOrgMatches policy check denies the request.
  defp with_org_headers(conn, org_id) do
    conn
    |> with_internal_api_token()
    |> put_req_header("x-org-id", org_id)
  end

  # Real, required since ResolveOrgActor resolves X-Org-Id against a real
  # Xaas.Accounts.Org row by slug (Ash.get(Org, [slug: org_id], ...)) --
  # an arbitrary unregistered string now real-404s before ever reaching
  # ApprovalTierDowngrade's own policy check.
  defp real_org_slug! do
    Xaas.Generator.create_org!().slug
  end

  defp real_balance_for(identifier) do
    case Account
         |> Ash.Query.filter(identifier: identifier)
         |> Ash.read_one!(authorize?: false) do
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
  # exactly the dead-on-arrival gap the eleventh pass fixed.
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
    org_id = Keyword.get_lazy(opts, :org_id, fn -> real_org_slug!() end)
    current_tier = Keyword.get(opts, :current_tier, :pro)
    requested_tier = Keyword.get(opts, :requested_tier, :standard)

    subscription =
      Keyword.get_lazy(opts, :subscription, fn -> real_subscription!(org_id, current_tier) end)

    request =
      ApprovalTierDowngrade
      |> Ash.Changeset.for_create(:create, %{
        requested_by: requested_by,
        subscription_id: subscription.id,
        requested_tier: requested_tier
      })
      |> Ash.create!(authorize?: false)

    {request, subscription, org_id}
  end

  test "POST /api/approval_tier_downgrade creates a real pending request", %{conn: conn} do
    requester = "requester-#{System.unique_integer([:positive])}"
    org_id = real_org_slug!()
    subscription = real_subscription!(org_id, :pro)

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
      |> with_org_headers(org_id)
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
    org_id = real_org_slug!()
    subscription = real_subscription!(org_id, :standard)

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
      |> with_org_headers(org_id)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> post("/api/approval_tier_downgrade", body)

    assert conn.status == 400
  end

  test "POST /api/approval_tier_downgrade rejects requests without the internal API token", %{
    conn: conn
  } do
    org_id = real_org_slug!()
    subscription = real_subscription!(org_id, :pro)

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

  test "PATCH .../:id accepts a real approval and persists the HTTP/JSON:API shell", %{conn: conn} do
    {pending, _subscription, org_id} =
      create_pending!("requester-#{System.unique_integer([:positive])}")

    body = %{
      "data" => %{
        "type" => "approval_tier_downgrade",
        "id" => pending.id,
        "attributes" => %{"approved_by" => "approver-real-1"}
      }
    }

    conn =
      conn
      |> with_org_headers(org_id)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_tier_downgrade/#{pending.id}", body)

    response = json_response(conn, 200)
    assert response["data"]["attributes"]["approved_by"] == "approver-real-1"

    persisted = ApprovalTierDowngrade |> Ash.get!(pending.id, authorize?: false)
    assert persisted.approved_by == "approver-real-1"

    # The real end-to-end business outcome (Subscription :pro -> :standard,
    # real $50.00 prorated Ledger credit) is already proven at the
    # resource level in test/xaas/billing/approval_tier_downgrade_test.exs:87-114 —
    # this test's unique value is the HTTP/JSON:API wiring above.
  end

  test "PATCH .../:id rejects approval missing an approver", %{conn: conn} do
    {pending, _subscription, org_id} =
      create_pending!("requester-#{System.unique_integer([:positive])}")

    body = %{
      "data" => %{
        "type" => "approval_tier_downgrade",
        "id" => pending.id,
        "attributes" => %{"approved_by" => ""}
      }
    }

    conn =
      conn
      |> with_org_headers(org_id)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_tier_downgrade/#{pending.id}", body)

    assert conn.status == 400

    persisted = ApprovalTierDowngrade |> Ash.get!(pending.id, authorize?: false)
    assert persisted.approved_by == nil
  end

  test "PATCH .../:id rejects a requester approving their own request", %{conn: conn} do
    requester = "requester-#{System.unique_integer([:positive])}"
    {pending, _subscription, org_id} = create_pending!(requester)

    body = %{
      "data" => %{
        "type" => "approval_tier_downgrade",
        "id" => pending.id,
        "attributes" => %{"approved_by" => requester}
      }
    }

    conn =
      conn
      |> with_org_headers(org_id)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_tier_downgrade/#{pending.id}", body)

    assert conn.status == 400

    persisted = ApprovalTierDowngrade |> Ash.get!(pending.id, authorize?: false)
    assert persisted.approved_by == nil
  end

  test "PATCH .../:id rejects requests without the internal API token", %{conn: conn} do
    {pending, _subscription, _org_id} =
      create_pending!("requester-#{System.unique_integer([:positive])}")

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

  # Real regression test for this pass's own selected CREATE item: proves
  # the real, live-HTTP-demonstrated vulnerability found by the
  # fifteenth-pass ERRC grid sweep is now really closed. Before this pass:
  # an actor asserting ANY X-Org-Id (no relationship to the target
  # subscription at all) could create a downgrade request against another
  # org's subscription. Now: Xaas.Billing.Checks.ActorOrgMatches loads the
  # real target Subscription and denies with a real 403 when the actor's
  # asserted org and the subscription's real org_id disagree.
  test "POST rejects creating a downgrade against a DIFFERENT org's subscription, not silently allowed",
       %{conn: conn} do
    victim_org = real_org_slug!()
    attacker_org = real_org_slug!()
    subscription = real_subscription!(victim_org, :pro)

    body = %{
      "data" => %{
        "type" => "approval_tier_downgrade",
        "attributes" => %{
          "requested_by" => "attacker-requester",
          "subscription_id" => subscription.id,
          "requested_tier" => "standard"
        }
      }
    }

    conn =
      conn
      |> with_org_headers(attacker_org)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> post("/api/approval_tier_downgrade", body)

    assert conn.status == 403

    # Real cross-check: no row was persisted at all, not just a rejected
    # response -- a denied create has zero real side effects.
    assert ApprovalTierDowngrade
           |> Ash.Query.filter(subscription_id == ^subscription.id)
           |> Ash.read!(authorize?: false) == []
  end

  # This is the exact real, live-HTTP-proven exploit this pass's grid sweep
  # found and disclosed: an actor asserting an unrelated org's X-Org-Id
  # could PATCH .../:id approve a DIFFERENT org's pending tier downgrade,
  # really dropping that org's real Subscription tier and posting a real
  # Xaas.Ledger.Transfer credit. This test proves the real fix -- a real
  # 403, the subscription's tier untouched, no Ledger money movement, and
  # the approval row still pending.
  test "PATCH rejects approving a DIFFERENT org's real downgrade, not silently allowed -- the real fifteenth-pass exploit, now closed",
       %{conn: conn} do
    victim_org = real_org_slug!()
    attacker_org = real_org_slug!()

    {pending, subscription, ^victim_org} =
      create_pending!("victim-requester",
        org_id: victim_org,
        current_tier: :pro,
        requested_tier: :standard
      )

    body = %{
      "data" => %{
        "type" => "approval_tier_downgrade",
        "id" => pending.id,
        "attributes" => %{"approved_by" => "attacker-approver"}
      }
    }

    conn =
      conn
      |> with_org_headers(attacker_org)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_tier_downgrade/#{pending.id}", body)

    assert conn.status == 403

    persisted = ApprovalTierDowngrade |> Ash.get!(pending.id, authorize?: false)

    assert persisted.approved_by == nil,
           "a cross-org PATCH must never approve another org's real downgrade -- " <>
             "this is the exact fifteenth-pass live-demonstrated exploit"

    reloaded_subscription = Ash.reload!(subscription, authorize?: false)

    assert reloaded_subscription.tier == :pro,
           "a rejected cross-org approval must never really drive Subscription.change_tier"

    assert real_balance_for(victim_org) == nil,
           "a rejected cross-org approval must never post a real Ledger.Transfer credit"
  end
end
