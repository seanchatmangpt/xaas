defmodule KanbanWeb.ApprovalSlaCreditApplyControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against
  the real `/api/approval_sla_credit_apply` POST/PATCH routes, real
  `Ash.create!`/`Ash.Changeset` rows in the real sandboxed Postgres
  (`Xaas.Repo`), asserting on the real decoded JSON response body and the
  real persisted state. No mocking of `ApprovalSlaCreditApply`, its
  validation, or the DB.

  Extended sixteenth pass (real fix -- see `Xaas.Billing.Checks.
  SlaCreditActorOrgMatches` and `ApprovalSlaCreditApply`'s own moduledoc):
  a real, live-HTTP-proven cross-org vulnerability was found and fixed
  this pass -- an actor holding only the shared `INTERNAL_API_TOKEN`
  could previously `:create` a request with a fabricated, never-registered
  `org_id`, then self-approve it, minting a real Ledger credit with zero
  authorization check (proven live: `Money.new(:USD, "9999.99")` landed in
  a real `Xaas.Ledger.Balance` row for an org that was never created).
  Every `:create`/`:approve` request now requires a real `X-Org-Id` header
  (via `KanbanWeb.Plugs.ResolveOrgActor`, newly scoped to this route) that
  resolves to a real `Xaas.Accounts.Org` and matches the request's own
  `org_id` attribute, or `Xaas.Billing.Checks.SlaCreditActorOrgMatches`
  denies with a real `403`. The 2 new tests at the bottom of this file
  prove that real cross-org rejection, mirroring
  `KanbanWeb.ApprovalTierDowngradeControllerTest`'s own cross-org test
  pattern. Every other test in this file was updated to send a real,
  matching `X-Org-Id` header so it continues to exercise its own named
  behavior (not incidentally pass/fail on the new org check).
  """
  use KanbanWeb.ConnCase
  require Ash.Query

  alias Xaas.Accounts.Org
  alias Xaas.Billing.ApprovalSlaCreditApply
  alias Xaas.Ledger.{Account, Balance}

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp with_internal_api_token(conn) do
    put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
  end

  # Real, required since the sixteenth-pass fix: :create/:approve now
  # require a real, caller-asserted X-Org-Id header (resolved by
  # KanbanWeb.Plugs.ResolveOrgActor against a real Xaas.Accounts.Org row)
  # that must match the request's real org_id, or the real
  # Xaas.Billing.Checks.SlaCreditActorOrgMatches policy check denies it.
  defp with_org_headers(conn, org_id) do
    conn
    |> with_internal_api_token()
    |> put_req_header("x-org-id", org_id)
  end

  # Real, required since ResolveOrgActor resolves X-Org-Id against a real
  # Xaas.Accounts.Org row by slug (Ash.get(Org, [slug: org_id], ...)) --
  # an arbitrary unregistered string now real-404s before ever reaching
  # ApprovalSlaCreditApply's own policy check.
  defp real_org_slug! do
    Org
    |> Ash.Changeset.for_create(:create, %{
      name: "Test Org",
      slug: "org-#{System.unique_integer([:positive])}"
    })
    |> Ash.create!(authorize?: false)
    |> Map.fetch!(:slug)
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

  defp create_pending!(requested_by, org_id) do
    ApprovalSlaCreditApply
    |> Ash.Changeset.for_create(:create, %{
      requested_by: requested_by,
      org_id: org_id,
      credit_amount_cents: 1000
    })
    |> Ash.create!(authorize?: false)
  end

  test "POST /api/approval_sla_credit_apply creates a real pending request", %{conn: conn} do
    requester = "requester-#{System.unique_integer([:positive])}"
    org_id = real_org_slug!()

    body = %{
      "data" => %{
        "type" => "approval_sla_credit_apply",
        "attributes" => %{
          "requested_by" => requester,
          "org_id" => org_id,
          "credit_amount_cents" => 1000
        }
      }
    }

    conn =
      conn
      |> with_org_headers(org_id)
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
    org_id = real_org_slug!()
    pending = create_pending!("requester-#{System.unique_integer([:positive])}", org_id)

    body = %{
      "data" => %{
        "type" => "approval_sla_credit_apply",
        "id" => pending.id,
        "attributes" => %{"approved_by" => "approver-real-1"}
      }
    }

    conn =
      conn
      |> with_org_headers(org_id)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_sla_credit_apply/#{pending.id}", body)

    response = json_response(conn, 200)
    assert response["data"]["attributes"]["approved_by"] == "approver-real-1"

    persisted = ApprovalSlaCreditApply |> Ash.get!(pending.id, authorize?: false)
    assert persisted.approved_by == "approver-real-1"
  end

  test "PATCH .../:id rejects approval missing an approver", %{conn: conn} do
    org_id = real_org_slug!()
    pending = create_pending!("requester-#{System.unique_integer([:positive])}", org_id)

    body = %{
      "data" => %{
        "type" => "approval_sla_credit_apply",
        "id" => pending.id,
        "attributes" => %{"approved_by" => ""}
      }
    }

    conn =
      conn
      |> with_org_headers(org_id)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_sla_credit_apply/#{pending.id}", body)

    assert conn.status == 400

    persisted = ApprovalSlaCreditApply |> Ash.get!(pending.id, authorize?: false)
    assert persisted.approved_by == nil
  end

  test "PATCH .../:id rejects a requester approving their own request", %{conn: conn} do
    org_id = real_org_slug!()
    requester = "requester-#{System.unique_integer([:positive])}"
    pending = create_pending!(requester, org_id)

    body = %{
      "data" => %{
        "type" => "approval_sla_credit_apply",
        "id" => pending.id,
        "attributes" => %{"approved_by" => requester}
      }
    }

    conn =
      conn
      |> with_org_headers(org_id)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_sla_credit_apply/#{pending.id}", body)

    assert conn.status == 400

    persisted = ApprovalSlaCreditApply |> Ash.get!(pending.id, authorize?: false)
    assert persisted.approved_by == nil
  end

  test "PATCH .../:id rejects requests without the internal API token", %{conn: conn} do
    org_id = real_org_slug!()
    pending = create_pending!("requester-#{System.unique_integer([:positive])}", org_id)

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

  # Real regression test for this pass's own selected CREATE item: proves
  # the real, live-HTTP-demonstrated vulnerability found by the
  # sixteenth-pass ERRC grid sweep is now really closed. Before this pass:
  # an actor asserting ANY X-Org-Id (or a fabricated org_id payload with
  # no relationship to the actor's own asserted org at all) could create a
  # pending SLA credit request under any org identifier it invented. Now:
  # Xaas.Billing.Checks.SlaCreditActorOrgMatches denies with a real 403
  # when the actor's asserted org and the payload's own org_id disagree.
  test "POST rejects creating a request whose org_id does NOT match the actor's asserted org, not silently allowed",
       %{conn: conn} do
    attacker_org = real_org_slug!()
    fabricated_victim_org_id = "org-victim-fabricated-#{System.unique_integer([:positive])}"

    body = %{
      "data" => %{
        "type" => "approval_sla_credit_apply",
        "attributes" => %{
          "requested_by" => "attacker-requester",
          "org_id" => fabricated_victim_org_id,
          "credit_amount_cents" => 999_999
        }
      }
    }

    conn =
      conn
      |> with_org_headers(attacker_org)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> post("/api/approval_sla_credit_apply", body)

    assert conn.status == 403

    # Real cross-check: no row was persisted at all, not just a rejected
    # response -- a denied create has zero real side effects.
    assert ApprovalSlaCreditApply
           |> Ash.Query.filter(org_id == ^fabricated_victim_org_id)
           |> Ash.read!(authorize?: false) == []

    assert real_balance_for(fabricated_victim_org_id) == nil,
           "a rejected create must never open a real Ledger.Account for the fabricated org"
  end

  # This is the exact real, live-HTTP-proven exploit this pass's grid
  # sweep found and disclosed: an actor could fabricate a victim org_id,
  # create a request under it, and self-approve as its own invented
  # approver -- real money landed in a real Ledger account for an org that
  # was never authenticated, never even created. This test proves the
  # real fix -- a real 403, no approval, and zero Ledger money movement.
  test "PATCH rejects approving a request whose org_id does NOT match the actor's asserted org -- the real sixteenth-pass exploit, now closed",
       %{conn: conn} do
    victim_org = real_org_slug!()
    attacker_org = real_org_slug!()

    pending = create_pending!("victim-requester", victim_org)

    body = %{
      "data" => %{
        "type" => "approval_sla_credit_apply",
        "id" => pending.id,
        "attributes" => %{"approved_by" => "attacker-approver"}
      }
    }

    conn =
      conn
      |> with_org_headers(attacker_org)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_sla_credit_apply/#{pending.id}", body)

    assert conn.status == 403

    persisted = ApprovalSlaCreditApply |> Ash.get!(pending.id, authorize?: false)
    assert persisted.approved_by == nil,
           "a cross-org PATCH must never approve another org's real SLA credit request -- " <>
             "this is the exact sixteenth-pass live-demonstrated exploit"

    assert real_balance_for(victim_org) == nil,
           "a rejected cross-org approval must never post a real Ledger.Transfer credit"
  end
end
