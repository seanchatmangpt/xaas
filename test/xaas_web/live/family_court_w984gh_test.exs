defmodule XaasWeb.WdFa.CaseStudyLiveFamilyCourtW984ghTest do
  @moduledoc """
  Lane W984gh unclaimed-family court for `XaasWeb.WdFa.CaseStudyLive`
  (/case-studies/wd-fa) — the only state-bearing module under
  `lib/xaas_web/live/` with zero test-tree references.

  Chicago-school: real mounts, real `handle_event` round-trips, real
  `LearningLoop.verify_novel_fixture/0` (no doubles). Each test carries a
  mutation rationale: reverting the exercised branch (or flipping a rendered
  assignment) must fail the assertions below.
  """

  use XaasWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  describe "mount (deterministic reference state)" do
    @describetag :family_court_w984gh

    test "renders known_firmware default with real derived state", %{conn: conn} do
      {:ok, view, html} = live(conn, "/case-studies/wd-fa")

      # Mutation rationale: reverting mount's `selected`/`state` assigns (or
      # WdFa.presentation_state/2's KNOWN branch) flips the classification.
      assert text(view, "[data-testid=classification]") =~ "KNOWN"
      assert text(view, "[data-testid=standing]") =~ "ALIVE"
      assert has_element?(view, "[data-testid=scenario-known_firmware]")
    end

    test "morning brief and STOGAF metrics render real domain summaries", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/case-studies/wd-fa")

      brief = view |> element("[data-testid=morning-brief]") |> render()
      assert brief =~ "Needs judgment"

      # Mutation rationale: dropping any mount assign that render/1 dereferences
      # (morning_brief, evaluation, architecture, dfcm_metrics) raises in the
      # LiveView — the mount fails and this test fails with it.
      assert text(view, "[data-testid=stogaf-requirements-count]") != ""
      assert text(view, "[data-testid=stogaf-viewpoints-count]") != ""
      assert text(view, "[data-testid=stogaf-workorders-count]") != ""
      assert text(view, "[data-testid=stogaf-unclaimed-count]") != ""
    end
  end

  describe "select_scenario event" do
    @describetag :family_court_w984gh

    test "partial_firmware renders PARTIAL with missing required evidence", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/case-studies/wd-fa")

      render_click(view, "select_scenario", %{"id" => "partial_firmware"})
      assert text(view, "[data-testid=classification]") =~ "PARTIAL"

      missing = text(view, "[data-testid=missing-evidence]")
      assert missing =~ "timeout_waveform"

      # Mutation rationale: the `learned?` guard in handle_event (id == "novel_x"
      # and experience_admitted) must leave non-novel selections un-learned;
      # short-circuiting it to true would surface MODE-X-NOVEL here.
      refute text(view, "[data-testid=admitted-mode]") =~ "MODE-X-NOVEL"
    end

    test "novel_x unadmitted renders UNKNOWN with admit button present", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/case-studies/wd-fa")

      render_click(view, "select_scenario", %{"id" => "novel_x"})
      assert text(view, "[data-testid=classification]") =~ "UNKNOWN"
      assert has_element?(view, "[data-testid=admit-experience]")

      # Mutation rationale: presentation_state("novel_x") unadmitted branch sets
      # standing UNKNOWN; flipping it to ALIVE fails these asserts.
      assert text(view, "[data-testid=standing]") =~ "UNKNOWN"
    end
  end

  describe "admit_experience event (real learning loop)" do
    @describetag :family_court_w984gh

    test "admitting the verified MachineExperience flips novel_x to KNOWN/ALIVE", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/case-studies/wd-fa")

      render_click(view, "select_scenario", %{"id" => "novel_x"})
      render_click(view, "admit_experience")

      # Mutation rationale: handle_event("admit_experience") assigns a real
      # VerificationReceipt + MachineExperience + ArchitectureChange; dropping
      # any of them crashes render, corrupting them breaks these assertions.
      assert text(view, "[data-testid=classification]") =~ "KNOWN"
      assert text(view, "[data-testid=admitted-mode]") =~ "MODE-X-NOVEL"
      assert has_element?(view, "[data-testid=verification-receipt]")

      assert text(view, "[data-testid=receipt-digest]") != ""
      assert text(view, "[data-testid=experience-id]") != ""
      assert text(view, "[data-testid=standard-change]") =~ "→"
    end

    test "admitted selection survives scenario re-selection via the learned? guard", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/case-studies/wd-fa")

      render_click(view, "admit_experience")
      render_click(view, "select_scenario", %{"id" => "novel_x"})

      # Mutation rationale: this is the only path exercising
      # `learned? = id == "novel_x" and socket.assigns.experience_admitted`
      # returning true — reverting the guard or the experience_admitted assign
      # drops the UI back to UNKNOWN.
      assert text(view, "[data-testid=classification]") =~ "KNOWN"
      assert text(view, "[data-testid=admitted-mode]") =~ "MODE-X-NOVEL"
    end
  end

  defp text(view, selector) do
    view |> element(selector) |> render() |> Floki.parse_fragment!() |> Floki.text()
  end
end
