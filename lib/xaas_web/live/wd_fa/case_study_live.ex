defmodule XaasWeb.WdFa.CaseStudyLive do
  @moduledoc """
  Browser proof surface for WD Case Study 2.

  No LLM participates in KNOWN/PARTIAL/UNKNOWN classification here. This is
  the deterministic behavioral reference that later generated stacks must
  reproduce.
  """

  use XaasWeb, :live_view

  alias Xaas.CaseStudies.WdFa

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:selected, "known_firmware")
     |> assign(:experience_admitted, false)
     |> assign(:state, WdFa.presentation_state("known_firmware"))}
  end

  @impl true
  def handle_event("select_scenario", %{"id" => id}, socket) do
    learned? = id == "novel_x" and socket.assigns.experience_admitted

    {:noreply,
     socket
     |> assign(:selected, id)
     |> assign(:state, WdFa.presentation_state(id, learned?))}
  end

  @impl true
  def handle_event("admit_experience", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected, "novel_x")
     |> assign(:experience_admitted, true)
     |> assign(:state, WdFa.presentation_state("novel_x", true))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="mx-auto max-w-6xl p-8" data-testid="wd-fa-root">
      <header class="mb-8">
        <p class="text-sm font-semibold uppercase tracking-wide">WD Case Study 2</p>
        <h1 class="text-3xl font-bold">Failure Analysis Quality Loop</h1>
        <p class="mt-2 text-sm">
          standard → evidence → abnormality → work → disposition → verified experience → improved standard
        </p>
      </header>

      <nav class="mb-6 flex gap-3" data-testid="scenario-nav">
        <%= for id <- WdFa.scenario_ids() do %>
          <button type="button" phx-click="select_scenario" phx-value-id={id}
            data-testid={"scenario-" <> id} class="rounded border px-3 py-2">
            <%= id %>
          </button>
        <% end %>
      </nav>

      <section class="grid gap-4 md:grid-cols-4">
        <article class="rounded border p-4">
          <h2 class="font-semibold">Classification</h2>
          <div class="mt-2 text-2xl font-bold" data-testid="classification"><%= @state.classification %></div>
          <div data-testid="standing"><%= @state.standing %></div>
        </article>
        <article class="rounded border p-4">
          <h2 class="font-semibold">Admitted mode</h2>
          <div class="mt-2" data-testid="admitted-mode"><%= @state.admitted_mode || "NONE" %></div>
          <div class="text-sm" data-testid="confidence-basis"><%= @state.confidence_basis %></div>
        </article>
        <article class="rounded border p-4">
          <h2 class="font-semibold">Next action</h2>
          <div class="mt-2" data-testid="next-action"><%= @state.next_action %></div>
          <div class="text-sm" data-testid="owning-team"><%= @state.owning_team %></div>
        </article>
        <article class="rounded border p-4">
          <h2 class="font-semibold">Authority</h2>
          <div class="mt-2" data-testid="authority"><%= @state.authority %></div>
          <div class="text-sm" data-testid="human-gate"><%= @state.human_gate %></div>
        </article>
      </section>

      <section class="mt-6 grid gap-6 md:grid-cols-2">
        <article class="rounded border p-4">
          <h2 class="font-semibold">Evidence</h2>
          <ul data-testid="evidence-list">
            <%= for evidence <- @state.evidence do %><li><%= evidence %></li><% end %>
          </ul>
          <h3 class="mt-4 font-semibold">Missing required evidence</h3>
          <ul data-testid="missing-evidence">
            <%= if @state.missing_evidence == [] do %>
              <li>NONE</li>
            <% else %>
              <%= for evidence <- @state.missing_evidence do %><li><%= evidence %></li><% end %>
            <% end %>
          </ul>
        </article>

        <article class="rounded border p-4">
          <h2 class="font-semibold">Ranked hypotheses</h2>
          <ol data-testid="hypothesis-list">
            <%= for hypothesis <- @state.ranked_hypotheses do %>
              <li class="mb-3">
                <strong><%= hypothesis.mode %></strong>
                <span> score=<%= hypothesis.score %></span>
                <span> · candidate only</span>
              </li>
            <% end %>
          </ol>
          <h3 class="mt-4 font-semibold">Closest admitted prior art</h3>
          <ul data-testid="prior-cases">
            <%= if @state.prior_cases == [] do %>
              <li>NONE</li>
            <% else %>
              <%= for prior <- @state.prior_cases do %><li><%= prior %></li><% end %>
            <% end %>
          </ul>
        </article>
      </section>

      <section class="mt-6 rounded border p-4" data-testid="learning-loop">
        <h2 class="font-semibold">Standardized learning</h2>
        <p>UNKNOWN → investigation → verified disposition → MachineExperience → future KNOWN</p>
        <%= if @selected == "novel_x" and not @experience_admitted do %>
          <button type="button" phx-click="admit_experience" data-testid="admit-experience"
            class="mt-3 rounded border px-3 py-2">
            Admit verified MachineExperience fixture
          </button>
        <% end %>
      </section>
    </main>
    """
  end
end
