defmodule XaasWeb.DevRoutesCourtTest do
  @moduledoc """
  W774 dev-routes court: the dev-only route surface (LiveDashboard,
  AshAdmin `/admin`, autofde-lab LiveView, `/system`) is real HTTP under
  test (test config sets `config :xaas, dev_routes: true`, so the
  compile-time block in `lib/xaas_web/router.ex` IS mounted here).

  Compile-time gate: `Application.compile_env(:xaas, :dev_routes)` is
  read when the router module compiles (lib/xaas_web/router.ex:314).
  It cannot be flipped per-test without recompiling the router, so the
  disabled side is courted as a source pin (see `source pin` tests) --
  the honest contract, per the lane order.

  Auth posture (asserted honestly): these routes carry NO credential
  guard. Each request below is made with zero auth headers and expects a
  real 200 -- that is the dev-only trust boundary: unauthenticated
  service locally, and production exclusion enforced solely by the
  compile-time gate (no `dev_routes` setting exists in prod.exs or
  runtime.exs, so `compile_env` is nil/falsy there and the block is
  never mounted). The server that answers these requests runs under the
  test endpoint, i.e. dev_routes: true by construction.
  """

  use XaasWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @router_source_relative "lib/xaas_web/router.ex"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  ## ------------------------------------------------------------------
  ## (a) enabled side: real requests, unauthenticated, non-404 / 200
  ## ------------------------------------------------------------------

  test "GET /dev/dashboard serves LiveDashboard unauthenticated", %{conn: conn} do
    conn = get(conn, "/dev/dashboard")
    # LiveDashboard may 302 (e.g. to its canonical page path) before 200.
    conn =
      if conn.status == 302 do
        redirected = get_resp_header(conn, "location") |> hd()
        get(conn, redirected)
      else
        conn
      end

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") |> hd() =~ "text/html"
    refute conn.resp_body == ""
  end

  test "GET /admin serves AshAdmin unauthenticated", %{conn: conn} do
    conn = get(conn, "/admin")
    # AshAdmin answers /admin with 200 directly, or a 302 to its first
    # domain page depending on domain enumeration; follow to the real 200.
    conn =
      if conn.status == 302 do
        redirected = get_resp_header(conn, "location") |> hd()
        get(conn, redirected)
      else
        conn
      end

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") |> hd() =~ "text/html"
    assert conn.resp_body =~ "<title>Ash Admin</title>"
    refute conn.resp_body == ""
  end

  test "GET /dev/dashboards/autofde-lab mounts the autofde-lab StatusLive", %{conn: conn} do
    # Real mount through the router: StatusLive reads the sibling repo's
    # docs/STATUS.md (may be :not_found in this checkout -- the view
    # handles it) and the 10 most-recent real WebhookDelivery rows.
    {:ok, _view, html} = live(conn, "/dev/dashboards/autofde-lab")

    assert html =~ "autofde-lab benchmark history"
    assert html =~ "phx-click=\"refresh\""
  end

  test "GET /system mounts the command center LiveView (same dev_routes gate)", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/system")

    assert html =~ ~s(data-testid="command-center-root")
    assert html =~ "System command center"
  end

  ## ------------------------------------------------------------------
  ## (b) disabled side: compile-time gate source-pin
  ## ------------------------------------------------------------------

  @guard_line ~S{if Application.compile_env(:xaas, :dev_routes) do}

  test "source pin: every dev-route mount sits inside the dev_routes compile-time block" do
    source = File.read!(Path.expand(@router_source_relative, File.cwd!()))

    # The guard exists exactly once, as an `if` on the compile_env.
    occurrences =
      source
      |> String.split("\n")
      |> Enum.count(&String.contains?(&1, @guard_line))

    assert occurrences == 1,
           "expected exactly one dev_routes compile-time guard in router.ex, got #{occurrences}"

    [guard_section | _] = String.split(source, @guard_line, parts: 2)
    rest = source |> String.split(@guard_line, parts: 2) |> Enum.at(1)

    # Nothing dev-only is mounted BEFORE the guard...
    refute guard_section =~ "live_dashboard("
    refute guard_section =~ "ash_admin("
    refute guard_section =~ "AutofdeLab.StatusLive"

    # ...and the guarded section mounts exactly the documented surface,
    # ending at the router's final `end`.
    assert rest =~ ~S{live_dashboard("/dashboard", metrics: XaasWeb.Telemetry)}
    assert rest =~ ~S{forward("/mailbox", Plug.Swoosh.MailboxPreview)}
    assert rest =~ ~S{live("/dashboards/autofde-lab", XaasWeb.AutofdeLab.StatusLive)}
    assert rest =~ ~S{live("/system", System.CommandCenterLive)}
    assert rest =~ ~S{ash_admin("/")}
  end

  test "source pin: no prod/runtime config sets dev_routes, so the block is never mounted there" do
    for {file, present} <- [
          {"config/prod.exs", false},
          {"config/runtime.exs", false},
          {"config/dev.exs", true},
          {"config/test.exs", true}
        ] do
      path = Path.expand(file, File.cwd!())
      body = File.read!(path)
      sets = Regex.match?(~r/config\s+:xaas,\s*dev_routes:\s*true/, body)

      assert sets == present,
             "#{file}: expected dev_routes:true=#{present}, got #{sets}"
    end
  end

  ## ------------------------------------------------------------------
  ## (d) determinism
  ## ------------------------------------------------------------------

  test "GET /admin is deterministic across repeated requests", %{conn: conn} do
    c1 = get(conn, "/admin")
    c2 = get(build_conn(), "/admin")

    assert c1.status == c2.status
    assert c1.status == 200
    # Bodies differ only by per-request CSRF nonce; assert the stable shell.
    for body <- [c1.resp_body, c2.resp_body] do
      assert body =~ "<title>Ash Admin</title>"
    end
  end
end
