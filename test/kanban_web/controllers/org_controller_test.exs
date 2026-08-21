defmodule KanbanWeb.OrgControllerTest do
  @moduledoc """
  Real Chicago-style tests: real Phoenix ConnCase HTTP requests against
  the real `/api/orgs` POST/PATCH routes, real Ash-persisted rows in the
  real sandboxed Postgres (Xaas.Repo). No mocking.

  Real regression coverage for the nineteenth-pass ERRC grid's own
  selected CREATE item: before this pass, `POST /api/orgs` and
  `PATCH /api/orgs/:id` were both unconditional real `HTTP 403` for every
  real caller -- fresh-reproduced via a temporary, deleted-after-run
  `ConnCase` test before any fix landed (same discipline rounds 14-18
  used). No `test/kanban_web/controllers/org_controller_test.exs` existed
  before this pass (`org_test.exs`'s own direct-`Ash.update!` tests never
  exercised the real HTTP/AshJsonApi path -- see `org.ex`'s own moduledoc
  for the full disclosure of why that gap existed).
  """
  use KanbanWeb.ConnCase

  alias Xaas.Accounts.{Org, OrgMembership, User}

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp with_internal_api_token(conn) do
    put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
  end

  defp json_headers(conn) do
    conn
    |> with_internal_api_token()
    |> put_req_header("content-type", "application/vnd.api+json")
    |> put_req_header("accept", "application/vnd.api+json")
  end

  defp json_headers(conn, org_id) do
    conn |> json_headers() |> put_req_header("x-org-id", org_id)
  end

  defp real_org!(name) do
    Org
    |> Ash.Changeset.for_create(:create, %{
      name: name,
      slug: "org-#{System.unique_integer([:positive])}"
    })
    |> Ash.create!(authorize?: false)
  end

  # --- POST /api/orgs (Gap A, :create half) ---

  test "POST creates a real org for any real Bearer-token-authenticated caller (legitimate case)",
       %{conn: conn} do
    slug = "created-#{System.unique_integer([:positive])}"

    create_body = %{
      "data" => %{
        "type" => "org",
        "attributes" => %{"name" => "New Co", "slug" => slug}
      }
    }

    resp = conn |> json_headers() |> post("/api/orgs", create_body)

    # Real, disclosed, pre-existing limitation (unrelated to this pass's
    # fix -- see org_test.exs's own "an actor with no real iam_policy is
    # really denied read" test): the minimal `%{}` actor this plug now
    # supplies for :create has no `iam_policy`, so AshIam's field
    # authorization real-serializes every attribute as `null` in the HTTP
    # response even though the real row was really written -- asserting
    # only the real persisted state, via `authorize?: false`, same
    # established convention as every other AshIam-gated resource test in
    # this codebase.
    created = json_response(resp, 201)
    id = created["data"]["id"]
    refute is_nil(id)

    persisted = Org |> Ash.get!(id, authorize?: false)
    assert persisted.name == "New Co"
    assert persisted.slug == slug
    assert persisted.status == :active
  end

  test "POST with no Bearer token at all is real-401'd, before this plug ever runs",
       %{conn: conn} do
    create_body = %{
      "data" => %{
        "type" => "org",
        "attributes" => %{"name" => "No Token Co", "slug" => "no-token-#{System.unique_integer([:positive])}"}
      }
    }

    resp =
      conn
      |> put_req_header("content-type", "application/vnd.api+json")
      |> put_req_header("accept", "application/vnd.api+json")
      |> post("/api/orgs", create_body)

    assert resp.status == 401
  end

  # --- PATCH /api/orgs/:id (Gap A, :update half + actor-shape fix) ---

  test "PATCH updates the org when X-Org-Id matches the org being updated (org-token actor, legitimate case)",
       %{conn: conn} do
    org = real_org!("Mutable Co")

    update_body = %{
      "data" => %{
        "type" => "org",
        "id" => org.id,
        "attributes" => %{"name" => "Mutable Co Renamed"}
      }
    }

    resp = conn |> json_headers(org.slug) |> patch("/api/orgs/#{org.id}", update_body)

    # Real, disclosed, pre-existing limitation (see
    # Xaas.Accounts.Checks.ActorOrgSelfFilter's own moduledoc): a
    # FilterCheck-authorized read/update real-serializes attribute VALUES
    # as `null` for an org-token actor with no `iam_policy` -- asserting
    # the real persisted state, via `authorize?: false`, same established
    # convention as every other AshIam-gated resource test in this
    # codebase.
    _updated = json_response(resp, 200)

    persisted = Org |> Ash.get!(org.id, authorize?: false)
    assert persisted.name == "Mutable Co Renamed"
  end

  test "PATCH updates the org for a real per-user OrgMembership actor too (direct Ash call, shape 1 preserved)" do
    org = real_org!("Membership Co")

    user =
      Ash.Seed.seed!(User, %{
        email: "member-#{System.unique_integer([:positive])}@example.com"
      })

    OrgMembership
    |> Ash.Changeset.for_create(:create, %{user_id: user.id, org_id: org.id, role: :admin})
    |> Ash.create!(authorize?: false)

    org
    |> Ash.Changeset.for_update(:update, %{name: "Membership Co Renamed"}, actor: user)
    |> Ash.update!()

    persisted = Org |> Ash.get!(org.id, authorize?: false)
    assert persisted.name == "Membership Co Renamed"
  end

  test "PATCH rejects updating a DIFFERENT org than the one X-Org-Id asserts, not silently allowed",
       %{conn: conn} do
    owner_org = real_org!("Owner Co")
    other_org = real_org!("Other Co")

    update_body = %{
      "data" => %{
        "type" => "org",
        "id" => owner_org.id,
        "attributes" => %{"name" => "Hijacked"}
      }
    }

    resp = conn |> json_headers(other_org.slug) |> patch("/api/orgs/#{owner_org.id}", update_body)

    # Real 404, not 403: Xaas.Accounts.Checks.ActorOrgSelfFilter's real
    # `WHERE slug = ...` filter makes owner_org's row simply not exist
    # from other_org's actor's point of view -- the same real, established
    # "hide existence, not just deny" convention
    # test/kanban_web/controllers/resolve_org_actor_test.exs already
    # proves for the other tenant-scoped resources (its own "org A CANNOT
    # real-read org B's row... real 404, not silently empty/allowed" and
    # "...CANNOT real-approve org B's row" tests).
    assert resp.status == 404

    persisted = Org |> Ash.get!(owner_org.id, authorize?: false)
    assert persisted.name == "Owner Co"
  end

  test "PATCH rejects a request with no X-Org-Id header at all (400, fail-closed, not implicitly allowed)",
       %{conn: conn} do
    org = real_org!("Headerless Co")

    update_body = %{
      "data" => %{
        "type" => "org",
        "id" => org.id,
        "attributes" => %{"name" => "Should Not Change"}
      }
    }

    resp = conn |> json_headers() |> patch("/api/orgs/#{org.id}", update_body)

    assert resp.status == 400
    assert json_response(resp, 400)["error"] == "missing_org_id"

    persisted = Org |> Ash.get!(org.id, authorize?: false)
    assert persisted.name == "Headerless Co"
  end

  test "PATCH rejects an X-Org-Id that resolves to no real Org (404)", %{conn: conn} do
    org = real_org!("Real Target Co")

    update_body = %{
      "data" => %{
        "type" => "org",
        "id" => org.id,
        "attributes" => %{"name" => "Should Not Change"}
      }
    }

    resp =
      conn
      |> json_headers("does-not-exist-#{System.unique_integer([:positive])}")
      |> patch("/api/orgs/#{org.id}", update_body)

    assert resp.status == 404
  end

  # --- Gap B (atomic-eligibility) regression coverage ---

  test "PATCH suspending an org without a suspension_reason is really rejected (real business rule)",
       %{conn: conn} do
    org = real_org!("Suspend Me Co")

    update_body = %{
      "data" => %{
        "type" => "org",
        "id" => org.id,
        "attributes" => %{"status" => "suspended"}
      }
    }

    resp = conn |> json_headers(org.slug) |> patch("/api/orgs/#{org.id}", update_body)

    # 400, matching this codebase's established convention for a real Ash
    # validation error surfaced through AshJsonApi (see
    # route_orgs_custom_domain_controller_test.exs's own "POST rejects an
    # invalid hostname" test).
    assert resp.status == 400

    persisted = Org |> Ash.get!(org.id, authorize?: false)
    assert persisted.status == :active
  end

  test "PATCH suspending an org WITH a real suspension_reason succeeds end-to-end (proves the atomic-ineligibility fix, not just the actor fix)",
       %{conn: conn} do
    org = real_org!("Suspend Me Properly Co")

    update_body = %{
      "data" => %{
        "type" => "org",
        "id" => org.id,
        "attributes" => %{"status" => "suspended", "suspension_reason" => "non-payment"}
      }
    }

    resp = conn |> json_headers(org.slug) |> patch("/api/orgs/#{org.id}", update_body)

    # Real, disclosed limitation (see the previous test's own comment):
    # response body attribute values are redacted for this actor shape,
    # so this asserts the real persisted state instead.
    _updated = json_response(resp, 200)

    persisted = Org |> Ash.get!(org.id, authorize?: false)
    assert persisted.status == :suspended
    assert persisted.suspension_reason == "non-payment"
  end
end
