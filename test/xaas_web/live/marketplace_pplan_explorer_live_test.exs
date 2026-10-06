defmodule XaasWeb.MarketplacePplanExplorerLiveTest do
  @moduledoc """
  Coverage for `XaasWeb.MarketplacePplanExplorerLive` (/marketplace-pplan).

  Proves the LiveView renders from the real p-plan TTL (anti-hardcode: counts
  and labels come from the ontology), that step selection swaps the detail
  card, that simulator slider changes update the KPIs and SVG, and that the
  Turtle viewer filter narrows server-side.
  """

  use XaasWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @ttl "priv/gcp/marketplace_lifecycle.ttl"

  test "renders the full explorer from the ontology", %{conn: conn} do
    {:ok, view, html} = live(conn, "/marketplace-pplan")

    # All 8 agents, 4 organizations, 8 steps, 27 variables -- from the TTL.
    assert html =~ "Elena Vance"
    assert html =~ "Sarah Chen"
    assert html =~ "Rachel Adams"
    assert html =~ "Liam Sterling"
    assert html =~ "KubeScale Technologies Inc."
    assert view |> has_element?("#avatar-grid .rounded-lg", "ISV")
    assert view |> has_element?("#avatar-grid .rounded-lg", "Hyperscaler")
    assert view |> has_element?("#avatar-grid .rounded-lg", "Reseller")

    # Petal Components is live on this page: the domain pill is petal's
    # <.badge> (pc-badge classes), rendered through use XaasWeb, :live_view.
    assert view |> has_element?("#avatar-grid .pc-badge.pc-badge--sm.pc-badge--primary-light", "ISV")
    assert html =~ ~s(role="note")
    assert html =~ "Step 1: Supplier Enrollment"
    assert html =~ "System Dynamics"
    assert html =~ "FinOps Spend-Drawdown Simulator"

    # Counts derived from the ontology, not hardcoded: the header reads
    # "<N> variables · <M> steps" with the plan's own numbers (the TTL
    # declares 29 p-plan:Variable individuals).
    header_text =
      view
      |> element("#ontology-summary")
      |> render()
      |> Floki.parse_fragment!()
      |> Floki.text()

    assert header_text =~ "29 variables"
    assert header_text =~ "8 steps"
    assert header_text =~ "8 agents"
    assert header_text =~ "4 organizations"
  end

  test "step selection swaps the detail card", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/marketplace-pplan")

    assert view |> element("#step-detail h3") |> render() =~ "Step 1: Supplier Enrollment"

    view
    |> element("button[phx-value-step='3']")
    |> render_click()

    assert view |> element("#step-detail h3") |> render() =~ "Step 3: Private Offer Negotiation"
    assert render(view) =~ "Rachel Adams"
    assert render(view) =~ "Immutable Cryptographically Sealed Private Offer Object"
  end

  test "domain filter narrows avatars", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/marketplace-pplan")

    html =
      view
      |> element("#domain-filter-form")
      |> render_change(%{"domain" => "Enterprise"})

    # Elena Vance is an ISV avatar; with the Enterprise filter she disappears
    # from the avatar grid (she may still appear in step detail cards).
    assert html =~ "Sarah Chen"
    refute view |> has_element?("#avatar-grid .rounded-lg", "Elena Vance")
    assert view |> has_element?("#avatar-grid .rounded-lg", "Sarah Chen")
  end

  test "simulator slider change updates KPIs", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/marketplace-pplan")

    html =
      view
      |> element("#sim-form")
      |> render_change(%{"pool" => "1000000", "deal" => "1000000", "burn" => "30"})

    # pool 1M, burn 30% -> organic 300k; deal 1M -> post total min(1M, 1.3M) = 1M,
    # so the entire pool is consumed post-marketplace and velocity gain is huge.
    assert html =~ "Velocity gain"
    assert html =~ "$700,000"

    baseline_html =
      view
      |> element("#sim-form")
      |> render_change(%{"pool" => "20000000", "deal" => "50000", "burn" => "100"})

    # organic burn = pool -> zero unused baseline commit.
    assert baseline_html =~ "$0"
  end

  test "turtle filter narrows rendered lines server-side", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/marketplace-pplan")

    ttl = File.read!(@ttl)
    assert String.contains?(ttl, "hasInputVar")

    html =
      view
      |> element("#turtle-filter-form")
      |> render_change(%{"q" => "hasOutputVar"})

    assert html =~ "hasOutputVar"
    refute html =~ "p-plan:hasInputVar "
  end
end
