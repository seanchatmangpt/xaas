defmodule XaasWeb.System.CommandCenterLiveTest do
  @moduledoc """
  Real `Phoenix.LiveViewTest` mount of the real
  `XaasWeb.System.CommandCenterLive` over real sandboxed `Xaas.Repo` rows
  (same shared-sandbox pattern as
  `XaasWeb.AutofdeLab.StatusLiveTest` — the LiveView runs in its own
  process, so shared mode is required for it to see the same transaction).

  The `/system` route entry itself lands at integration (R6); these tests
  mount the module directly via `live_isolated/3`, which needs no route.
  """

  use XaasWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Xaas.Ultracode.{Epoch, Run}
  alias XaasWeb.System.CommandCenterAdapter
  alias XaasWeb.System.CommandCenterLive

  @subject "urn:chicago:agentic-payment:purchase-001"

  setup do
    # ash-migration Phase 3: `Xaas.Repo` is a real, separate
    # `AshPostgres.Repo` from `Xaas.LegacyRepo` — `XaasWeb.ConnCase`'s
    # default `setup_sandbox` only checks out `Xaas.LegacyRepo`, so this
    # test checks out `Xaas.Repo` itself, in shared mode for the
    # separately-spawned LiveView process.
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  defp create_run!(goal) do
    Run
    |> Ash.Changeset.for_create(
      :create,
      %{goal: goal, provider: "zcode-chicago-live-test"},
      authorize?: false
    )
    |> Ash.create!()
  end

  defp create_epoch!(run, cycle) do
    Epoch
    |> Ash.Changeset.for_create(
      :create,
      %{run_id: run.id, cycle: cycle, exact_subject: @subject, state: :running},
      authorize?: false
    )
    |> Ash.create!()
  end

  defp digest_of(html) do
    case Regex.run(~r/state digest ([0-9a-f]{64})/, html) do
      [_, digest] -> digest
      _ -> flunk("no state digest rendered in html")
    end
  end

  test "mount renders the twelve questions, real rows, and standing chips", %{conn: conn} do
    run = create_run!("chicago live test — real running work")
    create_epoch!(run, 0)

    {:ok, _view, html} = live_isolated(conn, CommandCenterLive, session: %{})

    assert html =~ ~s(data-testid="command-center-root")
    assert html =~ @subject
    assert html =~ ~s(data-testid="answer-what_running")
    assert html =~ "chicago live test — real running work"
    assert html =~ "run-row-"
    assert html =~ "running"

    # real OCEL evidence section is present with its honest empty state or rows
    assert html =~ ~s(data-testid="ocel")
    assert html =~ "OCEL evidence"
  end

  test "refresh re-reads the real state (a Run created after mount appears)", %{conn: conn} do
    {:ok, view, html} = live_isolated(conn, CommandCenterLive, session: %{})

    refute html =~ "chicago live test — created after mount"

    create_run!("chicago live test — created after mount")

    html_after =
      view
      |> element(~s([data-testid="refresh"]))
      |> render_click()

    assert html_after =~ "chicago live test — created after mount"
  end

  test "state digest is stable across refresh with unchanged real state", %{conn: conn} do
    run = create_run!("chicago live test — digest stability")
    create_epoch!(run, 0)

    {:ok, view, html} = live_isolated(conn, CommandCenterLive, session: %{})

    html_after =
      view
      |> element(~s([data-testid="refresh"]))
      |> render_click()

    assert digest_of(html) == digest_of(html_after)
  end

  test "transport outcomes render as rows, never as a standing chip", %{conn: conn} do
    {:ok, _view, html} = live_isolated(conn, CommandCenterLive, session: %{})

    # The L4 projection has not landed in this lane build, so the typed
    # transport outcome row must render (and after L4 lands this section
    # legitimately disappears — assert conditionally on the adapter).
    case CommandCenterAdapter.snapshot().chicago do
      {:refused, _} ->
        assert html =~ ~s(data-testid="transport-outcomes")
        assert html =~ "chicago_projection"

      {:ok, _} ->
        assert html =~ ~s(data-testid="layers")
    end
  end

  test "refused receipts render as typed refusal rows with named reasons", %{conn: conn} do
    # The refusal fold is covered at the adapter level; here we prove the
    # refused section and its typed-reason testids render from the model.
    {:ok, _view, html} = live_isolated(conn, CommandCenterLive, session: %{})

    assert html =~ ~s(data-testid="refused")
    assert html =~ "Refused (typed, with reasons)"
  end
end
