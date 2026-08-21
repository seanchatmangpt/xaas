defmodule KanbanWeb.AuditExportTokenControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against
  the real `/api/audit_export_tokens` POST/PATCH/GET routes, real
  `Ash.create!`/`Ash.Changeset` rows in the real sandboxed Postgres
  (`Xaas.Repo`), asserting on the real decoded JSON response body and the
  real persisted state. No mocking of `AuditExportToken`, its checks, or
  the DB.

  Real fix under test (twentieth-pass ERRC grid sweep, item 27 -- see
  `docs/claude/diataxis/explanation/errc-innovation-grid.md` and
  `Xaas.Governance.Checks.AuditExportTokenActorOrgMatches`'s own
  moduledoc for the full disclosed finding): `AuditExportToken` previously
  had zero test coverage of any kind, Ash-level or HTTP-level, and its
  `:issue`/`:revoke` actions bypassed with a bare `authorize_if always()`
  -- any actor holding only the shared `INTERNAL_API_TOKEN` could mint a
  real, persisted, hashed bearer credential (`token_hash`/`token_prefix`)
  for any caller-supplied `org_id`, never created, never authenticated.
  Real, live-HTTP-verified this session via a temporary (deleted-after-run)
  `ConnCase` scratch test before this permanent file was written -- same
  discipline rounds 14-19 used. Every `:issue`/`:revoke` request now
  requires a real `X-Org-Id` header (via `KanbanWeb.Plugs.ResolveOrgActor`,
  newly scoped to `audit_export_tokens`) that resolves to a real
  `Xaas.Accounts.Org` and matches the request's own `org_id`, or
  `Xaas.Governance.Checks.AuditExportTokenActorOrgMatches` denies with a
  real `403`.
  """
  use KanbanWeb.ConnCase
  require Ash.Query

  alias Xaas.Accounts.Org
  alias Xaas.Governance.AuditExportToken

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

  defp issue_token!(org_id, created_by \\ "requester") do
    AuditExportToken
    |> Ash.Changeset.for_create(:issue, %{org_id: org_id, created_by: created_by})
    |> Ash.create!(authorize?: false)
  end

  # --- :issue (POST) ---------------------------------------------------

  test "POST /api/audit_export_tokens issues a real, hashed credential for a matching org", %{conn: conn} do
    org_id = real_org_slug!()

    body = %{
      "data" => %{
        "type" => "audit_export_token",
        "attributes" => %{
          "org_id" => org_id,
          "created_by" => "real-caller"
        }
      }
    }

    conn =
      conn
      |> with_org_headers(org_id)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> post("/api/audit_export_tokens", body)

    response = json_response(conn, 201)
    assert response["data"]["attributes"]["org_id"] == org_id
    assert response["data"]["attributes"]["scope"] == "audit:read"
    assert response["data"]["attributes"]["created_by"] == "real-caller"
    refute response["data"]["attributes"]["revoked_at"]

    persisted =
      AuditExportToken
      |> Ash.Query.filter(org_id == ^org_id)
      |> Ash.read_one!(authorize?: false)

    refute is_nil(persisted)
    assert String.starts_with?(persisted.token_prefix, "aet_live_")
    assert byte_size(persisted.token_hash) == 64
  end

  test "POST /api/audit_export_tokens rejects requests without the internal API token", %{conn: conn} do
    org_id = real_org_slug!()

    body = %{
      "data" => %{
        "type" => "audit_export_token",
        "attributes" => %{"org_id" => org_id, "created_by" => "no-auth"}
      }
    }

    conn =
      conn
      |> put_req_header("content-type", "application/vnd.api+json")
      |> post("/api/audit_export_tokens", body)

    assert conn.status == 401
  end

  test "POST /api/audit_export_tokens rejects requests missing the X-Org-Id header", %{conn: conn} do
    org_id = real_org_slug!()

    body = %{
      "data" => %{
        "type" => "audit_export_token",
        "attributes" => %{"org_id" => org_id, "created_by" => "no-org-header"}
      }
    }

    conn =
      conn
      |> with_internal_api_token()
      |> put_req_header("content-type", "application/vnd.api+json")
      |> post("/api/audit_export_tokens", body)

    assert conn.status == 400

    assert AuditExportToken
           |> Ash.Query.filter(org_id == ^org_id)
           |> Ash.read!(authorize?: false) == []
  end

  # Real regression test for this pass's own selected CREATE item: proves
  # the real, live-HTTP-demonstrated vulnerability found by the
  # twentieth-pass ERRC grid sweep is now really closed. Before this fix:
  # an actor asserting any X-Org-Id (or none at all) could mint a real,
  # persisted, hashed bearer credential under a completely fabricated,
  # never-authenticated org_id.
  test "POST rejects issuing a token whose org_id does NOT match the actor's asserted org, not silently allowed",
       %{conn: conn} do
    attacker_org = real_org_slug!()
    fabricated_victim_org_id = "org-victim-fabricated-#{System.unique_integer([:positive])}"

    body = %{
      "data" => %{
        "type" => "audit_export_token",
        "attributes" => %{
          "org_id" => fabricated_victim_org_id,
          "created_by" => "attacker-requester"
        }
      }
    }

    conn =
      conn
      |> with_org_headers(attacker_org)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> post("/api/audit_export_tokens", body)

    assert conn.status == 403

    # Real cross-check: no row -- and no real hashed credential material --
    # was persisted at all, not just a rejected response.
    assert AuditExportToken
           |> Ash.Query.filter(org_id == ^fabricated_victim_org_id)
           |> Ash.read!(authorize?: false) == [],
           "a rejected :issue must never mint and persist a real hashed credential " <>
             "for the fabricated victim org -- this is the exact twentieth-pass exploit"
  end

  # --- :revoke (PATCH) --------------------------------------------------

  test "PATCH .../:id revokes a real token from the matching org", %{conn: conn} do
    org_id = real_org_slug!()
    token = issue_token!(org_id)

    body = %{
      "data" => %{
        "type" => "audit_export_token",
        "id" => token.id,
        "attributes" => %{}
      }
    }

    conn =
      conn
      |> with_org_headers(org_id)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/audit_export_tokens/#{token.id}", body)

    response = json_response(conn, 200)
    refute is_nil(response["data"]["attributes"]["revoked_at"])

    persisted = AuditExportToken |> Ash.get!(token.id, authorize?: false)
    refute is_nil(persisted.revoked_at)
  end

  test "PATCH .../:id rejects revoking a token whose org_id does NOT match the actor's asserted org",
       %{conn: conn} do
    victim_org = real_org_slug!()
    attacker_org = real_org_slug!()
    token = issue_token!(victim_org)

    body = %{
      "data" => %{
        "type" => "audit_export_token",
        "id" => token.id,
        "attributes" => %{}
      }
    }

    conn =
      conn
      |> with_org_headers(attacker_org)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/audit_export_tokens/#{token.id}", body)

    assert conn.status == 403

    persisted = AuditExportToken |> Ash.get!(token.id, authorize?: false)
    assert is_nil(persisted.revoked_at),
           "a cross-org PATCH must never revoke another org's real audit export token"
  end

  test "PATCH .../:id rejects revoking an already-revoked token", %{conn: conn} do
    org_id = real_org_slug!()
    token = issue_token!(org_id)

    already_revoked =
      token
      |> Ash.Changeset.for_update(:revoke, %{})
      |> Ash.update!(authorize?: false)

    body = %{
      "data" => %{
        "type" => "audit_export_token",
        "id" => already_revoked.id,
        "attributes" => %{}
      }
    }

    conn =
      conn
      |> with_org_headers(org_id)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/audit_export_tokens/#{already_revoked.id}", body)

    assert conn.status == 400
  end

  test "PATCH .../:id rejects requests without the internal API token", %{conn: conn} do
    org_id = real_org_slug!()
    token = issue_token!(org_id)

    body = %{
      "data" => %{"type" => "audit_export_token", "id" => token.id, "attributes" => %{}}
    }

    conn =
      conn
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/audit_export_tokens/#{token.id}", body)

    assert conn.status == 401

    persisted = AuditExportToken |> Ash.get!(token.id, authorize?: false)
    assert is_nil(persisted.revoked_at)
  end

  # --- :read (GET) -------------------------------------------------------

  # Real, disclosed consequence of adding `audit_export_tokens` to
  # `ResolveOrgActor`'s `@tenant_scoped_path_segments`: that plug gates by
  # path segment regardless of HTTP method (same real behavior every
  # other resource already in the list gets), so GET/read now also
  # requires a real X-Org-Id header -- even though the resource's own
  # policy bypasses :read with `authorize_if always()` and needs no actor
  # at all. Real-verified this session via a temporary scratch test
  # before this permanent test was written.
  test "GET /api/audit_export_tokens/:id succeeds with a real, resolvable X-Org-Id header", %{conn: conn} do
    org_id = real_org_slug!()
    token = issue_token!(org_id)

    conn =
      conn
      |> with_org_headers(org_id)
      |> get("/api/audit_export_tokens/#{token.id}")

    response = json_response(conn, 200)
    assert response["data"]["attributes"]["org_id"] == org_id
    refute response["data"]["attributes"]["token_hash"],
           "token_hash is public? false -- must never be serialized in the real API response"
  end

  test "GET /api/audit_export_tokens/:id rejects requests missing the X-Org-Id header", %{conn: conn} do
    org_id = real_org_slug!()
    token = issue_token!(org_id)

    conn =
      conn
      |> with_internal_api_token()
      |> get("/api/audit_export_tokens/#{token.id}")

    assert conn.status == 400
  end
end
