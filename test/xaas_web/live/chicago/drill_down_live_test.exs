defmodule XaasWeb.Chicago.DrillDownLiveTest do
  @moduledoc """
  Coverage for `XaasWeb.Chicago.DrillDownLive` (/chicago).

  Two classes of proof:

  1. Component-level tests that run NOW: the real `drill_down/1` template is
     rendered through `Phoenix.LiveViewTest.render_component/2` with
     model-shaped inputs (R4 `Xaas.Chicago.View.drill_down/0` episode maps).
     These prove the render is MODEL-DRIVEN — subject literals, layer counts,
     chip text and classes all flip when the model field flips (anti-hardcode).
  2. Mount/route/event tests that need the `/chicago` route entry (R6, lands
     at integration) or the rendered projection (`mix chicago.render`). They
     are tagged `:chicago_route_pending` / `:chicago_projection_pending` so
     lane runs exclude them; run them with `--include` once the seams land.
  """

  use XaasWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias XaasWeb.Chicago.DrillDownLive

  @layer_ids ~w(sjira graphlaw sa2a pplan xaas ex4pm beam4pm affidavit ashsurface marketplace)

  ## Model-shaped fixtures (R4 episode maps, atom keys)

  defp layer(id, overrides \\ []) do
    Map.merge(
      %{
        id: id,
        label: String.upcase(id) <> " layer",
        what_happened: id <> " — model-supplied narrative",
        standing: "UNKNOWN",
        lifecycle: :candidate,
        evidence: [],
        receipt: nil,
        absence: nil
      },
      Map.new(overrides)
    )
  end

  defp full_layers, do: Enum.map(@layer_ids, &layer/1)

  defp episode(layers, overrides \\ []) do
    Map.merge(
      %{
        subject: "urn:chicago:agentic-payment:purchase-001",
        business_outcome: %{
          headline: "Pay once, prove every layer",
          detail: "model-supplied business detail",
          standing: "UNKNOWN"
        },
        layers: layers
      },
      Map.new(overrides)
    )
  end

  defp render_episode(ep) do
    assigns = Map.new(DrillDownLive.base_assigns({:ok, ep}))
    render_component(&DrillDownLive.drill_down/1, assigns)
  end

  defp render_blocked(reason) do
    assigns = Map.new(DrillDownLive.base_assigns({:refused, reason}))
    render_component(&DrillDownLive.drill_down/1, assigns)
  end

  defp render_selected(ep, id) do
    {ok_assigns, selected} =
      {Map.new(DrillDownLive.base_assigns({:ok, ep})), DrillDownLive.find_layer({:ok, ep}, id)}

    assigns = Map.merge(ok_assigns, %{selected_id: id, selected_layer: selected})
    render_component(&DrillDownLive.drill_down/1, assigns)
  end

  # ~s|...| with the bar sigil so the marker keeps its trailing dash: matching
  # the `data-testid="layer-row-` PREFIX (the id suffix is model-supplied).
  @row_marker ~s|data-testid="layer-row-|

  defp occurrences(html, marker) do
    html |> String.split(marker) |> length() |> Kernel.-(1)
  end

  defp episode_subject(ep), do: ep[:subject] || ep["subject"]

  defp episode_layers(ep), do: ep[:layers] || ep["layers"] || []

  defp first_layer_id(ep) do
    first = hd(episode_layers(ep))
    first[:id] || first["id"]
  end

  ## Model-driven render (runs now)

  test "subject literal comes from the model, never hardcoded" do
    a = render_episode(episode(full_layers(), subject: "urn:chicago:demo-a"))
    b = render_episode(episode(full_layers(), subject: "urn:chicago:demo-b"))

    assert a =~ ~s(data-testid="subject")
    assert a =~ "urn:chicago:demo-a"
    refute a =~ "urn:chicago:demo-b"

    assert b =~ "urn:chicago:demo-b"
    refute b =~ "urn:chicago:demo-a"
  end

  test "renders exactly 10 layer rows for a 10-layer model" do
    html = render_episode(episode(full_layers()))
    assert occurrences(html, @row_marker) == 10
    refute html =~ "LAYER MISSING FROM MODEL"
  end

  test "lifecycle chip text and classes derive from the model (anti-hardcode)" do
    candidate = render_episode(episode(Enum.map(@layer_ids, &layer(&1, lifecycle: :candidate))))
    assert candidate =~ ~s(data-testid="layer-lifecycle-sa2a")
    assert candidate =~ "CANDIDATE"
    assert candidate =~ "border-amber-500"
    refute candidate =~ "EXECUTED"
    refute candidate =~ "border-green-600"

    executed = render_episode(episode(Enum.map(@layer_ids, &layer(&1, lifecycle: :executed))))
    assert executed =~ "EXECUTED"
    assert executed =~ "border-green-600"
    refute executed =~ "CANDIDATE"
    refute executed =~ "border-amber-500"

    refused = render_episode(episode(Enum.map(@layer_ids, &layer(&1, lifecycle: :refused))))
    assert refused =~ "REFUSED"
    assert refused =~ "border-red-600"

    unknown = render_episode(episode(Enum.map(@layer_ids, &layer(&1, lifecycle: :unknown))))
    assert unknown =~ "UNKNOWN"
    assert unknown =~ "border-slate-400"
  end

  test "typed absence row renders NO BRIDGE with the model's reason and no liveness chip" do
    layers =
      Enum.map(@layer_ids, fn
        "sjira" -> layer("sjira", absence: %{reason: "no bridge rendered by pack"})
        id -> layer(id)
      end)

    html = render_episode(episode(layers))

    assert html =~ ~s(data-testid="layer-absence-sjira")
    assert html =~ "NO BRIDGE — no bridge rendered by pack"
    assert html =~ ~s(data-testid="layer-absence-standing-sjira")
    # no liveness-colored standing chip and no lifecycle badge on absence rows
    refute html =~ ~s(data-testid="layer-standing-sjira")
    refute html =~ ~s(data-testid="layer-lifecycle-sjira")
  end

  test "guard row renders when the model returns fewer than 10 layers" do
    html = render_episode(episode(Enum.take(full_layers(), 9)))
    assert html =~ "LAYER MISSING FROM MODEL"
    assert html =~ "expected 10"
    assert html =~ "model returned 9"
    # the rows that DO exist still render
    assert occurrences(html, @row_marker) == 9
  end

  test "drill-down panel renders evidence list and truthful NO RECEIPT absence" do
    ep = episode(full_layers())
    html = render_selected(ep, "sa2a")

    assert html =~ ~s(data-testid="layer-panel")
    assert html =~ ~s(data-testid="panel-id")
    assert html =~ "sa2a"
    assert html =~ ~s(data-testid="panel-evidence-none")
    assert html =~ "NO RECEIPT"
    assert html =~ "standing is UNKNOWN until a real receipt binds observed execution"
  end

  test "drill-down panel renders model-supplied evidence and receipt when present" do
    layers =
      Enum.map(@layer_ids, fn
        "sa2a" ->
          layer("sa2a",
            evidence: ["priv/chicago/receipts/sa2a.json"],
            receipt: %{digest: "sha256:abc123", verifier: "ggen-crown-court"}
          )

        id ->
          layer(id)
      end)

    html = render_selected(episode(layers), "sa2a")

    assert html =~ ~s(data-testid="panel-evidence-0")
    assert html =~ "priv/chicago/receipts/sa2a.json"
    assert html =~ ~s(data-testid="panel-receipt")
    assert html =~ ~s(data-testid="panel-receipt-digest")
    assert html =~ "sha256:abc123"
    assert html =~ "ggen-crown-court"
    refute html =~ "NO RECEIPT"
  end

  test "selecting an id the model does not carry renders the typed missing-layer guard" do
    ep = episode(full_layers())
    html = render_selected(ep, "not_in_model")

    assert html =~ ~s(data-testid="panel-layer-missing")
    assert html =~ "LAYER MISSING FROM MODEL"
    assert html =~ "not_in_model"
  end

  test "find_layer/2 resolves normalized layers and typed nil for unknown ids" do
    ep = episode(full_layers())

    assert %{id: "sa2a", lifecycle: :candidate, absence: nil} =
             DrillDownLive.find_layer({:ok, ep}, "sa2a")

    assert DrillDownLive.find_layer({:ok, ep}, "not_in_model") == nil
    assert DrillDownLive.find_layer({:refused, {:chicago_x, :y}}, "sa2a") == nil
  end

  test "blocked state renders the typed BLOCKED banner, never synthetic layers" do
    html = render_blocked({:chicago_projection, :not_rendered})

    assert html =~ ~s(data-testid="projection-blocked")
    assert html =~ "projection not rendered yet"
    assert html =~ "run mix chicago.render"
    assert html =~ ~s(data-testid="blocked-reason")
    assert html =~ ":chicago_projection"
    assert html =~ "LAYER MISSING FROM MODEL"
    assert html =~ "model returned 0"
    assert occurrences(html, @row_marker) == 0
  end

  ## Mount + module contract (runs now; live_isolated needs no route)

  test "drill_down_episode/0 returns the typed R4 result shape" do
    case DrillDownLive.drill_down_episode() do
      {:ok, episode} -> assert is_map(episode)
      {:refused, {code, reason}} when is_atom(code) -> assert not is_nil(reason)
      other -> flunk("unexpected drill_down_episode/0 shape: #{inspect(other)}")
    end
  end

  test "mount renders the model truthfully (loaded rows or typed BLOCKED state)", %{conn: conn} do
    {:ok, _view, html} = live_isolated(conn, DrillDownLive, session: %{})

    assert html =~ ~s(data-testid="chicago-root")
    assert html =~ ~s(data-testid="subject")

    case DrillDownLive.drill_down_episode() do
      {:ok, episode} ->
        assert html =~ episode_subject(episode)
        assert occurrences(html, @row_marker) == length(episode_layers(episode))

      {:refused, reason} ->
        assert html =~ ~s(data-testid="projection-blocked")
        assert html =~ "run mix chicago.render"
        # HEEx escapes the quotes inside inspect/1 output, so assert the
        # escape-stable parts: the typed code atom and the refusal path.
        assert html =~ inspect(elem(reason, 0))
        assert html =~ elem(reason, 1)
        assert html =~ "model returned 0"
    end
  end

  ## Route + interaction seams (excluded from lane runs; run at integration)

  # route/projection landed at integration (tag removed)
  test "GET /chicago mounts the drill-down live view (R6 route lands at integration)", %{
    conn: conn
  } do
    # plain binary path, not ~p — the router entry does not exist until the
    # coordinator lands R6, so compile-time route verification cannot see it.
    {:ok, _view, html} = live(conn, "/chicago")
    assert html =~ ~s(data-testid="chicago-root")
    assert html =~ ~s(data-testid="layer-rows")
  end

  # route/projection landed at integration (tag removed)
  test "select_layer event expands the drill-down panel (needs rendered projection)", %{
    conn: conn
  } do
    {:ok, view, _html} = live_isolated(conn, DrillDownLive, session: %{})

    case DrillDownLive.drill_down_episode() do
      {:ok, episode} ->
        id = first_layer_id(episode)

        html =
          view
          |> element(~s([data-testid="layer-select-#{id}"]))
          |> render_click()

        assert html =~ ~s(data-testid="layer-panel")
        assert html =~ to_string(id)

      {:refused, reason} ->
        flunk("projection still not rendered (#{inspect(reason)}) — run mix chicago.render")
    end
  end
end
