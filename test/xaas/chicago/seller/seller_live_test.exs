defmodule XaasWeb.Chicago.SellerLiveTest do
  @moduledoc """
  Lane-local coverage for `XaasWeb.Chicago.SellerLive` (L9, wave 2,
  RESOLUTIONS R3/R4/R8/R10).

  The executive payload here is a SYNTHESIZED FIXTURE shaped per R3 — it is
  not a render and carries no standing (R8: UNKNOWN until a real receipt
  binds observed execution). The `/chicago/seller` route lands at
  integration (R6; lanes do not touch router.ex), so the LiveView is mounted
  directly with `Phoenix.LiveViewTest.live_isolated/3` through the
  loader-seam MFAs that production never sets.

  Text assertions go through `has_element?/3`'s text filter, which matches
  against the element's decoded text content (`TreeDOM.to_text/1`), so
  HTML-escaped fixture characters (`->`, `'`) are matched as written.
  """

  use XaasWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @fixture_path "test/xaas/chicago/seller/fixtures/chicago.executive.json"
  @module_source "lib/xaas_web/live/chicago/seller_live.ex"
  @subject "urn:chicago:agentic-payment:purchase-001"

  setup do
    fixture =
      @fixture_path
      |> File.read!()
      |> Jason.decode!()

    Application.put_env(:xaas, :chicago_executive_loader, {__MODULE__, :test_executive, []})
    Application.put_env(:xaas, :chicago_subject_loader, {__MODULE__, :test_subject, []})
    Application.put_env(:xaas, :chicago_executive_test_result, {:ok, fixture})
    Application.put_env(:xaas, :chicago_subject_test_result, {:ok, @subject})

    on_exit(fn ->
      Application.delete_env(:xaas, :chicago_executive_loader)
      Application.delete_env(:xaas, :chicago_subject_loader)
      Application.delete_env(:xaas, :chicago_executive_test_result)
      Application.delete_env(:xaas, :chicago_subject_test_result)
    end)

    {:ok, fixture: fixture}
  end

  # Loader MFAs — read whatever the running test stored in the env.
  def test_executive, do: Application.fetch_env!(:xaas, :chicago_executive_test_result)
  def test_subject, do: Application.fetch_env!(:xaas, :chicago_subject_test_result)

  defp mount_seller do
    assert {:ok, view, _html} =
             live_isolated(build_conn(), XaasWeb.Chicago.SellerLive, session: %{})

    view
  end

  defp assert_text(view, selector, expected) do
    assert has_element?(view, selector, expected),
           "expected #{selector} to contain text: #{inspect(expected)}"
  end

  defp demonstrated_variant do
    @fixture_path
    |> File.read!()
    |> Jason.decode!()
    |> Map.put("demonstrated", ["marketplace"])
    |> Map.update!("evidence", fn evidence ->
      Enum.map(evidence, fn item ->
        if item["layer"] == "marketplace",
          do: Map.put(item, "receipt", %{"id" => "rcpt-synth-001"}),
          else: item
      end)
    end)
    |> put_in(["deliveryState", "demonstratedLayers"], 1)
    |> put_in(["deliveryState", "candidateLayers"], 9)
  end

  test "fixture provenance: file is labeled a synthesized fixture, not a render" do
    assert File.read!(@fixture_path) =~ "synthesized fixture — not a render"
  end

  test "header renders subject literal, authority claim, generator identity, digests", %{
    fixture: fixture
  } do
    view = mount_seller()

    assert_text(view, "[data-testid=chicago-header-subject]", fixture["subject"])
    assert_text(view, "[data-testid=chicago-authority-claim]", "NONE")
    assert_text(view, "[data-testid=chicago-generator-identity]", fixture["generatorIdentity"])

    Enum.each(Enum.with_index(fixture["sourceDigests"]), fn {digest, i} ->
      assert_text(view, "[data-testid=chicago-source-digest-#{i}]", digest["path"])
      assert_text(view, "[data-testid=chicago-source-digest-#{i}]", digest["sha256"])
    end)
  end

  test "narrative sections render from fixture fields", %{fixture: fixture} do
    view = mount_seller()
    narrative = fixture["narrative"]

    assert_text(view, "[data-testid=chicago-headline]", narrative["headline"])
    assert_text(view, "[data-testid=chicago-customer-problem]", narrative["customerProblem"])
    assert_text(view, "[data-testid=chicago-desired-outcome]", narrative["desiredOutcome"])
    assert_text(view, "[data-testid=chicago-semantic-path]", narrative["semanticPath"])
  end

  test "capability chips derive from JSON only (demonstrated|candidate|successor)", %{
    fixture: fixture
  } do
    view = mount_seller()
    demonstrated = MapSet.new(fixture["demonstrated"])

    Enum.each(fixture["capabilities"], fn cap ->
      state =
        cond do
          MapSet.member?(demonstrated, cap["id"]) -> "demonstrated"
          cap["role"] == "successor" -> "successor"
          true -> "candidate"
        end

      assert_text(view, "[data-testid=chicago-capability-#{cap["id"]}]", cap["label"])
      assert_text(view, "[data-testid=chicago-capability-state-#{cap["id"]}]", state)
    end)
  end

  test "demonstrated section shows the honest empty state when nothing is demonstrated", %{
    fixture: fixture
  } do
    assert fixture["demonstrated"] == []

    view = mount_seller()

    assert_text(
      view,
      "[data-testid=chicago-demonstrated-empty]",
      "nothing yet demonstrated on this subject"
    )
  end

  test "demonstrated section and evidence receipt flip only from JSON" do
    Application.put_env(:xaas, :chicago_executive_test_result, {:ok, demonstrated_variant()})
    view = mount_seller()

    assert_text(view, "[data-testid=chicago-demonstrated-marketplace]", "marketplace")
    assert_text(view, "[data-testid=chicago-capability-state-marketplace]", "demonstrated")

    assert_text(view, "[data-testid=chicago-evidence-standing-marketplace]", "UNKNOWN")

    assert_text(view, "[data-testid=chicago-evidence-receipt-marketplace]", "rcpt-synth-001")

    refute has_element?(view, "[data-testid=chicago-demonstrated-empty]")
  end

  test "scenarios split positive vs negative from JSON polarity", %{fixture: fixture} do
    view = mount_seller()

    positives = Enum.count(fixture["scenarios"], &(&1["polarity"] == "positive"))
    negatives = Enum.count(fixture["scenarios"], &(&1["polarity"] == "negative"))
    assert positives > 0 and negatives > 0

    assert_text(
      view,
      "[data-testid=chicago-scenarios-positive-count]",
      Integer.to_string(positives)
    )

    assert_text(
      view,
      "[data-testid=chicago-scenarios-negative-count]",
      Integer.to_string(negatives)
    )

    Enum.each(fixture["scenarios"], fn scenario ->
      selector = "[data-testid=chicago-scenario-#{scenario["id"]}]"
      assert_text(view, selector, scenario["label"])
      assert_text(view, selector, scenario["polarity"])
    end)
  end

  test "authority boundaries render each fixture entry", %{fixture: fixture} do
    view = mount_seller()

    Enum.each(Enum.with_index(fixture["authorityBoundaries"]), fn {boundary, i} ->
      assert_text(view, "[data-testid=chicago-authority-boundary-#{i}]", boundary)
    end)
  end

  test "evidence is layer-keyed with receipt-or-none", %{fixture: fixture} do
    view = mount_seller()

    Enum.each(fixture["evidence"], fn item ->
      assert_text(
        view,
        "[data-testid=chicago-evidence-standing-#{item["layer"]}]",
        item["standing"]
      )

      receipt_selector = "[data-testid=chicago-evidence-receipt-#{item["layer"]}]"

      if item["receipt"] do
        assert_text(view, receipt_selector, receipt_text(item["receipt"]))
      else
        assert_text(view, receipt_selector, "none")
      end
    end)
  end

  # Mirrors the view's receipt_label/1 derivation for id-shaped receipts.
  defp receipt_text(%{"id" => id}), do: id
  defp receipt_text(receipt) when is_binary(receipt), do: receipt

  test "failure recovery renders per case with the typed refusal", %{fixture: fixture} do
    view = mount_seller()

    Enum.each(fixture["failureRecovery"], fn recovery ->
      assert_text(
        view,
        "[data-testid=chicago-recovery-#{recovery["caseId"]}]",
        recovery["refusal"]
      )

      assert_text(
        view,
        "[data-testid=chicago-recovery-#{recovery["caseId"]}]",
        recovery["recovery"]
      )
    end)
  end

  test "delivery state renders all five JSON fields", %{fixture: fixture} do
    view = mount_seller()
    ds = fixture["deliveryState"]

    assert_text(
      view,
      "[data-testid=chicago-delivery-required-layers]",
      Integer.to_string(ds["requiredLayers"])
    )

    assert_text(
      view,
      "[data-testid=chicago-delivery-demonstrated-layers]",
      Integer.to_string(ds["demonstratedLayers"])
    )

    assert_text(
      view,
      "[data-testid=chicago-delivery-candidate-layers]",
      Integer.to_string(ds["candidateLayers"])
    )

    assert_text(
      view,
      "[data-testid=chicago-delivery-successor-layers]",
      Integer.to_string(ds["successorLayers"])
    )

    assert_text(view, "[data-testid=chicago-delivery-overall-standing]", ds["overallStanding"])
  end

  test "BLOCKED banner on refused executive: typed reason, subject, render hint" do
    Application.put_env(
      :xaas,
      :chicago_executive_test_result,
      {:refused, {:chicago_not_rendered, :missing_file}}
    )

    view = mount_seller()

    assert_text(view, "[data-testid=chicago-blocked]", "BLOCKED")
    assert_text(view, "[data-testid=chicago-blocked]", "chicago_not_rendered")
    assert_text(view, "[data-testid=chicago-blocked]", "mix chicago.render")
    assert_text(view, "[data-testid=chicago-blocked-subject]", @subject)

    refute has_element?(view, "[data-testid=chicago-customer-problem]")
  end

  test "BLOCKED banner when the projection API module is not loaded" do
    Application.put_env(:xaas, :chicago_executive_loader, {NoSuch.Chicago.Api, :executive, []})
    Application.put_env(:xaas, :chicago_subject_loader, {NoSuch.Chicago.Api, :subject, []})

    view = mount_seller()

    assert_text(view, "[data-testid=chicago-blocked]", "BLOCKED")
    assert_text(view, "[data-testid=chicago-blocked]", "projection_api_unavailable")
    assert_text(view, "[data-testid=chicago-blocked]", "mix chicago.render")
    assert_text(view, "[data-testid=chicago-blocked-subject]", "unavailable")
  end

  test "anti-hardcode: module source contains no case ids and no narrative content", %{
    fixture: fixture
  } do
    source = File.read!(@module_source)

    refute source =~ "CHI-CASE-"
    refute source =~ fixture["narrative"]["headline"]
    refute source =~ fixture["narrative"]["customerProblem"]
    refute source =~ fixture["narrative"]["desiredOutcome"]
    refute source =~ fixture["narrative"]["semanticPath"]

    Enum.each(fixture["scenarios"], fn scenario ->
      refute source =~ scenario["description"]
    end)
  end

  # route landed: lib/xaas_web/router.ex:62 (un-skipped 2026-10-06, coordinator)
  test "router mounts Chicago.SellerLive at /chicago/seller" do
    router = File.read!("lib/xaas_web/router.ex")
    assert router =~ ~s[live("/chicago/seller", Chicago.SellerLive)]
  end
end
