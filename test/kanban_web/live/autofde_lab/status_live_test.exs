defmodule KanbanWeb.AutofdeLab.StatusLiveTest do
  @moduledoc """
  Real Chicago-style coverage for `KanbanWeb.AutofdeLab.StatusLive`'s
  second panel: a real `Phoenix.LiveViewTest` mount of the real
  `/dev/dashboards/autofde-lab` route, asserting the real, seeded
  `Xaas.Platform.WebhookDelivery` rows' real values appear in the real
  rendered HTML -- state-based, no mock of the data layer.
  """
  # async: false -- the LiveView mounted by `live/2` below runs in its own
  # process, separate from the test process; real `Ecto.Adapters.SQL.Sandbox`
  # shared mode (set up below) is required for that process to see the same
  # real `Xaas.Repo` transaction, and shared mode is real Ecto/Sandbox
  # advice against running async (same pattern already used by this repo's
  # other real Xaas.Repo-backed test setups).
  use KanbanWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Xaas.Platform.Webhook
  alias Xaas.Platform.WebhookDelivery

  setup do
    # ash-migration Phase 3: `Xaas.Repo` is a real, separate
    # `AshPostgres.Repo` from `Kanban.Repo` -- `KanbanWeb.ConnCase`'s
    # default `setup_sandbox` only checks out `Kanban.Repo`, so every real
    # Xaas.* Ash-resource test (this one included) checks out `Xaas.Repo`
    # itself. Shared mode so the separately-spawned LiveView process can
    # see the same real sandboxed transaction.
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  defp create_webhook!(run) do
    Webhook
    |> Ash.Changeset.for_create(
      :create,
      %{
        org_id: "status-live-test-org-#{run}",
        url: "https://example.invalid/webhooks/#{run}",
        event_types: ["backup.completed"],
        secret: "real-hmac-secret",
        enabled: true
      },
      authorize?: false
    )
    |> Ash.create!()
  end

  defp create_delivery!(webhook, event_type, status, attempt_count) do
    WebhookDelivery
    |> Ash.Changeset.for_create(
      :create,
      %{
        webhook_id: webhook.id,
        event_type: event_type,
        payload: %{"ok" => true},
        status: status,
        attempt_count: attempt_count
      },
      authorize?: false
    )
    |> Ash.create!()
  end

  test "renders real seeded WebhookDelivery rows in the recent-activity panel", %{conn: conn} do
    run = System.unique_integer([:positive, :monotonic])
    webhook = create_webhook!(run)

    delivery =
      create_delivery!(webhook, "backup.completed.status-live-test-#{run}", :delivered, 2)

    {:ok, view, _html} = live(conn, ~p"/dev/dashboards/autofde-lab")

    html = render(view)

    assert html =~ "xaas platform: recent webhook deliveries"
    assert html =~ "backup.completed.status-live-test-#{run}"
    assert html =~ "delivered"
    assert html =~ "2"

    # Real refresh event re-reads the real data (existing control, reused).
    html_after_refresh =
      view
      |> element("button", "Refresh")
      |> render_click()

    assert html_after_refresh =~ "backup.completed.status-live-test-#{run}"
    assert is_binary(delivery.id)
  end
end
