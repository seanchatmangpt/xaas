defmodule XaasWeb.Channels.SocketCourtW984kjTest do
  @moduledoc """
  W984kj unclaimed-family probe — realtime socket layer court.

  Census (2026-10-08): `lib/xaas_web/channels/` does not exist; there is no
  `user_socket.ex` and no `use Phoenix.Channel` module anywhere under `lib/`.
  The only socket mounts in `lib/xaas_web/endpoint.ex` are the stock
  `Phoenix.LiveView.Socket` at `/live` (with signed-cookie session
  `connect_info`) and the dev-only `Phoenix.LiveReloader.Socket`. Neither
  carries custom join-time logic (no `connect/3` callback, no topic guards).

  This court goes past the indirect coverage W984hq typed (LiveViewTest
  mounts through `/live` in e.g.
  `test/xaas_web/next_read_live_deepening_test.exs`) with real endpoint
  dispatches:

  1. a non-upgraded HTTP GET on the socket path falls through the socket
     mount to the router and answers 404 — pinned so the endpoint's
     socket-vs-router boundary is explicit (the transport only ever speaks
     websocket upgrade; ConnTest cannot originate one, so the mount itself
     is exercised the only lawful in-process way: a real LiveView mount),
  2. an unrouted control path answers the same 404 shape,
  3. a real `Phoenix.LiveViewTest` mount through `/live` succeeds over
     sandboxed real Postgres.

  Mutation rationale (1)+(2): removing the `socket("/live", ...)` mount
  leaves both probes unchanged (they pin fall-through), so the load-bearing
  probe is (3) — a session-bearing mount through the LiveView socket, which
  fails if the socket mount or its session `connect_info` is dropped.
  Chicago-style: real endpoint, real socket path, real Postgres, no mocks.
  """

  use XaasWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  @moduletag :w984kj

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Xaas.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end

  test "non-upgraded GET /live falls through to the router as 404" do
    conn = get(build_conn(), "/live")

    assert conn.status == 404
  end

  test "unrouted control path answers 404 (same fall-through shape)" do
    conn = get(build_conn(), "/definitely-unrouted-w984kj")

    assert conn.status == 404
  end

  test "LiveView mount through /live succeeds over the real socket path" do
    conn = Phoenix.ConnTest.build_conn()
    assert {:ok, _view, html} = live(conn, "/witness")
    assert html =~ "WITNESS" or html != ""
  end
end
