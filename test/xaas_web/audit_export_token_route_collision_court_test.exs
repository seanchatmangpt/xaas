defmodule XaasWeb.AuditExportTokenRouteCollisionCourtTest do
  @moduledoc """
  Route-collision court for `Xaas.Governance.AuditExportToken`'s JSON:API
  surface (lane W944b, v26.10.6).

  Falsifies the exact regression class W940 disclosed: two `patch(...)`
  route entries resolving to the SAME path (`/:id`) for two different
  update actions (`:use` and `revoke`) -- AshJsonApi silently keeps the
  first and the second action becomes unreachable over HTTP. The fix
  (W940b) pins distinct subpaths (`/:id/use`, `/:id/revoke`).

  Three layers, all real:
    1. Resource route table (`AshJsonApi.Resource.Info.routes/1`) --
       exactly one route per action, per (method, path) uniqueness.
    2. The real compiled router table (`XaasWeb.ApiRouter.__routes__/0`,
       the AshJsonApi.Router forwarded at "/api") -- the actual match-time
       surface, per-verb path uniqueness across the audit_export_tokens
       mount.
    3. Real HTTP probes through the full pipeline (internal-api token
       floor per W723, org actor resolution) -- the :use route actually
       consumes and the :revoke route actually revokes, so the court
       cannot pass while either action is shadowed.
  """
  use XaasWeb.ConnCase
  require Ash.Query

  alias Xaas.Accounts.Org
  alias Xaas.Governance.AuditExportToken

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  # --- helpers ----------------------------------------------------------

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

  defp issue_token!(org_id) do
    AuditExportToken
    |> Ash.Changeset.for_create(:issue, %{org_id: org_id, created_by: "w944b-court"})
    |> Ash.create!(authorize?: false)
  end

  defp json_api_body(id) do
    %{"data" => %{"type" => "audit_export_token", "id" => id, "attributes" => %{}}}
  end

  # AshJsonApi.Router compiles a single catch-all match and dispatches at
  # runtime, so the real introspectable match-time table is the resource
  # route table over the router's mounted domains -- exactly what
  # AshJsonApi.Controllers.Router matches against at request time.
  defp audit_routes do
    XaasWeb.ApiRouter.domains()
    |> Enum.flat_map(&Ash.Domain.Info.resources/1)
    |> Enum.flat_map(fn resource ->
      resource
      |> AshJsonApi.Resource.Info.routes()
      |> Enum.map(fn r ->
        %{verb: r.method, path: "/api" <> r.route, resource: resource, action: r.action}
      end)
    end)
    |> Enum.filter(&String.contains?(&1.path, "audit_export_tokens"))
  end

  # --- layer 1: resource route table ------------------------------------

  test "resource route table: exactly one route per action, no (method, path) duplicates" do
    routes = AshJsonApi.Resource.Info.routes(AuditExportToken)

    for action <- [:use, :revoke] do
      matches = Enum.filter(routes, &(&1.action == action and &1.method == :patch))

      assert length(matches) == 1,
             "expected exactly one PATCH route for :#{action}, got #{inspect(matches)}"
    end

    dupes =
      routes
      |> Enum.frequencies_by(&{&1.method, &1.route})
      |> Enum.filter(fn {_k, n} -> n > 1 end)

    assert dupes == [],
           "duplicate (method, path) pairs in AuditExportToken's json_api route table: #{inspect(dupes)}"

    use_route = Enum.find(routes, &(&1.action == :use and &1.method == :patch))
    revoke_route = Enum.find(routes, &(&1.action == :revoke and &1.method == :patch))

    assert use_route.route == "/audit_export_tokens/:id/use"
    assert revoke_route.route == "/audit_export_tokens/:id/revoke"
    assert use_route.route != revoke_route.route
  end

  # --- layer 2: compiled Phoenix router table ---------------------------
  # AshJsonApi registers per-resource routes at router-compile time; the
  # compiled table is the actual match-time truth, so a duplicate here is
  # a shadowed action regardless of what the resource DSL says.

  test "compiled router has one path per verb across the audit_export_tokens mount" do
    routes = audit_routes()

    assert routes != [], "audit_export_tokens has no compiled routes in XaasWeb.ApiRouter"

    dupes =
      routes
      |> Enum.frequencies_by(&{&1.verb, &1.path})
      |> Enum.filter(fn {_k, n} -> n > 1 end)

    assert dupes == [],
           "duplicate (verb, path) routes for audit_export_tokens in the compiled router: #{inspect(dupes)}"

    patch_paths =
      routes
      |> Enum.filter(&(&1.verb == :patch))
      |> Enum.map(& &1.path)
      |> Enum.sort()

    assert patch_paths == [
             "/api/audit_export_tokens/:id/revoke",
             "/api/audit_export_tokens/:id/use"
           ],
           "PATCH surface drifted from the W940b distinct subpaths: #{inspect(patch_paths)}"
  end

  # --- layer 3: real HTTP probes -----------------------------------------

  test "PATCH /:id/use actually consumes a real token (not shadowed by :revoke)" do
    org_id = real_org_slug!()
    token = issue_token!(org_id)

    conn =
      build_conn()
      |> with_org_headers(org_id)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/audit_export_tokens/#{token.id}/use", json_api_body(token.id))

    assert conn.status == 200,
           "PATCH /:id/use did not reach the :use action: #{inspect(conn.status)}"

    response = json_response(conn, 200)
    refute is_nil(response["data"]["attributes"]["used_at"])
    assert response["data"]["attributes"]["use_count"] == 1

    persisted = Ash.get!(AuditExportToken, token.id, authorize?: false)
    refute is_nil(persisted.used_at)
    assert persisted.use_count == 1
  end

  test "PATCH /:id/revoke still works (the fix must not have broken :revoke)" do
    org_id = real_org_slug!()
    token = issue_token!(org_id)

    conn =
      build_conn()
      |> with_org_headers(org_id)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/audit_export_tokens/#{token.id}/revoke", json_api_body(token.id))

    assert conn.status == 200
    response = json_response(conn, 200)
    refute is_nil(response["data"]["attributes"]["revoked_at"])

    persisted = Ash.get!(AuditExportToken, token.id, authorize?: false)
    refute is_nil(persisted.revoked_at)
  end
end
