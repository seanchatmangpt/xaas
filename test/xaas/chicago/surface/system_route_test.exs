defmodule XaasWeb.System.SystemRouteTest do
  @moduledoc """
  Route-level proof for `/system` (R6: the entry lives inside the
  `dev_routes` block; the coordinator lands it at integration).

  Tagged `:chicago_route_pending` so lane runs skip it — run with
  `--include chicago_route_pending` once the router entry lands (the
  coordinator also un-tags it at integration).
  """

  use XaasWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  # route/projection landed at integration (tag removed)
  test "GET /system mounts the command center live view (route lands at integration)", %{
    conn: conn
  } do
    # plain binary path, not ~p — the router entry does not exist until the
    # coordinator lands R6, so compile-time route verification cannot see it.
    {:ok, _view, html} = live(conn, "/system")

    assert html =~ ~s(data-testid="command-center-root")
    assert html =~ "System command center"
    assert html =~ ~s(data-testid="refresh")
  end
end
