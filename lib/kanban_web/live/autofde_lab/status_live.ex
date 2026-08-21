defmodule KanbanWeb.AutofdeLab.StatusLive do
  @moduledoc """
  Dev-only dashboard rendering the sibling `autofde-lab` repo's real
  `docs/STATUS.md` dispatch sheet via `Xaas.Autofde.StatusParser`.
  """
  use KanbanWeb, :live_view

  alias Xaas.Autofde.StatusParser

  @impl true
  def mount(_params, _session, socket) do
    {:ok, load_status(socket)}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, load_status(socket)}
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
    </div>
    """
  end

  defp verdict_class(:pass), do: "bg-green-100 text-green-800"
  defp verdict_class(:blocked), do: "bg-red-100 text-red-800"
  defp verdict_class(:mixed), do: "bg-amber-100 text-amber-800"
end
