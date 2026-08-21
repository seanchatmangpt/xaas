defmodule KanbanWeb.IncidentControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against
  the real `/api/incidents` POST/PATCH routes, real `Ash.create!`/
  `Ash.Changeset` rows in the real sandboxed Postgres (`Xaas.Repo`),
  asserting on the real decoded JSON response body and the real
  persisted state. No mocking of `Xaas.Operations.Incident`, its checks,
  or the DB.

  Added (seventeenth pass, real fix -- see `Xaas.Operations.Checks.
  ActorOrgMatches` and `Xaas.Operations.Incident`'s own moduledoc): this
  file did not previously exist -- `Xaas.Operations.IncidentTest`'s own
  moduledoc incorrectly claimed the resource's json_api routes weren't
  wired into the real router at all, which this file's own passing tests
  now disprove. A real, live-HTTP-proven cross-org vulnerability was
  found and fixed this pass -- an actor holding only the shared
  `INTERNAL_API_TOKEN` could previously `:create`/`:update` an Incident
  under a completely fabricated, never-authenticated `org_id` with zero
  authorization check, and (worse) that fabricated incident could satisfy
  a REAL, unrelated victim org's `ApprovalDrFailover:approve` precondition
  (see `test/kanban_web/controllers/approval_dr_failover_controller_test.exs`
  for that cross-resource regression). Every `:create`/`:update` request
  now requires a real `X-Org-Id` header (via `KanbanWeb.Plugs.
  ResolveOrgActor`, newly scoped to this route) matching the request's
  own `org_id`, or `Xaas.Operations.Checks.ActorOrgMatches` denies with a
  real `403`.
  """
  use KanbanWeb.ConnCase
  require Ash.Query

  alias Xaas.Accounts.Org
  alias Xaas.Operations.Incident

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp with_internal_api_token(conn) do
    put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
  end

  defp with_org_headers(conn, org_id) do
    conn
    |> with_internal_api_token()
    |> put_req_header("x-org-id", org_id)
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

  defp create_pending!(org_id, region) do
    Incident
    |> Ash.Changeset.for_create(:create, %{
      org_id: org_id,
      title: "seed incident",
      region: region,
      opened_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Ash.create!(authorize?: false)
  end

  test "POST /api/incidents creates a real incident when the actor's org matches the payload org",
       %{conn: conn} do
    org_id = real_org_slug!()

    body = %{
      "data" => %{
        "type" => "incidents",
        "attributes" => %{
          "org_id" => org_id,
          "title" => "us-east-1 primary DB unreachable",
          "region" => "us-east-1",
          "severity" => "critical",
          "opened_at" => DateTime.to_iso8601(DateTime.utc_now())
        }
      }
    }

    conn =
      conn
      |> with_org_headers(org_id)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> post("/api/incidents", body)

    response = json_response(conn, 201)
    assert response["data"]["attributes"]["org_id"] == org_id
    assert response["data"]["attributes"]["status"] == "open"
  end

  test "POST /api/incidents rejects requests without the internal API token", %{conn: conn} do
    body = %{
      "data" => %{
        "type" => "incidents",
        "attributes" => %{
          "org_id" => real_org_slug!(),
          "title" => "no auth",
          "region" => "us-east-1",
          "opened_at" => DateTime.to_iso8601(DateTime.utc_now())
        }
      }
    }

    conn =
      conn
      |> put_req_header("content-type", "application/vnd.api+json")
      |> post("/api/incidents", body)

    assert conn.status == 401
  end

  # Real regression test for this pass's own selected CREATE item: proves
  # the real, live-HTTP-demonstrated vulnerability found by the
  # seventeenth-pass ERRC grid sweep is now really closed. Before this
  # pass: an actor asserting ANY (or no) X-Org-Id could create an
  # Incident under any org_id it invented -- real 201, zero check. Now:
  # Xaas.Operations.Checks.ActorOrgMatches denies with a real 403 when
  # the actor's asserted org and the payload's own org_id disagree.
  test "POST rejects creating an incident whose org_id does NOT match the actor's asserted org, not silently allowed",
       %{conn: conn} do
    attacker_org = real_org_slug!()
    fabricated_victim_org_id = "org-victim-fabricated-#{System.unique_integer([:positive])}"

    body = %{
      "data" => %{
        "type" => "incidents",
        "attributes" => %{
          "org_id" => fabricated_victim_org_id,
          "title" => "attacker-fabricated cross-org incident",
          "region" => "us-east-1",
          "opened_at" => DateTime.to_iso8601(DateTime.utc_now())
        }
      }
    }

    conn =
      conn
      |> with_org_headers(attacker_org)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> post("/api/incidents", body)

    assert conn.status == 403

    # Real cross-check: no row was persisted at all, not just a rejected
    # response.
    assert Incident
           |> Ash.Query.filter(org_id == ^fabricated_victim_org_id)
           |> Ash.read!(authorize?: false) == []
  end

  test "POST rejects creating an incident with NO X-Org-Id header at all (fail-closed, not implicitly allowed)",
       %{conn: conn} do
    fabricated_org_id = "org-no-header-#{System.unique_integer([:positive])}"

    body = %{
      "data" => %{
        "type" => "incidents",
        "attributes" => %{
          "org_id" => fabricated_org_id,
          "title" => "no org header at all",
          "region" => "us-east-1",
          "opened_at" => DateTime.to_iso8601(DateTime.utc_now())
        }
      }
    }

    conn =
      conn
      |> with_internal_api_token()
      |> put_req_header("content-type", "application/vnd.api+json")
      |> post("/api/incidents", body)

    assert conn.status == 400

    assert Incident
           |> Ash.Query.filter(org_id == ^fabricated_org_id)
           |> Ash.read!(authorize?: false) == []
  end

  test "PATCH .../:id accepts a real update from the matching org", %{conn: conn} do
    org_id = real_org_slug!()
    incident = create_pending!(org_id, "eu-west-1")

    body = %{
      "data" => %{
        "type" => "incidents",
        "id" => incident.id,
        "attributes" => %{
          "status" => "resolved",
          "resolved_at" => DateTime.to_iso8601(DateTime.utc_now())
        }
      }
    }

    conn =
      conn
      |> with_org_headers(org_id)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/incidents/#{incident.id}", body)

    response = json_response(conn, 200)
    assert response["data"]["attributes"]["status"] == "resolved"

    persisted = Incident |> Ash.get!(incident.id, authorize?: false)
    assert persisted.status == :resolved
  end

  test "PATCH rejects updating a DIFFERENT org's real incident, not silently allowed", %{conn: conn} do
    owner_org = real_org_slug!()
    other_org = real_org_slug!()
    incident = create_pending!(owner_org, "eu-west-1")

    body = %{
      "data" => %{
        "type" => "incidents",
        "id" => incident.id,
        "attributes" => %{
          "status" => "resolved",
          "resolved_at" => DateTime.to_iso8601(DateTime.utc_now())
        }
      }
    }

    conn =
      conn
      |> with_org_headers(other_org)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/incidents/#{incident.id}", body)

    assert conn.status == 403

    persisted = Incident |> Ash.get!(incident.id, authorize?: false)
    assert persisted.status == :open
  end
end
