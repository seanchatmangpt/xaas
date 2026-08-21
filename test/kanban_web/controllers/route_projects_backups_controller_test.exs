defmodule KanbanWeb.RouteProjectsBackupsControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against the
  real `/api/route_projects_backups` POST route (ported from
  platform-console's `POST /api/orgs/[id]/backups`), real Ash-persisted
  rows in the real sandboxed Postgres (Xaas.Repo). No mocking.

  Extended eighteenth pass (real fix -- see `Xaas.Platform.Checks.
  ActorOrgMatches` and `RouteProjectsBackups`'s own moduledoc): a real,
  live-HTTP-proven cross-org vulnerability was found and fixed this pass --
  an actor holding only the shared `INTERNAL_API_TOKEN` could previously
  `:create` a backup-history row under a completely fabricated,
  never-authenticated `org_id` with zero authorization check. Every
  `:create` request now requires a real `X-Org-Id` header (via
  `KanbanWeb.Plugs.ResolveOrgActor`, newly scoped to this route) that
  resolves to a real `Xaas.Accounts.Org` and matches the request's own
  `org_id`, or `Xaas.Platform.Checks.ActorOrgMatches` denies with a real
  `403`. The pre-existing tests below were updated to send a real, matching
  `X-Org-Id` header so they continue to exercise their own named behavior
  (not incidentally pass/fail on the new org check); the 2 new tests at the
  bottom prove the real cross-org rejection.
  """
  use KanbanWeb.ConnCase

  require Ash.Query

  alias Xaas.Accounts.Org
  alias Xaas.Platform.RouteProjectsBackups

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp with_internal_api_token(conn) do
    put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
  end

  # Real, required since the eighteenth-pass fix: :create now requires a
  # real, caller-asserted X-Org-Id header (resolved by
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
  # RouteProjectsBackups's own policy check.
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

  test "POST creates a real backup record with real fields", %{conn: conn} do
    org_id = real_org_slug!()
    taken_at = DateTime.utc_now() |> DateTime.truncate(:second)
    retain_until = DateTime.add(taken_at, 30, :day)

    create_body = %{
      "data" => %{
        "type" => "route_projects_backups",
        "attributes" => %{
          "org_id" => org_id,
          "namespace" => "ns-#{org_id}",
          "project_name" => "my-real-project",
          "job_name" => "backup-job-1",
          "taken_at" => DateTime.to_iso8601(taken_at),
          "size_bytes" => 0,
          "retain_until" => DateTime.to_iso8601(retain_until)
        }
      }
    }

    resp = conn |> json_headers(org_id) |> post("/api/route_projects_backups", create_body)
    created = json_response(resp, 201)
    id = created["data"]["id"]

    persisted = RouteProjectsBackups |> Ash.get!(id, authorize?: false)
    assert persisted.org_id == org_id
    assert persisted.namespace == "ns-#{org_id}"
    assert persisted.project_name == "my-real-project"
    assert persisted.job_name == "backup-job-1"
    assert persisted.taken_at == taken_at
    assert persisted.size_bytes == 0
    assert persisted.retain_until == retain_until
    assert persisted.status == :pending
  end

  test "POST rejects a real invalid project_name", %{conn: conn} do
    org_id = real_org_slug!()
    taken_at = DateTime.utc_now() |> DateTime.truncate(:second)
    retain_until = DateTime.add(taken_at, 30, :day)

    create_body = %{
      "data" => %{
        "type" => "route_projects_backups",
        "attributes" => %{
          "org_id" => org_id,
          "namespace" => "ns-#{org_id}",
          "project_name" => "   ",
          "job_name" => "backup-job-1",
          "taken_at" => DateTime.to_iso8601(taken_at),
          "size_bytes" => 0,
          "retain_until" => DateTime.to_iso8601(retain_until)
        }
      }
    }

    resp = conn |> json_headers(org_id) |> post("/api/route_projects_backups", create_body)
    assert resp.status == 400
  end

  # Real regression test for this pass's own selected CREATE item: proves
  # the real, live-HTTP-demonstrated vulnerability found by the
  # eighteenth-pass ERRC grid sweep is now really closed. Before this pass:
  # an actor asserting ANY (or no) X-Org-Id could fabricate a
  # backup-history row under any org_id it invented -- real 201, zero
  # check. Now: Xaas.Platform.Checks.ActorOrgMatches denies with a real 403
  # when the actor's asserted org and the payload's own org_id disagree.
  test "POST rejects creating a backup record whose org_id does NOT match the actor's asserted org, not silently allowed",
       %{conn: conn} do
    attacker_org = real_org_slug!()
    fabricated_victim_org_id = "org-victim-fabricated-#{System.unique_integer([:positive])}"
    taken_at = DateTime.utc_now() |> DateTime.truncate(:second)
    retain_until = DateTime.add(taken_at, 30, :day)

    create_body = %{
      "data" => %{
        "type" => "route_projects_backups",
        "attributes" => %{
          "org_id" => fabricated_victim_org_id,
          "namespace" => "ns-#{fabricated_victim_org_id}",
          "project_name" => "attacker-fabricated-project",
          "job_name" => "attacker-job",
          "taken_at" => DateTime.to_iso8601(taken_at),
          "size_bytes" => 0,
          "retain_until" => DateTime.to_iso8601(retain_until)
        }
      }
    }

    resp =
      conn
      |> json_headers(attacker_org)
      |> post("/api/route_projects_backups", create_body)

    assert resp.status == 403

    # Real cross-check: no row was persisted at all, not just a rejected
    # response -- a denied create must never fabricate a backup-history row.
    assert RouteProjectsBackups
           |> Ash.Query.filter(org_id == ^fabricated_victim_org_id)
           |> Ash.read!(authorize?: false) == []
  end

  test "POST rejects creating a backup record with NO X-Org-Id header at all (fail-closed, not implicitly allowed)",
       %{conn: conn} do
    fabricated_org_id = "org-no-header-#{System.unique_integer([:positive])}"
    taken_at = DateTime.utc_now() |> DateTime.truncate(:second)
    retain_until = DateTime.add(taken_at, 30, :day)

    create_body = %{
      "data" => %{
        "type" => "route_projects_backups",
        "attributes" => %{
          "org_id" => fabricated_org_id,
          "namespace" => "ns-#{fabricated_org_id}",
          "project_name" => "no-header-project",
          "job_name" => "no-header-job",
          "taken_at" => DateTime.to_iso8601(taken_at),
          "size_bytes" => 0,
          "retain_until" => DateTime.to_iso8601(retain_until)
        }
      }
    }

    resp =
      conn
      |> with_internal_api_token()
      |> put_req_header("content-type", "application/vnd.api+json")
      |> put_req_header("accept", "application/vnd.api+json")
      |> post("/api/route_projects_backups", create_body)

    assert resp.status == 400

    assert RouteProjectsBackups
           |> Ash.Query.filter(org_id == ^fabricated_org_id)
           |> Ash.read!(authorize?: false) == []
  end
end
