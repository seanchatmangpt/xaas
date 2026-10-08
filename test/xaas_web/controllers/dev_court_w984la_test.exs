defmodule XaasWeb.DevCourtW984laTest do
  @moduledoc """
  W984la unclaimed-family probe on the /dev-scope controller surface.

  There is no `*dev*` file in `lib/xaas_web/controllers/` — the /dev
  scope (lib/xaas_web/router.ex:339-379) mounts framework handlers
  (LiveDashboard, Swoosh MailboxPreview, AshAdmin) plus two first-party
  LiveView handlers: `XaasWeb.AutofdeLab.StatusLive`
  (/dev/dashboards/autofde-lab) and `XaasWeb.System.CommandCenterLive`
  (/system, same dev_routes gate).

  Census result: mounts, refresh events, and the /dev//system route
  entries are COVERED by
  test/xaas_web/dev_routes_court_test.exs,
  test/xaas/chicago/surface/command_center_{live,adapter}_test.exs, and
  test/xaas_web/live/autofde_lab/status_live_test.exs. The genuinely
  unexercised branches are:

  - `CommandCenterLive.standing_chip_classes/1` (all 4 case arms) and
    `state_chip_classes/1` (all 4 arms) — public pure functions with
    zero direct calls in the whole test tree (grep-verified);
  - `StatusLive.delivery_status_class/1` arms `:failed` and `:pending`
    (the existing test only seeds :delivered);
  - THIN dispositions recorded in the receipt, not filler-tested here:
    `delivery_status_class/1` catch-all (unreachable: the Ash enum
    `Xaas.Platform.Types.WebhookDeliveryStatus` admits only
    :pending/:delivered/:failed) and `verdict_class/1` (reachable only
    when the sibling autofde-lab repo's docs/STATUS.md exists in this
    checkout — external path, not courted here).
  """

  use XaasWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Xaas.Platform.WebhookDelivery
  alias XaasWeb.System.CommandCenterLive

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  # ------------------------------------------------------------------
  # CommandCenterLive chip-class pure functions (real direct calls)
  # ------------------------------------------------------------------

  test "standing_chip_classes/1 covers all four standing arms" do
    assert CommandCenterLive.standing_chip_classes("ALIVE") =~ "border-green-600"
    assert CommandCenterLive.standing_chip_classes("PARTIAL_ALIVE") =~ "border-amber-500"

    assert CommandCenterLive.standing_chip_classes("REFUSED_NO_RECEIPT") =~ "border-red-600"

    # catch-all: UNKNOWN and any other vocabulary renders slate
    assert CommandCenterLive.standing_chip_classes("UNKNOWN") =~ "border-dashed"
    assert CommandCenterLive.standing_chip_classes(:alive) =~ "border-dashed"
  end

  test "standing_chip_classes/1 accepts atom values (render passes projection values)" do
    assert CommandCenterLive.standing_chip_classes(:ALIVE) =~ "border-green-600"
    assert CommandCenterLive.standing_chip_classes(:"REFUSED_X") =~ "border-red-600"
  end

  test "state_chip_classes/1 covers all four state arms" do
    assert CommandCenterLive.state_chip_classes("running") =~ "bg-amber-100"
    assert CommandCenterLive.state_chip_classes("completed") =~ "bg-green-100"

    assert CommandCenterLive.state_chip_classes("failed") =~ "bg-red-100"
    assert CommandCenterLive.state_chip_classes("missed") =~ "bg-red-100"
    assert CommandCenterLive.state_chip_classes("abandoned") =~ "bg-red-100"

    assert CommandCenterLive.state_chip_classes("other") =~ "bg-slate-100"
  end

  # ------------------------------------------------------------------
  # StatusLive delivery-status chip arms via a real mount of the real
  # /dev route (dev_routes: true under test config, per W774 court)
  # ------------------------------------------------------------------

  defp create_webhook!(run) do
    Xaas.Generator.create_webhook!(%{
      org_id: "dev-court-w984la-org-#{run}",
      url: "https://example.invalid/webhooks/#{run}",
      event_types: ["backup.completed"]
    })
  end

  defp create_delivery!(webhook, event_type, status) do
    WebhookDelivery
    |> Ash.Changeset.for_create(
      :create,
      %{
        webhook_id: webhook.id,
        event_type: event_type,
        payload: %{"ok" => true},
        status: status,
        attempt_count: 1
      },
      authorize?: false
    )
    |> Ash.create!()
  end

  test "failed and pending delivery-status chip arms render via real /dev mount" do
    run = System.unique_integer([:positive, :monotonic])
    webhook = create_webhook!(run)

    create_delivery!(webhook, "backup.completed.w984la-failed-#{run}", :failed)
    create_delivery!(webhook, "backup.completed.w984la-pending-#{run}", :pending)

    {:ok, view, _html} = live(build_conn(), ~p"/dev/dashboards/autofde-lab")
    html = render(view)

    assert html =~ "backup.completed.w984la-failed-#{run}"
    assert html =~ "bg-red-100 text-red-800"
    assert html =~ "backup.completed.w984la-pending-#{run}"
    assert html =~ "bg-amber-100 text-amber-800"
  end
end
