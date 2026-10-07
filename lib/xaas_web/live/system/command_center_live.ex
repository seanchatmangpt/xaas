defmodule XaasWeb.System.CommandCenterLive do
  @moduledoc """
  Single Monday-legible `/system` page (R6: inside the `dev_routes` block)
  answering the twelve agentic-payment questions from ONE deterministic
  read model, `XaasWeb.System.CommandCenterAdapter.snapshot/0`:

    1. what exists            — Chicago layers (R2 contract slugs)
    2. what is running        — real `Xaas.Ultracode.Run`/`Epoch` rows
    3. obligations            — OBSERVE-only `AshSurface.Obligation` structs
    4. capabilities admitted  — receipt-backed count (0 until a real receipt)
    5. plans                  — `AshSurface.PlanningEpisode` structs (:SELECT)
    6. executed               — `Xaas.Sa2a.Execution` rows + completed epochs
    7. refused                — typed refusal rows with named reasons
    8. unknown                — transport-outcome/candidate rows (R8: UNKNOWN
                                 is never an AshSurface standing; it renders
                                 here as rows, in slate)
    9. receipts               — real `Xaas.Ultracode.Receipt` rows
   10. OCEL evidence          — real `Xaas.Ocel.Event` rows
   11. standing per claim     — per-layer standing chips, full vocabulary
   12. replayable             — executions with `replay_verified: true`

  This Live performs ZERO mutations: no Ash mutation call exists in this
  module (grep-gated by the lane tests); the only event is `refresh`,
  which re-runs the adapter's read-only snapshot.
  """

  use XaasWeb, :live_view

  alias XaasWeb.System.CommandCenterAdapter

  @question_labels %{
    "what_exists" => "what exists",
    "what_running" => "running now",
    "obligations" => "obligations",
    "capabilities_admitted" => "capabilities admitted",
    "plans" => "plans",
    "executed" => "executed",
    "refused" => "refused",
    "unknown" => "unknown",
    "receipts" => "receipts",
    "ocel_evidence" => "OCEL evidence",
    "standing_per_claim" => "standing per claim",
    "replayable" => "replayable"
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:snap, CommandCenterAdapter.snapshot())
     # HEEx `@question_labels` reads the ASSIGN, not the module attribute —
     # the module attribute is the compile-time source, assigned here.
     |> assign(:question_labels, @question_labels)}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, assign(socket, :snap, CommandCenterAdapter.snapshot())}
  end

  @doc """
  Standing chip classes for rendered evidence vocabulary: ALIVE green,
  PARTIAL_ALIVE amber, every REFUSED_* red (reason row renders beside it),
  everything else — including UNKNOWN — slate. String-driven so projection
  values never need atom conversion.
  """
  def standing_chip_classes(value) do
    case to_string(value) do
      "ALIVE" ->
        "rounded border border-green-600 bg-green-100 px-2 py-0.5 font-mono text-xs text-green-800"

      "PARTIAL_ALIVE" ->
        "rounded border border-amber-500 bg-amber-50 px-2 py-0.5 font-mono text-xs text-amber-700"

      "REFUSED" <> _ ->
        "rounded border border-red-600 bg-red-100 px-2 py-0.5 font-mono text-xs text-red-800"

      _ ->
        "rounded border border-dashed border-slate-400 bg-slate-50 px-2 py-0.5 font-mono text-xs text-slate-600"
    end
  end

  @doc "Lifecycle/state chip classes for Run/Epoch rows."
  def state_chip_classes(value) do
    case to_string(value) do
      "running" ->
        "rounded bg-amber-100 px-2 py-0.5 font-mono text-xs text-amber-800"

      "completed" ->
        "rounded bg-green-100 px-2 py-0.5 font-mono text-xs text-green-800"

      state when state in ["failed", "missed", "abandoned"] ->
        "rounded bg-red-100 px-2 py-0.5 font-mono text-xs text-red-800"

      _ ->
        "rounded bg-slate-100 px-2 py-0.5 font-mono text-xs text-slate-800"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-6xl p-6" data-testid="command-center-root">
      <div class="flex items-start justify-between gap-4 mb-4">
        <div>
          <h1 class="text-2xl font-bold">System command center — agentic payment</h1>
          <p class="mt-1 font-mono text-sm" data-testid="subject">{@snap.exact_subject}</p>
          <p class="font-mono text-xs text-slate-500" data-testid="state-digest">
            state digest {@snap.command_center.state_digest}
          </p>
        </div>
        <button
          phx-click="refresh"
          data-testid="refresh"
          class="px-3 py-1.5 rounded bg-slate-800 text-white text-sm hover:bg-slate-700"
        >
          Refresh
        </button>
      </div>

      <div
        :if={@snap.transport != []}
        class="mb-4 rounded border border-slate-300 bg-slate-50 p-3"
        data-testid="transport-outcomes"
      >
        <p class="text-sm font-semibold text-slate-700">
          transport outcomes (UNKNOWN renders here — never as a standing)
        </p>
        <ul class="mt-1 space-y-1">
          <li
            :for={{row, index} <- Enum.with_index(@snap.transport)}
            class="font-mono text-xs text-slate-600"
            data-testid={"transport-row-" <> Integer.to_string(index)}
          >
            {row.component} — {row.outcome} — {row.reason}
          </li>
        </ul>
      </div>

      <section class="mb-8" data-testid="answers">
        <h2 class="text-lg font-semibold mb-2">The twelve questions</h2>
        <div class="grid grid-cols-2 gap-2 md:grid-cols-4">
          <div
            :for={{slug, label} <- @question_labels}
            class="rounded border border-slate-200 p-2"
            data-testid={"answer-" <> slug}
          >
            <p class="text-xs uppercase tracking-wide text-slate-500">{label}</p>
            <p class="text-xl font-bold">{@snap.answers[slug]}</p>
          </div>
        </div>
      </section>

      <section class="mb-8" data-testid="layers">
        <h2 class="text-lg font-semibold mb-2">Layers — what exists + standing per claim</h2>
        <table class="w-full text-sm border border-slate-200">
          <thead class="bg-slate-50">
            <tr>
              <th class="text-left p-2 border-b border-slate-200">Layer</th>
              <th class="text-left p-2 border-b border-slate-200">Capability</th>
              <th class="text-left p-2 border-b border-slate-200">Standing</th>
              <th class="text-left p-2 border-b border-slate-200">Evidence / receipts</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={layer <- @snap.layers}
              class="border-b border-slate-100"
              data-testid={"layer-row-" <> layer.id}
            >
              <td class="p-2 font-semibold">{layer.label}</td>
              <td class="p-2 font-mono text-xs">{layer.capability_id}</td>
              <td class="p-2">
                <span
                  class={standing_chip_classes(layer.status)}
                  data-testid={"layer-standing-" <> layer.id}
                >
                  {layer.status}
                </span>
              </td>
              <td class="p-2 text-xs text-slate-500">
                {length(layer.evidence_refs)} evidence / {length(layer.receipt_refs)} receipt refs
              </td>
            </tr>
            <tr :if={@snap.layers == []}>
              <td colspan="4" class="p-4 text-center text-slate-500">
                no layers in the model yet — standing stays UNKNOWN until a real receipt binds observed execution
              </td>
            </tr>
          </tbody>
        </table>
      </section>

      <section class="mb-8" data-testid="running">
        <h2 class="text-lg font-semibold mb-2">Running — real Runs and Epochs</h2>
        <table class="w-full text-sm border border-slate-200">
          <thead class="bg-slate-50">
            <tr>
              <th class="text-left p-2 border-b border-slate-200">Kind</th>
              <th class="text-left p-2 border-b border-slate-200">Goal / subject</th>
              <th class="text-left p-2 border-b border-slate-200">State</th>
              <th class="text-left p-2 border-b border-slate-200">Standing</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={run <- @snap.runs}
              class="border-b border-slate-100"
              data-testid={"run-row-" <> run.id}
            >
              <td class="p-2 font-mono text-xs">run</td>
              <td class="p-2">{run.goal}</td>
              <td class="p-2"><span class={state_chip_classes(run.state)}>{run.state}</span></td>
              <td class="p-2">
                <span class={standing_chip_classes(run.standing)}>{run.standing}</span>
              </td>
            </tr>
            <tr
              :for={epoch <- @snap.epochs}
              class="border-b border-slate-100"
              data-testid={"epoch-row-" <> epoch.id}
            >
              <td class="p-2 font-mono text-xs">epoch {epoch.cycle}</td>
              <td class="p-2 font-mono text-xs">{epoch.exact_subject}</td>
              <td class="p-2"><span class={state_chip_classes(epoch.state)}>{epoch.state}</span></td>
              <td class="p-2 text-slate-400">—</td>
            </tr>
            <tr :if={@snap.runs == [] and @snap.epochs == []}>
              <td colspan="4" class="p-4 text-center text-slate-500">nothing running</td>
            </tr>
          </tbody>
        </table>
      </section>

      <section class="mb-8" data-testid="obligations">
        <h2 class="text-lg font-semibold mb-2">Obligations (OBSERVE-only projections)</h2>
        <table class="w-full text-sm border border-slate-200">
          <thead class="bg-slate-50">
            <tr>
              <th class="text-left p-2 border-b border-slate-200">Obligation</th>
              <th class="text-left p-2 border-b border-slate-200">Capability</th>
              <th class="text-left p-2 border-b border-slate-200">Cause</th>
              <th class="text-left p-2 border-b border-slate-200">Status</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={obligation <- @snap.command_center.obligations}
              class="border-b border-slate-100"
              data-testid={"obligation-row-" <> obligation.obligation_id}
            >
              <td class="p-2 font-mono text-xs">{obligation.obligation_id}</td>
              <td class="p-2 font-mono text-xs">{obligation.capability_id}</td>
              <td class="p-2 font-mono text-xs">{obligation.cause_ref}</td>
              <td class="p-2">
                <span class={state_chip_classes(to_string(obligation.status))}>{obligation.status}</span>
              </td>
            </tr>
            <tr :if={@snap.command_center.obligations == []}>
              <td colspan="4" class="p-4 text-center text-slate-500">
                no obligations — the Chicago projection has not landed yet (R4)
              </td>
            </tr>
          </tbody>
        </table>
      </section>

      <section class="mb-8" data-testid="capabilities">
        <h2 class="text-lg font-semibold mb-2">Capabilities (admitted = receipt-backed)</h2>
        <table class="w-full text-sm border border-slate-200">
          <thead class="bg-slate-50">
            <tr>
              <th class="text-left p-2 border-b border-slate-200">Capability</th>
              <th class="text-left p-2 border-b border-slate-200">Origin</th>
              <th class="text-left p-2 border-b border-slate-200">Executions</th>
              <th class="text-left p-2 border-b border-slate-200">Admitted</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={{capability, index} <- Enum.with_index(@snap.command_center.capabilities)}
              class="border-b border-slate-100"
              data-testid={"capability-row-" <> Integer.to_string(index)}
            >
              <td class="p-2 font-mono text-xs">{capability.id}</td>
              <td class="p-2 font-mono text-xs">{capability.origin}</td>
              <td class="p-2">{capability.executions}</td>
              <td class="p-2">
                <span class={capability.admitted? |> to_string() |> standing_chip_classes()}>
                  {if capability.admitted?, do: "ALIVE", else: "UNKNOWN"}
                </span>
              </td>
            </tr>
            <tr :if={@snap.command_center.capabilities == []}>
              <td colspan="4" class="p-4 text-center text-slate-500">
                no capabilities observed or projected
              </td>
            </tr>
          </tbody>
        </table>
      </section>

      <section class="mb-8" data-testid="plans">
        <h2 class="text-lg font-semibold mb-2">Plans (planning episodes, ceiling :SELECT)</h2>
        <table class="w-full text-sm border border-slate-200">
          <thead class="bg-slate-50">
            <tr>
              <th class="text-left p-2 border-b border-slate-200">Episode</th>
              <th class="text-left p-2 border-b border-slate-200">World state</th>
              <th class="text-left p-2 border-b border-slate-200">Policy standing</th>
              <th class="text-left p-2 border-b border-slate-200">Ceiling</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={episode <- @snap.command_center.planning_episodes}
              class="border-b border-slate-100"
              data-testid={"episode-row-" <> episode.episode_id}
            >
              <td class="p-2 font-mono text-xs">{episode.episode_id}</td>
              <td class="p-2 font-mono text-xs">{episode.world_state_ref}</td>
              <td class="p-2">
                <span class={standing_chip_classes(episode.policy_standing)}>{episode.policy_standing}</span>
              </td>
              <td class="p-2 font-mono text-xs">{episode.authority_ceiling}</td>
            </tr>
            <tr :if={@snap.command_center.planning_episodes == []}>
              <td colspan="4" class="p-4 text-center text-slate-500">no runs — no plans projected</td>
            </tr>
          </tbody>
        </table>
      </section>

      <section class="mb-8" data-testid="executed">
        <h2 class="text-lg font-semibold mb-2">Executed + replayable</h2>
        <table class="w-full text-sm border border-slate-200">
          <thead class="bg-slate-50">
            <tr>
              <th class="text-left p-2 border-b border-slate-200">Execution</th>
              <th class="text-left p-2 border-b border-slate-200">Work order</th>
              <th class="text-left p-2 border-b border-slate-200">Capability</th>
              <th class="text-left p-2 border-b border-slate-200">Replay verified</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={execution <- @snap.executions}
              class="border-b border-slate-100"
              data-testid={"execution-row-" <> execution.id}
            >
              <td class="p-2 font-mono text-xs">{execution.id}</td>
              <td class="p-2 font-mono text-xs">{execution.work_order_id}</td>
              <td class="p-2 font-mono text-xs">{execution.capability}</td>
              <td class="p-2" data-testid={"replay-" <> execution.id}>
                <span class={
                  state_chip_classes(if execution.replay_verified, do: "completed", else: "other")
                }>
                  {execution.replay_verified}
                </span>
              </td>
            </tr>
            <tr :if={@snap.executions == []}>
              <td colspan="4" class="p-4 text-center text-slate-500">
                no SA2A executions recorded — nothing is claimed executed
              </td>
            </tr>
          </tbody>
        </table>
      </section>

      <section class="mb-8" data-testid="refused">
        <h2 class="text-lg font-semibold mb-2">Refused (typed, with reasons)</h2>
        <ul class="space-y-1">
          <li
            :for={refusal <- @snap.refusals}
            class="rounded border border-red-200 bg-red-50 p-2 text-sm"
            data-testid={"refusal-row-" <> refusal.id}
          >
            <span class="font-mono text-xs">{refusal.source}</span>
            — <span data-testid={"refusal-reason-" <> refusal.id}>{refusal.reason}</span>
          </li>
          <li :if={@snap.refusals == []} class="p-2 text-center text-sm text-slate-500">
            no refusals recorded
          </li>
        </ul>
      </section>

      <section class="mb-8" data-testid="unknown">
        <h2 class="text-lg font-semibold mb-2">Unknown (candidate/transport rows, slate)</h2>
        <ul class="space-y-1">
          <li
            :for={{unknown, index} <- Enum.with_index(@snap.unknowns)}
            class="rounded border border-dashed border-slate-400 bg-slate-50 p-2 text-sm text-slate-600"
            data-testid={"unknown-row-" <> Integer.to_string(index)}
          >
            <span class="font-mono text-xs">{unknown.kind}:{unknown.id}</span> — {unknown.reason}
          </li>
          <li :if={@snap.unknowns == []} class="p-2 text-center text-sm text-slate-500">
            nothing unknown — every claim carries a real receipt
          </li>
        </ul>
      </section>

      <section class="mb-8" data-testid="receipts">
        <h2 class="text-lg font-semibold mb-2">Receipts (real sealed rows)</h2>
        <table class="w-full text-sm border border-slate-200">
          <thead class="bg-slate-50">
            <tr>
              <th class="text-left p-2 border-b border-slate-200">Receipt</th>
              <th class="text-left p-2 border-b border-slate-200">Subject</th>
              <th class="text-left p-2 border-b border-slate-200">Outcome</th>
              <th class="text-left p-2 border-b border-slate-200">Reason</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={receipt <- @snap.receipts}
              class="border-b border-slate-100"
              data-testid={"receipt-row-" <> receipt.id}
            >
              <td class="p-2 font-mono text-xs">{receipt.id}</td>
              <td class="p-2 font-mono text-xs">{receipt.subject}</td>
              <td class="p-2">
                <span class={standing_chip_classes(receipt.outcome)}>{receipt.outcome}</span>
              </td>
              <td class="p-2 text-xs">{receipt.reason}</td>
            </tr>
            <tr :if={@snap.receipts == []}>
              <td colspan="4" class="p-4 text-center text-slate-500">
                no receipts sealed for recent epochs — every layer stays UNKNOWN
              </td>
            </tr>
          </tbody>
        </table>
      </section>

      <section class="mb-8" data-testid="ocel">
        <h2 class="text-lg font-semibold mb-2">OCEL evidence (real event log rows)</h2>
        <table class="w-full text-sm border border-slate-200">
          <thead class="bg-slate-50">
            <tr>
              <th class="text-left p-2 border-b border-slate-200">Event type</th>
              <th class="text-left p-2 border-b border-slate-200">OCEL id</th>
              <th class="text-left p-2 border-b border-slate-200">Occurred at</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={event <- @snap.ocel_events}
              class="border-b border-slate-100"
              data-testid={"ocel-row-" <> event.id}
            >
              <td class="p-2 font-mono text-xs">{event.event_type}</td>
              <td class="p-2 font-mono text-xs">{event.ocel_id}</td>
              <td class="p-2 text-slate-500">{event.occurred_at}</td>
            </tr>
            <tr :if={@snap.ocel_events == []}>
              <td colspan="3" class="p-4 text-center text-slate-500">no OCEL events recorded</td>
            </tr>
          </tbody>
        </table>
      </section>

      <section class="mb-8" data-testid="cases">
        <h2 class="text-lg font-semibold mb-2">Cases (candidate predictions — R8)</h2>
        <ul class="space-y-1">
          <li
            :for={kase <- @snap.cases}
            class="rounded border border-slate-200 p-2 text-sm"
            data-testid={"case-row-" <> kase.id}
          >
            <span class="font-semibold">{kase.label}</span>
            <span class={standing_chip_classes(kase.observed_standing)}>{kase.observed_standing}</span>
          </li>
          <li :if={@snap.cases == []} class="p-2 text-center text-sm text-slate-500">
            no cases in the model yet
          </li>
        </ul>
      </section>
    </div>
    """
  end
end
