defmodule KanbanWeb.AutofdeLab.StatusLive do
  @moduledoc """
  Dev-only dashboard rendering the sibling `autofde-lab` repo's real
  `docs/STATUS.md` dispatch sheet via `Xaas.Autofde.StatusParser`.
  """
  use KanbanWeb, :live_view

  alias Xaas.Autofde.StatusParser
  alias Xaas.Platform.WebhookDelivery

  # Real second panel's data source: the real, most-recent N
  # `Xaas.Platform.WebhookDelivery` rows (status, event_type,
  # attempt_count, inserted_at) -- chosen over the Ledger balance option
  # because a delivery row is a simple, already-final read (no
  # cross-account aggregation math needed to make the panel honest) and
  # this table is the one every `Subscription`/`BackupRetention`/
  # `SlaCredit` webhook-dispatch path in this session actually writes to
  # via `Xaas.Platform.Changes.DeliverWebhook`, so it is real live
  # platform activity, not synthetic data invented for this panel.
  @recent_deliveries_limit 10

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> load_status() |> load_webhook_deliveries()}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, socket |> load_status() |> load_webhook_deliveries()}
  end

  defp load_status(socket) do
    case StatusParser.parse() do
      {:error, :not_found} ->
        socket
        |> Phoenix.Component.assign(:error, :not_found)
        |> Phoenix.Component.assign(:status_path, StatusParser.default_path())
        |> Phoenix.Component.assign(:passes, [])

      passes when is_list(passes) ->
        socket
        |> Phoenix.Component.assign(:error, nil)
        |> Phoenix.Component.assign(:passes, passes)
    end
  end

  # Real read of the real, most-recent `WebhookDelivery` rows. Internal
  # dev-only dashboard behind the same `dev_routes` guard as
  # `ash_admin`/`live_dashboard` on this route -- `authorize?: false`
  # matches that existing trust boundary, not a new one.
  defp load_webhook_deliveries(socket) do
    deliveries =
      WebhookDelivery
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.limit(@recent_deliveries_limit)
      |> Ash.read!(authorize?: false)

    Phoenix.Component.assign(socket, :webhook_deliveries, deliveries)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto p-6">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold">autofde-lab benchmark history</h1>
        <button
          phx-click="refresh"
          class="px-3 py-1.5 rounded bg-slate-800 text-white text-sm hover:bg-slate-700"
        >
          Refresh
        </button>
      </div>

      <%= if @error == :not_found do %>
        <div class="rounded border border-red-300 bg-red-50 text-red-800 p-4">
          autofde-lab not found at {@status_path} -- checkout the sibling repo to see real benchmark history
        </div>
      <% else %>
        <ul class="space-y-4">
          <li :for={pass <- @passes} class="rounded border border-slate-200 p-4">
            <div class="flex items-center gap-3 mb-1">
              <span class="font-mono font-semibold">Pass {pass.pass}</span>
              <span :if={pass.date} class="text-sm text-slate-500">{pass.date}</span>
              <span class={[
                "text-xs font-semibold uppercase px-2 py-0.5 rounded",
                verdict_class(pass.verdict)
              ]}>
                {pass.verdict}
              </span>
            </div>
            <p class="text-sm text-slate-700">{pass.summary}</p>
          </li>
        </ul>
      <% end %>

      <div class="flex items-center justify-between mt-10 mb-4">
        <h2 class="text-xl font-bold">xaas platform: recent webhook deliveries</h2>
      </div>

      <table class="w-full text-sm border border-slate-200">
        <thead class="bg-slate-50">
          <tr>
            <th class="text-left p-2 border-b border-slate-200">Event type</th>
            <th class="text-left p-2 border-b border-slate-200">Status</th>
            <th class="text-left p-2 border-b border-slate-200">Attempts</th>
            <th class="text-left p-2 border-b border-slate-200">Inserted at</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={delivery <- @webhook_deliveries} class="border-b border-slate-100">
            <td class="p-2 font-mono">{delivery.event_type}</td>
            <td class="p-2">
              <span class={[
                "text-xs font-semibold uppercase px-2 py-0.5 rounded",
                delivery_status_class(delivery.status)
              ]}>
                {delivery.status}
              </span>
            </td>
            <td class="p-2">{delivery.attempt_count}</td>
            <td class="p-2 text-slate-500">{delivery.inserted_at}</td>
          </tr>
          <tr :if={@webhook_deliveries == []}>
            <td colspan="4" class="p-4 text-center text-slate-500">
              No webhook deliveries yet.
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  defp verdict_class(:pass), do: "bg-green-100 text-green-800"
  defp verdict_class(:blocked), do: "bg-red-100 text-red-800"
  defp verdict_class(:mixed), do: "bg-amber-100 text-amber-800"

  defp delivery_status_class(:delivered), do: "bg-green-100 text-green-800"
  defp delivery_status_class(:failed), do: "bg-red-100 text-red-800"
  defp delivery_status_class(:pending), do: "bg-amber-100 text-amber-800"
  defp delivery_status_class(_), do: "bg-slate-100 text-slate-800"
end
