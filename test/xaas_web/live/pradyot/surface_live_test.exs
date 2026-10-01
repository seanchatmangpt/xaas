defmodule XaasWeb.Pradyot.SurfaceLiveTest do
  use XaasWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  @subject "urn:chicago:agentic-payment:purchase-001"

  test "system route is read-only", %{conn: conn} do
    {:ok, _, html} = live(conn, "/system")
    assert html =~ "Live system view"
    assert html =~ "UI authority:"
    assert html =~ "NONE"
  end

  test "Chicago route preserves subject and evidence gaps", %{conn: conn} do
    {:ok, _, html} = live(conn, "/chicago")
    assert html =~ "Chicago Agentic Payments"
    assert html =~ @subject
    assert html =~ "unsupported"
    assert html =~ "partial"
  end

  test "seller route projects the Chicago subject", %{conn: conn} do
    {:ok, _, html} = live(conn, "/seller")
    assert html =~ "Seller projection"
    assert html =~ @subject
    assert html =~ "Customer problem"
    assert html =~ "XaaS/BRCE only"
  end
end
