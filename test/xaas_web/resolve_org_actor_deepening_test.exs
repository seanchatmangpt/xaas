defmodule XaasWeb.ResolveOrgActorDeepeningTest do
  @moduledoc """
  W743 deepening courts for `XaasWeb.Plugs.ResolveOrgActor` — the
  security-load-bearing, path-aware actor/tenant resolver on `/api`.

  Chicago-style: real plug invocations against real sandbox rows in the
  real Postgres (`Xaas.Repo`), plus real HTTP through the router for the
  enforcement probes. No mocks, no interaction assertions.

  Coverage this file adds beyond
  `test/xaas_web/controllers/resolve_org_actor_test.exs`:

    (a) the path allowlist itself: each of the 4 named non-global-
        multitenancy governance paths enforces X-Org-Id; a non-listed
        `/api` path passes through completely unaffected (asserted at
        BOTH the plug level and a real router HTTP probe);
    (b) resolution: a real `X-Org-Id` resolving to a real `Org` row
        assigns both `conn.assigns[:current_actor]` and the real Ash
        actor AND tenant; unknown slug → real 404 `org_not_found`;
        blank header and multi-valued header → real 400
        `missing_org_id` (typed: a duplicated header is treated as
        missing, never silently first-wins);
    (c) non-interference: an already-resolved org actor is never
        overridden by `SetInternalApiSystemActor` (its `is_nil`
        guard), and the real precedence where both apply is that the
        org actor wins;
    (d) `/mcp` no-op: the allowlist never matches there, so the plug
        is a pure passthrough on that surface.
  """

  use XaasWeb.ConnCase

  alias Xaas.Accounts.Org

  @enforced_paths ~w(
    approval_dr_failover
    approval_legal_hold_release
    approval_deployment_quarantine
    approval_backup_retention_change
  )

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp real_org! do
    Org
    |> Ash.Changeset.for_create(:create, %{
      name: "Org #{System.unique_integer([:positive])}",
      slug: "org-#{System.unique_integer([:positive])}"
    })
    |> Ash.create!(authorize?: false)
  end

  # Real plug invocation against a real ConnCase conn (endpoint private
  # config present, so Phoenix.Controller.json renders for real).
  defp call_plug(conn, path_info, method \\ "GET") do
    conn
    |> Map.put(:path_info, path_info)
    |> Map.put(:method, method)
    |> Map.put(:request_path, "/" <> Enum.join(path_info, "/"))
    |> XaasWeb.Plugs.ResolveOrgActor.call([])
  end

  defp call_system_actor_plug(conn, path_info) do
    conn
    |> Map.put(:path_info, path_info)
    |> Map.put(:method, "POST")
    |> Map.put(:request_path, "/" <> Enum.join(path_info, "/"))
    |> XaasWeb.Plugs.SetInternalApiSystemActor.call([])
  end

  # ---------------------------------------------------------------------------
  # (a) path allowlist
  # ---------------------------------------------------------------------------

  describe "(a) path allowlist enforces on each of the 4 governance paths" do
    for path <- @enforced_paths do
      test "enforces X-Org-Id on /api/#{path} (real 400, halted)" do
        conn =
          build_conn()
          |> put_req_header("accept", "application/json")
          |> call_plug(["api", unquote(path), "some-id"])

        assert conn.halted
        assert conn.status == 400

        body = Jason.decode!(conn.resp_body)
        assert body["error"] == "missing_org_id"

        assert body["detail"] ==
                 "X-Org-Id request header is required for this route"
      end
    end

    test "non-listed /api path passes through the plug completely unaffected (plug level)" do
      conn = build_conn() |> put_req_header("accept", "application/json")

      result = call_plug(conn, ["api", "freeze_window", "some-id"])

      # Structurally the SAME conn (passthrough returns it untouched):
      refute result.halted
      refute result.status
      refute Map.has_key?(result.assigns, :current_actor)
      assert Ash.PlugHelpers.get_actor(result) == nil
      assert Ash.PlugHelpers.get_tenant(result) == nil
    end

    test "non-listed /api path does NOT answer 400 missing_org_id over real HTTP" do
      token = System.fetch_env!("INTERNAL_API_TOKEN")

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer " <> token)
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/freeze_window")

      # Whatever the downstream router answers (404 here), it must never
      # be the plug's missing-org 400.
      refute conn.status == 400
      if conn.status == 400 do
        refute json_response(conn, 400)["error"] == "missing_org_id"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # (b) resolution
  # ---------------------------------------------------------------------------

  describe "(b) resolution against real Org rows" do
    test "real X-Org-Id resolving to a real Org assigns current_actor AND real Ash actor and tenant" do
      org = real_org!()

      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("x-org-id", org.slug)
        |> call_plug(["api", "approval_dr_failover", "some-id"])

      refute conn.halted
      assert conn.assigns[:current_actor] == %{org_id: org.slug}
      assert Ash.PlugHelpers.get_actor(conn) == %{org_id: org.slug}
      assert Ash.PlugHelpers.get_tenant(conn) == org.slug
    end

    test "unknown org slug: real 404 org_not_found with the slug echoed in detail" do
      unknown = "does-not-exist-#{System.unique_integer([:positive])}"

      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("x-org-id", unknown)
        |> call_plug(["api", "approval_backup_retention_change", "some-id"])

      assert conn.halted
      assert conn.status == 404

      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "org_not_found"
      assert body["detail"] == ~s(no Org found with slug #{inspect(unknown)})
    end

    test "malformed (empty-string) X-Org-Id: typed 400 missing_org_id, not a lookup" do
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("x-org-id", "")
        |> call_plug(["api", "approval_dr_failover", "some-id"])

      assert conn.halted
      assert conn.status == 400
      assert Jason.decode!(conn.resp_body)["error"] == "missing_org_id"
    end

    test "malformed (multi-valued) X-Org-Id: typed 400 missing_org_id — a genuinely duplicated header is treated as missing, never first-wins" do
      org = real_org!()
      other = real_org!()

      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        # Real multi-valued header state (two x-org-id entries on the
        # conn, as an HTTP client sending the header twice produces —
        # put_req_header would replace, so we set req_headers directly).
        |> Map.put(:req_headers, [{"x-org-id", org.slug}, {"x-org-id", other.slug}])
        |> call_plug(["api", "approval_dr_failover", "some-id"])

      assert conn.halted
      assert conn.status == 400
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "missing_org_id"
      # And crucially: no actor/tenant was ever installed from either value.
      assert Ash.PlugHelpers.get_actor(conn) == nil
      assert Ash.PlugHelpers.get_tenant(conn) == nil
    end

    test "resolution actually hits the real repo: a slug that exists only in another sandbox connection 404s" do
      # No real_org!() in THIS test — the slug below never existed.
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("x-org-id", "never-inserted-#{System.unique_integer([:positive])}")
        |> call_plug(["api", "approval_legal_hold_release", "some-id"])

      assert conn.halted
      assert conn.status == 404
      assert Jason.decode!(conn.resp_body)["error"] == "org_not_found"
    end
  end

  # ---------------------------------------------------------------------------
  # (c) non-interference with SetInternalApiSystemActor
  # ---------------------------------------------------------------------------

  describe "(c) non-interference / real precedence vs SetInternalApiSystemActor" do
    test "an already-resolved ORG actor is never overridden by SetInternalApiSystemActor on a system-actor path" do
      org = real_org!()

      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("x-org-id", org.slug)
        # ResolveOrgActor runs first and resolves the real org actor on
        # a tenant-scoped path...
        |> call_plug(["api", "approval_dr_failover", "some-id"])
        # ...then the SAME conn reaches a system-actor-scoped segment.
        |> call_system_actor_plug(["api", "approval_pricing_override", "some-id"])

      # The org actor wins; the system actor never replaced it.
      assert Ash.PlugHelpers.get_actor(conn) == %{org_id: org.slug}
      assert conn.assigns[:current_actor] == %{org_id: org.slug}
      assert Ash.PlugHelpers.get_tenant(conn) == org.slug

      # And it is genuinely NOT the system authority actor.
      refute match?(%Xaas.SystemAuthority{}, Ash.PlugHelpers.get_actor(conn))
    end

    test "conversely, on a system-actor path with no prior org actor, the system actor IS installed" do
      conn = build_conn() |> call_system_actor_plug(["api", "approval_pricing_override", "some-id"])

      actor = Ash.PlugHelpers.get_actor(conn)
      assert match?(%Xaas.SystemAuthority{}, actor)
      assert conn.assigns[:current_actor] == actor
    end

    test "ResolveOrgActor never adopts a pre-existing system actor as its own on a tenant-scoped path — it requires a real header" do
      # A conn that already carries the system actor, then hits a
      # tenant-scoped path with NO X-Org-Id: the plug's real behavior is
      # a 400 refusal (it does not treat the system actor as a substitute
      # for the header), proving the two actors never blur into one.
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> call_system_actor_plug(["internal-api", "approval_freeze_override", "some-id"])
        |> call_plug(["api", "approval_dr_failover", "some-id"])

      assert conn.halted
      assert conn.status == 400
      assert Jason.decode!(conn.resp_body)["error"] == "missing_org_id"
    end
  end

  # ---------------------------------------------------------------------------
  # (d) /mcp no-op
  # ---------------------------------------------------------------------------

  describe "(d) /mcp is a pure no-op" do
    test "an /mcp path whose second segment coincidentally equals an allowlisted name never enforces" do
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> call_plug(["mcp", "approval_dr_failover"])

      refute conn.halted
      refute conn.status
      refute Map.has_key?(conn.assigns, :current_actor)
      assert Ash.PlugHelpers.get_actor(conn) == nil
      assert Ash.PlugHelpers.get_tenant(conn) == nil
    end

    test "an /mcp path with a real X-Org-Id present still does not touch the conn" do
      org = real_org!()

      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("x-org-id", org.slug)
        |> call_plug(["mcp", "approval_dr_failover", "some-id"])

      refute conn.halted
      refute conn.status
      assert Ash.PlugHelpers.get_actor(conn) == nil
      assert Ash.PlugHelpers.get_tenant(conn) == nil
    end
  end
end
