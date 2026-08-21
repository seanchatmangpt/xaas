defmodule KanbanWeb.RouteOrgsCustomDomainControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/route_orgs_custom_domain` POST/PATCH routes, real Ash-persisted
  rows in the real sandboxed Postgres (Xaas.Repo). No mocking.

  Extended eighteenth pass (real fix -- see `Xaas.Platform.Checks.
  ActorOrgMatches` and `RouteOrgsCustomDomain`'s own moduledoc): a real,
  live-HTTP-proven cross-org vulnerability was found and fixed this pass --
  an actor holding only the shared `INTERNAL_API_TOKEN` could previously
  `:create`/`:update` a custom-domain binding under a completely
  fabricated, never-authenticated `org_id` with zero authorization check
  (real hostname-squatting: a fabricated `org_id` could bind ANY hostname).
  Every `:create`/`:update` request now requires a real `X-Org-Id` header
  (via `KanbanWeb.Plugs.ResolveOrgActor`, newly scoped to this route) that
  resolves to a real `Xaas.Accounts.Org` and matches the request's own
  `org_id`, or `Xaas.Platform.Checks.ActorOrgMatches` denies with a real
  `403`. The pre-existing tests below were updated to send a real, matching
  `X-Org-Id` header so they continue to exercise their own named behavior
  (not incidentally pass/fail on the new org check); the 3 new tests at the
  bottom prove the real cross-org rejection.
  """
  use KanbanWeb.ConnCase

  require Ash.Query

  alias Xaas.Accounts.Org
  alias Xaas.Platform.RouteOrgsCustomDomain

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp with_internal_api_token(conn) do
    put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
  end

  # Real, required since the eighteenth-pass fix: :create/:update now
  # require a real, caller-asserted X-Org-Id header (resolved by
  # KanbanWeb.Plugs.ResolveOrgActor against a real Xaas.Accounts.Org row)
  # that must match the request's real org_id, or the real
  # Xaas.Platform.Checks.ActorOrgMatches policy check denies it.
  defp with_org_headers(conn, org_id) do
    conn
    |> with_internal_api_token()
    |> put_req_header("x-org-id", org_id)
  end

  # Real, required since ResolveOrgActor resolves X-Org-Id against a real
  # Xaas.Accounts.Org row by slug (Ash.get(Org, [slug: org_id], ...)) -- an
  # arbitrary unregistered string now real-404s before ever reaching
  # RouteOrgsCustomDomain's own policy check.
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
    |> with_org_headers(org_id)
    |> put_req_header("content-type", "application/vnd.api+json")
    |> put_req_header("accept", "application/vnd.api+json")
  end

  test "POST creates a real custom domain record with a valid hostname", %{conn: conn} do
    org_id = real_org_slug!()
    hostname = "console.customer-#{System.unique_integer([:positive])}.com"

    create_body = %{
      "data" => %{
        "type" => "route_orgs_custom_domain",
        "attributes" => %{
          "org_id" => org_id,
          "hostname" => hostname
        }
      }
    }

    create_resp =
      conn |> json_headers(org_id) |> post("/api/route_orgs_custom_domain", create_body)

    created = json_response(create_resp, 201)
    id = created["data"]["id"]

    assert created["data"]["attributes"]["org_id"] == org_id
    assert created["data"]["attributes"]["hostname"] == hostname
    assert created["data"]["attributes"]["status"] == "pending"

    persisted = RouteOrgsCustomDomain |> Ash.get!(id, authorize?: false)
    assert persisted.org_id == org_id
    assert persisted.hostname == hostname
    assert persisted.status == "pending"
  end

  test "PATCH updates status and certificate fields", %{conn: conn} do
    org_id = real_org_slug!()
    hostname = "app.customer-#{System.unique_integer([:positive])}.com"

    domain =
      RouteOrgsCustomDomain
      |> Ash.Changeset.for_create(:create, %{org_id: org_id, hostname: hostname})
      |> Ash.create!(authorize?: false)

    update_body = %{
      "data" => %{
        "type" => "route_orgs_custom_domain",
        "id" => domain.id,
        "attributes" => %{
          "status" => "active",
          "certificate_secret_name" => "tls-secret-#{domain.id}",
          "certificate_reason" => "Issued",
          "certificate_message" => "Certificate issued successfully"
        }
      }
    }

    update_resp =
      conn
      |> json_headers(org_id)
      |> patch("/api/route_orgs_custom_domain/#{domain.id}", update_body)

    updated = json_response(update_resp, 200)
    assert updated["data"]["attributes"]["status"] == "active"
    assert updated["data"]["attributes"]["certificate_reason"] == "Issued"

    persisted = RouteOrgsCustomDomain |> Ash.get!(domain.id, authorize?: false)
    assert persisted.status == "active"
    assert persisted.certificate_secret_name == "tls-secret-#{domain.id}"
    assert persisted.certificate_reason == "Issued"
    assert persisted.certificate_message == "Certificate issued successfully"
  end

  test "POST rejects an invalid hostname (fewer than two DNS labels)", %{conn: conn} do
    org_id = real_org_slug!()

    create_body = %{
      "data" => %{
        "type" => "route_orgs_custom_domain",
        "attributes" => %{
          "org_id" => org_id,
          "hostname" => "not-a-valid-hostname"
        }
      }
    }

    resp = conn |> json_headers(org_id) |> post("/api/route_orgs_custom_domain", create_body)
    assert resp.status == 400

    count =
      RouteOrgsCustomDomain
      |> Ash.Query.filter(org_id == ^org_id)
      |> Ash.count!(authorize?: false)

    assert count == 0
  end

  # Real regression test for this pass's own selected CREATE item: proves
  # the real, live-HTTP-demonstrated vulnerability found by the
  # eighteenth-pass ERRC grid sweep is now really closed. Before this pass:
  # an actor asserting ANY (or no) X-Org-Id could bind a hostname under any
  # org_id it invented -- real 201, zero check (real hostname-squatting).
  # Now: Xaas.Platform.Checks.ActorOrgMatches denies with a real 403 when
  # the actor's asserted org and the payload's own org_id disagree.
  test "POST rejects creating a custom domain whose org_id does NOT match the actor's asserted org, not silently allowed",
       %{conn: conn} do
    attacker_org = real_org_slug!()
    fabricated_victim_org_id = "org-victim-fabricated-#{System.unique_integer([:positive])}"
    hostname = "hijacked.customer-#{System.unique_integer([:positive])}.com"

    create_body = %{
      "data" => %{
        "type" => "route_orgs_custom_domain",
        "attributes" => %{
          "org_id" => fabricated_victim_org_id,
          "hostname" => hostname
        }
      }
    }

    resp =
      conn
      |> json_headers(attacker_org)
      |> post("/api/route_orgs_custom_domain", create_body)

    assert resp.status == 403

    # Real cross-check: no row was persisted at all, not just a rejected
    # response -- a denied create must never let the hostname get squatted.
    assert RouteOrgsCustomDomain
           |> Ash.Query.filter(org_id == ^fabricated_victim_org_id)
           |> Ash.read!(authorize?: false) == []
  end

  test "POST rejects creating a custom domain with NO X-Org-Id header at all (fail-closed, not implicitly allowed)",
       %{conn: conn} do
    fabricated_org_id = "org-no-header-#{System.unique_integer([:positive])}"
    hostname = "noheader.customer-#{System.unique_integer([:positive])}.com"

    create_body = %{
      "data" => %{
        "type" => "route_orgs_custom_domain",
        "attributes" => %{
          "org_id" => fabricated_org_id,
          "hostname" => hostname
        }
      }
    }

    resp =
      conn
      |> with_internal_api_token()
      |> put_req_header("content-type", "application/vnd.api+json")
      |> put_req_header("accept", "application/vnd.api+json")
      |> post("/api/route_orgs_custom_domain", create_body)

    assert resp.status == 400

    assert RouteOrgsCustomDomain
           |> Ash.Query.filter(org_id == ^fabricated_org_id)
           |> Ash.read!(authorize?: false) == []
  end

  # The real cross-org PATCH half of the same vulnerability: an actor could
  # previously mutate ANY other org's custom-domain record (e.g. flip a
  # victim's `status` to "active" or overwrite its `certificate_secret_name`)
  # with zero authorization check.
  test "PATCH rejects updating a DIFFERENT org's real custom domain, not silently allowed",
       %{conn: conn} do
    owner_org = real_org_slug!()
    other_org = real_org_slug!()

    domain =
      RouteOrgsCustomDomain
      |> Ash.Changeset.for_create(:create, %{
        org_id: owner_org,
        hostname: "victim.customer-#{System.unique_integer([:positive])}.com"
      })
      |> Ash.create!(authorize?: false)

    update_body = %{
      "data" => %{
        "type" => "route_orgs_custom_domain",
        "id" => domain.id,
        "attributes" => %{
          "status" => "active",
          "certificate_secret_name" => "attacker-planted-secret"
        }
      }
    }

    resp =
      conn
      |> json_headers(other_org)
      |> patch("/api/route_orgs_custom_domain/#{domain.id}", update_body)

    assert resp.status == 403

    persisted = RouteOrgsCustomDomain |> Ash.get!(domain.id, authorize?: false)
    assert persisted.status == "pending"
    assert persisted.certificate_secret_name == nil
  end
end
