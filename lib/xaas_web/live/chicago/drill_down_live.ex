defmodule XaasWeb.Chicago.DrillDownLive do
  @moduledoc """
  Chicago executive/machine drill-down surface (`/chicago`, R6: public
  `:browser` scope, wd-fa precedent, read-only observation).

  The view renders ONLY what `Xaas.Chicago.View.drill_down/0` (R4) returns.
  Every standing literal is the model's value — UNKNOWN until a real receipt
  binds observed execution (R8). The view never invents layers, receipts, or
  standings:

  - model loaded  -> header + subject literal + 10 layer rows with standing
    chips and lifecycle badges, typed absence rows, drill-down panel
  - model refuses -> typed BLOCKED banner naming the refusal and the
    remediation command (`mix chicago.render`), never synthetic layers
  - model returns a layer count other than the required 10 -> the
    "LAYER MISSING FROM MODEL" guard row renders above the rows that exist
  """

  use XaasWeb, :live_view

  @required_layer_count 10

  @impl true
  def mount(_params, _session, socket) do
    episode_result = drill_down_episode()

    {:ok,
     socket
     |> assign(:episode, episode_result)
     |> assign(base_assigns(episode_result))}
  end

  @impl true
  def handle_event("select_layer", %{"id" => id}, socket) do
    {:noreply,
     assign(socket,
       selected_id: id,
       selected_layer: find_layer(socket.assigns.episode, id)
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.drill_down
      subject={@subject}
      headline={@headline}
      detail={@detail}
      outcome_standing={@outcome_standing}
      layers={@layers}
      layer_count={@layer_count}
      required_layer_count={@required_layer_count}
      blocked={@blocked}
      blocked_reason={@blocked_reason}
      selected_id={@selected_id}
      selected_layer={@selected_layer}
    />
    """
  end

  @doc """
  Resolves the R4 projection view at runtime, compile-safe while
  `Xaas.Chicago.View` has not landed yet (L4 owns it). Returns
  `{:ok, episode}` or `{:refused, {code, reason}}` — never raises into the
  render path and never fabricates an episode.
  """
  def drill_down_episode do
    if Code.ensure_loaded?(Xaas.Chicago.View) and
         function_exported?(Xaas.Chicago.View, :drill_down, 0) do
      apply(Xaas.Chicago.View, :drill_down, [])
    else
      {:refused, {:chicago_view_unavailable, :projection_not_rendered}}
    end
  end

  @doc """
  Pure mapping from a `drill_down_episode/0` result to the assigns the
  drill_down component renders. Mount uses it; tests use it to drive the
  real template with model-shaped inputs.
  """
  def base_assigns({:ok, episode}) do
    layers =
      episode
      |> Map.get(:layers, Map.get(episode, "layers", []))
      |> Enum.map(&normalize_layer/1)

    outcome = field(episode, :business_outcome) || %{}

    [
      subject: field(episode, :subject),
      headline: field(outcome, :headline),
      detail: field(outcome, :detail),
      outcome_standing: field(outcome, :standing),
      layers: layers,
      layer_count: length(layers),
      required_layer_count: @required_layer_count,
      blocked: false,
      blocked_reason: nil,
      selected_id: nil,
      selected_layer: nil
    ]
  end

  def base_assigns({:refused, reason}) do
    [
      subject: refused_subject(),
      headline: nil,
      detail: nil,
      outcome_standing: nil,
      layers: [],
      layer_count: 0,
      required_layer_count: @required_layer_count,
      blocked: true,
      blocked_reason: reason,
      selected_id: nil,
      selected_layer: nil
    ]
  end

  @doc """
  Finds a layer by contract-slug id in a `drill_down_episode/0` result and
  returns its normalized form (the same shape rendered in rows), or nil when
  the model does not carry the id.
  """
  def find_layer({:ok, episode}, id) do
    layers = Map.get(episode, :layers, Map.get(episode, "layers", []))

    case Enum.find(layers, &(to_string(field(&1, :id)) == id)) do
      nil -> nil
      layer -> normalize_layer(layer)
    end
  end

  def find_layer(_episode_result, _id), do: nil

  @doc "Lifecycle badge text, derived from the model's lifecycle value."
  def lifecycle_text(:candidate), do: "CANDIDATE"
  def lifecycle_text(:executed), do: "EXECUTED"
  def lifecycle_text(:refused), do: "REFUSED"
  def lifecycle_text(:admitted), do: "ADMITTED"
  def lifecycle_text(:unknown), do: "UNKNOWN"
  def lifecycle_text(other), do: String.upcase(to_string(other))

  @doc """
  Lifecycle badge classes: candidate dashed amber, executed solid green,
  refused solid red, admitted solid slate, unknown slate-dashed.
  """
  def lifecycle_classes(:candidate),
    do: "rounded border border-dashed border-amber-500 bg-amber-50 px-2 py-0.5 font-mono text-xs text-amber-700"

  def lifecycle_classes(:executed),
    do: "rounded border border-green-600 bg-green-100 px-2 py-0.5 font-mono text-xs text-green-800"

  def lifecycle_classes(:refused),
    do: "rounded border border-red-600 bg-red-100 px-2 py-0.5 font-mono text-xs text-red-800"

  def lifecycle_classes(:admitted),
    do: "rounded border border-slate-600 bg-slate-100 px-2 py-0.5 font-mono text-xs text-slate-800"

  def lifecycle_classes(_),
    do: "rounded border border-dashed border-slate-400 bg-slate-50 px-2 py-0.5 font-mono text-xs text-slate-600"

  @doc """
  Standing chip classes for rows that HAVE a bridge. Absence rows carry no
  liveness-colored chip at all (the standing renders as muted text inside
  the typed absence row instead).
  """
  def standing_chip_classes,
    do: "rounded border border-slate-400 bg-white px-2 py-0.5 font-mono text-xs text-slate-700"

  attr :subject, :string, default: nil
  attr :headline, :string, default: nil
  attr :detail, :string, default: nil
  attr :outcome_standing, :string, default: nil
  attr :layers, :list, default: []
  attr :layer_count, :integer, default: 0
  attr :required_layer_count, :integer, default: 10
  attr :blocked, :boolean, default: false
  attr :blocked_reason, :any, default: nil
  attr :selected_id, :string, default: nil
  attr :selected_layer, :any, default: nil

  def drill_down(assigns) do
    ~H"""
    <main class="mx-auto max-w-6xl p-8" data-testid="chicago-root">
      <header class="mb-8">
        <p class="text-sm font-semibold uppercase tracking-wide">
          Chicago agentic payment — executive/machine drill-down
        </p>
        <h1 class="text-3xl font-bold">Layer drill-down</h1>
        <p class="mt-2 font-mono text-sm" data-testid="subject">
          {subject_text(@subject)}
        </p>

        <div
          :if={@blocked}
          class="mt-3 rounded border border-red-400 bg-red-50 p-3"
          data-testid="projection-blocked"
        >
          <p class="font-semibold text-red-800">BLOCKED — projection not rendered yet</p>
          <p class="mt-1 font-mono text-xs text-red-700" data-testid="blocked-reason">
            {inspect(@blocked_reason)}
          </p>
          <p class="mt-1 text-sm text-red-800">
            executive/machine projection not rendered yet — run mix chicago.render
          </p>
        </div>

        <section :if={@headline} class="mt-4" data-testid="business-outcome">
          <h2 class="text-xl font-semibold">{@headline}</h2>
          <p class="mt-1 text-sm">{@detail}</p>
          <p class="mt-1 font-mono text-xs" data-testid="business-outcome-standing">
            standing: {@outcome_standing}
          </p>
        </section>

        <div
          class="mt-3 flex flex-wrap gap-x-4 gap-y-1 text-xs text-slate-600"
          data-testid="legend"
        >
          <span>dashed amber = candidate</span>
          <span>solid green = executed</span>
          <span>red = refused</span>
          <span>slate = admitted / unknown</span>
          <span>standing text is the model value until a real receipt binds observed execution</span>
        </div>
      </header>

      <div
        :if={@layer_count != @required_layer_count}
        class="mb-4 rounded border border-red-400 bg-red-50 p-3 font-mono text-sm text-red-800"
        data-testid="layer-count-guard"
      >
        LAYER MISSING FROM MODEL — expected {@required_layer_count}, model returned {@layer_count}
      </div>

      <section class="space-y-2" data-testid="layer-rows">
        <%= for layer <- @layers do %>
          <%= if layer.absence do %>
            <div
              class="rounded border border-slate-300 bg-slate-50 p-3"
              data-testid={"layer-absence-" <> layer.id}
            >
              <div class="flex items-center justify-between gap-3">
                <span class="font-semibold text-slate-500">{layer.label}</span>
                <span
                  class="font-mono text-xs text-slate-400"
                  data-testid={"layer-absence-standing-" <> layer.id}
                >
                  {layer.standing}
                </span>
              </div>
              <p
                class="mt-1 font-mono text-xs text-slate-600"
                data-testid={"layer-absence-reason-" <> layer.id}
              >
                NO BRIDGE — {layer.absence.reason}
              </p>
            </div>
          <% else %>
            <div
              class="flex items-center justify-between gap-3 rounded border border-slate-300 bg-white p-3"
              data-testid={"layer-row-" <> layer.id}
            >
              <button
                type="button"
                phx-click="select_layer"
                phx-value-id={layer.id}
                data-testid={"layer-select-" <> layer.id}
                class="text-left font-semibold text-slate-900 hover:underline"
              >
                {layer.label}
              </button>
              <div class="flex items-center gap-2">
                <span class={standing_chip_classes()} data-testid={"layer-standing-" <> layer.id}>
                  {layer.standing}
                </span>
                <span
                  class={lifecycle_classes(layer.lifecycle)}
                  data-testid={"layer-lifecycle-" <> layer.id}
                >
                  {lifecycle_text(layer.lifecycle)}
                </span>
              </div>
            </div>
          <% end %>
        <% end %>
      </section>

      <.layer_panel :if={@selected_id} selected_id={@selected_id} selected_layer={@selected_layer} />
    </main>
    """
  end

  attr :selected_id, :string, required: true
  attr :selected_layer, :any, default: nil

  def layer_panel(assigns) do
    ~H"""
    <section class="mt-6 rounded border p-4" data-testid="layer-panel">
      <h2 class="font-semibold" data-testid="panel-title">
        <%= if @selected_layer do %>
          {@selected_layer.label}
        <% else %>
          LAYER MISSING FROM MODEL
        <% end %>
      </h2>

      <%= if @selected_layer do %>
        <p class="mt-1 font-mono text-xs text-slate-600" data-testid="panel-id">
          {@selected_layer.id}
        </p>
        <p class="mt-2 text-sm" data-testid="panel-what-happened">
          {@selected_layer.what_happened}
        </p>
        <div class="mt-2 flex items-center gap-2">
          <span class={standing_chip_classes()} data-testid="panel-standing">
            {@selected_layer.standing}
          </span>
          <span
            class={lifecycle_classes(@selected_layer.lifecycle)}
            data-testid="panel-lifecycle"
          >
            {lifecycle_text(@selected_layer.lifecycle)}
          </span>
        </div>

        <h3 class="mt-4 font-semibold">Evidence</h3>
        <ul class="mt-1 list-disc pl-5 text-sm" data-testid="panel-evidence">
          <%= if @selected_layer.evidence == [] do %>
            <li data-testid="panel-evidence-none">
              NO EVIDENCE REFS — standing stays UNKNOWN until observed execution binds one
            </li>
          <% else %>
            <%= for {item, index} <- Enum.with_index(@selected_layer.evidence) do %>
              <li data-testid={"panel-evidence-" <> Integer.to_string(index)}>
                {evidence_text(item)}
              </li>
            <% end %>
          <% end %>
        </ul>

        <h3 class="mt-4 font-semibold">Receipt</h3>
        <%= if @selected_layer.receipt do %>
          <div class="mt-1 rounded border p-2 font-mono text-xs" data-testid="panel-receipt">
            <p data-testid="panel-receipt-digest">{receipt_digest(@selected_layer.receipt)}</p>
            <p data-testid="panel-receipt-verifier">
              verifier: {receipt_field(@selected_layer.receipt, :verifier)}
            </p>
          </div>
        <% else %>
          <p class="mt-1 font-mono text-xs text-slate-600" data-testid="panel-no-receipt">
            NO RECEIPT — standing is UNKNOWN until a real receipt binds observed execution
          </p>
        <% end %>
      <% else %>
        <p class="mt-1 font-mono text-xs text-red-700" data-testid="panel-layer-missing">
          LAYER MISSING FROM MODEL — id {@selected_id} is not in the returned model
        </p>
      <% end %>
    </section>
    """
  end

  ## Normalization helpers (model-shaped inputs, no fabrication)

  defp normalize_layer(layer) do
    %{
      id: to_string(field(layer, :id)),
      label: field(layer, :label),
      what_happened: field(layer, :what_happened),
      standing: field(layer, :standing),
      lifecycle: field(layer, :lifecycle),
      evidence: field(layer, :evidence) || [],
      receipt: field(layer, :receipt),
      absence: absence_map(field(layer, :absence))
    }
  end

  defp absence_map(nil), do: nil
  defp absence_map(reason) when is_binary(reason), do: %{reason: reason}

  defp absence_map(map) when is_map(map) do
    case field(map, :reason) do
      nil -> %{reason: inspect(map)}
      reason -> %{reason: to_string(reason)}
    end
  end

  defp absence_map(other), do: %{reason: to_string(other)}

  defp field(map, key) when is_map(map) and is_atom(key) do
    case Map.fetch(map, key) do
      {:ok, value} -> value
      :error -> Map.get(map, Atom.to_string(key))
    end
  end

  defp subject_text(nil), do: "UNAVAILABLE — model not loaded"
  defp subject_text(subject) when is_binary(subject), do: subject
  defp subject_text(other), do: to_string(other)

  defp refused_subject do
    if Code.ensure_loaded?(Xaas.Chicago) and function_exported?(Xaas.Chicago, :subject, 0) do
      case apply(Xaas.Chicago, :subject, []) do
        {:ok, subject} -> subject
        _ -> nil
      end
    else
      nil
    end
  end

  defp evidence_text(item) when is_binary(item), do: item

  defp evidence_text(item) when is_map(item) do
    cond do
      ref = field(item, :ref) -> to_string(ref)
      description = field(item, :description) -> to_string(description)
      true -> inspect(item)
    end
  end

  defp evidence_text(other), do: to_string(other)

  defp receipt_digest(receipt) when is_binary(receipt), do: receipt

  defp receipt_digest(receipt) when is_map(receipt) do
    field(receipt, :digest) || field(receipt, :id) || "digest not provided by model"
  end

  defp receipt_field(receipt, key) when is_map(receipt) do
    case field(receipt, key) do
      nil -> "not provided by model"
      value -> to_string(value)
    end
  end
end
