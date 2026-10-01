defmodule XaasWeb.Pradyot.SurfaceLive do
  @moduledoc "Read-only Monday demo projection over XaaS-owned semantic state."
  use XaasWeb, :live_view

  alias Xaas.Demo.PradyotSurface

  @impl true
  def mount(params, _session, socket) do
    view =
      case socket.assigns[:live_action] do
        :chicago -> "chicago"
        :seller -> "seller"
        :system -> "system"
        _ -> Map.get(params, "view", "system")
      end

    {:ok, assign_view(socket, view)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="max-w-6xl mx-auto p-6 space-y-6" id={"pradyot-" <> @view}>
      <header>
        <p class="text-xs uppercase tracking-wide text-slate-500">XaaS · AshSurface projection</p>
        <h1 class="text-3xl font-bold">{@title}</h1>
        <p class="font-mono text-sm mt-2">subject: {@data.subject}</p>
        <p class="mt-2 text-sm"><strong>UI authority:</strong> NONE · consequential DO remains XaaS/BRCE-owned.</p>
      </header>

      <nav class="flex gap-4 text-sm">
        <a href="/system">System</a><a href="/chicago">Chicago episode</a><a href="/seller">Seller view</a>
      </nav>

      <section :if={@view == "system"} class="grid md:grid-cols-2 gap-4">
        <.card title="What exists" value={@data.exists} />
        <.card title="What is running" value={@data.running} />
        <.card title="Admitted capabilities" value={@data.capabilities} />
        <.card title="Requirements / obligations" value={@data.obligations} />
        <.card title="Plans / candidates" value={@data.candidates} />
        <.card title="Execution / refusal" value={@data.execution} />
        <.card title="Receipts" value={@data.receipts} />
        <.card title="OCEL / evidence" value={@data.evidence} />
        <.card title="Standing" value={@data.standing} />
        <.card title="Replay / freshness" value={@data.replay} />
      </section>

      <section :if={@view == "chicago"} class="space-y-3">
        <p><strong>Outcome:</strong> {@data.outcome}</p>
        <div :for={layer <- @data.layers} class="border rounded p-4">
          <div class="flex justify-between gap-3">
            <strong>{layer.label}</strong><span class="font-mono text-xs">{layer.state}</span>
          </div>
          <p class="text-sm mt-2">{layer.evidence}</p>
        </div>
      </section>

      <section :if={@view == "seller"} class="space-y-4">
        <.card title="Customer problem" value={@data.customer_problem} />
        <.card title="Desired outcome" value={@data.desired_outcome} />
        <.card title="Relevant capabilities" value={@data.capabilities} />
        <.card title="Proposed path" value={@data.proposed_path} />
        <.card title="Evidence available now" value={@data.evidence_now} />
        <.card title="Boundaries / authority" value={@data.boundaries} />
        <.card title="Demonstrated" value={@data.demonstrated} />
        <.card title="Hypothetical" value={@data.hypothetical} />
        <.card title="Delivery status" value={@data.delivery_status} />
      </section>
    </main>
    """
  end

  attr :title, :string, required: true
  attr :value, :any, required: true
  defp card(assigns) do
    ~H"""
    <article class="border rounded p-4">
      <h2 class="font-semibold mb-2">{@title}</h2>
      <pre class="text-xs whitespace-pre-wrap break-words">{inspect(@value, pretty: true, limit: :infinity)}</pre>
    </article>
    """
  end

  defp assign_view(socket, "chicago"),
    do: assign(socket, view: "chicago", title: "Chicago Agentic Payments", data: PradyotSurface.chicago())

  defp assign_view(socket, "seller"),
    do: assign(socket, view: "seller", title: "Seller projection", data: PradyotSurface.seller())

  defp assign_view(socket, _),
    do: assign(socket, view: "system", title: "Live system view", data: PradyotSurface.system())
end
