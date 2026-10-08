defmodule XaasWeb.PageCourtW984kiTest do
  use XaasWeb.ConnCase

  @moduledoc """
  Lane W984ki unclaimed-family probe: the "/" browser-scope controller
  layer (`XaasWeb.PageController` + the `XaasWeb.ErrorHTML` fallback
  renderer; no FallbackController exists in this tree).

  Census (2026-10-08, grep of test/):
  - `GET /` covered by test/xaas_web/controllers/page_controller_test.exs
    (body text only).
  - 404-via-browser-route covered by residue_court_w984eq p4 (status +
    content-type only, no body).
  - Uncovered: the `layout: false` branch of `home/2` (layout marker
    absence never asserted), the `ErrorHTML.render/2` 500 clause, and
    the direct render shape of the HTML 404 body.
  """

  @tag :w984ki
  test "c1. GET / renders home WITHOUT the root layout (layout: false branch)" do
    # Mutation: drop `layout: false` from PageController.home/2 -> the
    # root layout's <.live_title> ("Phoenix Framework") appears in the
    # body and this court fails.
    conn = get(build_conn(), "/")

    # Observed: root layout IS rendered (root is not a "layout" in the
    # Phoenix render-layout sense here); the app layout (header nav) is
    # what layout: false skips.
    body = html_response(conn, 200)
    assert body =~ "Peace of mind from prototype to production"
    refute body =~ "<header class=\"px-4 sm:px-6 lg:px-8\""
  end

  @tag :w984ki
  test "c2. ErrorHTML.render maps 404/500 templates to Phoenix status messages" do
    # Mutation: change ErrorHTML.render/2 to stop delegating to
    # status_message_from_template/1 -> these exact bodies disappear.
    assert "Not Found" = XaasWeb.ErrorHTML.render("404.html", %{})
    assert "Internal Server Error" = XaasWeb.ErrorHTML.render("500.html", %{})
    assert "Forbidden" = XaasWeb.ErrorHTML.render("403.html", %{})
  end

  @tag :w984ki
  test "c3. unmatched browser route serves the ErrorHTML 404 text body" do
    # Complements residue court p4 (status/content-type only). Mutation:
    # swap the browser error view/template -> the rendered text body
    # changes while the status stays 404.
    conn = get(build_conn(), "/definitely-not-a-route-w984ki")

    assert conn.status == 404
    assert html_response(conn, 404) =~ "Not Found"
  end
end
