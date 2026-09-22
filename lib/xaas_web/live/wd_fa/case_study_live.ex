defmodule XaasWeb.WdFa.CaseStudyLive do
  @moduledoc """
  Browser proof surface for WD Case Study 2.

  No LLM participates in KNOWN/PARTIAL/UNKNOWN classification here. This is
  the deterministic behavioral reference that later generated stacks must
  reproduce.
  """

  use XaasWeb, :live_view

  alias Xaas.CaseStudies.WdFa
  alias Xaas.CaseStudies.WdFa.{CapabilitySelector, EvidenceCatalog, Evaluation, Ingestion, LearningLoop, MorningBrief, ProcessDelta, SemanticWork}
  alias Xaas.CaseStudies.WdFa.Stogaf
  alias Xaas.CaseStudies.WdFa.Stogaf.{ArchitectureChange, AutonomicPlanner}
  alias Xaas.CaseStudies.WdFa.Stogaf.{Conformance, Metrics, Requirements, Viewpoints, WorkGraph}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:selected, "known_firmware")
     |> assign(:experience_admitted, false)
     |> assign(:verification_receipt, nil)
     |> assign(:machine_experience, nil)
     |> assign(:architecture_change, nil)
     |> assign(:morning_brief, MorningBrief.summary())
     |> assign(:ingestion_fixture, Ingestion.ingest_known_fixture())
     |> assign(:evaluation, Evaluation.offline_report())
     |> assign(:process_delta, ProcessDelta.verified_replay_delta())
     |> assign(:semantic_work, SemanticWork.for_case("known_firmware"))
     |> assign(:case_capabilities, CapabilitySelector.for_case("known_firmware"))
     |> assign(:architecture, Stogaf.demo_projection())
     |> assign(:autonomic_next, AutonomicPlanner.next(AutonomicPlanner.initial_standings()))
     |> assign(:requirements, Requirements.all())
     |> assign(:viewpoints, Viewpoints.all())
     |> assign(:conformance, Conformance.all())
     |> assign(:workgraph, WorkGraph.all())
     |> assign(:dfcm_metrics, Metrics.summary())
     |> assign(:state, WdFa.presentation_state("known_firmware"))}
  end

  @impl true
  def handle_event("select_scenario", %{"id" => id}, socket) do
    learned? = id == "novel_x" and socket.assigns.experience_admitted

    {:noreply,
     socket
     |> assign(:selected, id)
     |> assign(:semantic_work, SemanticWork.for_case(id, learned?))
     |> assign(:case_capabilities, CapabilitySelector.for_case(id, learned?))
     |> assign(:state, WdFa.presentation_state(id, learned?))}
  end

  @impl true
  def handle_event("admit_experience", _params, socket) do
    {:ok, %{receipt: receipt, experience: experience}} = LearningLoop.verify_novel_fixture()
    {:ok, architecture_change} = ArchitectureChange.from_experience(experience)

    {:noreply,
     socket
     |> assign(:selected, "novel_x")
     |> assign(:experience_admitted, true)
     |> assign(:verification_receipt, receipt)
     |> assign(:machine_experience, experience)
     |> assign(:architecture_change, architecture_change)
     |> assign(:morning_brief, MorningBrief.summary(true))
     |> assign(:semantic_work, SemanticWork.for_case("novel_x", true))
     |> assign(:case_capabilities, CapabilitySelector.for_case("novel_x", true))
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


      <section class="mb-6 rounded border p-4" data-testid="morning-brief">
        <p class="text-sm font-semibold uppercase tracking-wide">FA Morning Brief</p>
        <h2 class="text-xl font-bold">Start with what needs an engineer</h2>
        <div class="mt-3 grid gap-3 md:grid-cols-3">
          <article class="rounded border p-3">
            <strong>Needs judgment</strong>
            <div data-testid="brief-needs-judgment">{@morning_brief.needs_judgment}</div>
          </article>
          <article class="rounded border p-3">
            <strong>Missing evidence</strong>
            <div data-testid="brief-missing-evidence">{@morning_brief.missing_evidence}</div>
          </article>
          <article class="rounded border p-3">
            <strong>Prior-art ready</strong>
            <div data-testid="brief-prior-art-ready">{@morning_brief.prior_art_ready}</div>
          </article>
        </div>
        <p class="mt-3 text-sm" data-testid="brief-authority-rule">
          {@morning_brief.semantic_rule}
        </p>
      </section>

      <nav class="mb-6 flex gap-3" data-testid="scenario-nav">
        <%= for id <- WdFa.scenario_ids() do %>
          <button
            type="button"
            phx-click="select_scenario"
            phx-value-id={id}
            data-testid={"scenario-" <> id}
            class="rounded border px-3 py-2"
          >
            {id}
          </button>
        <% end %>
      </nav>

      <section class="grid gap-4 md:grid-cols-4">
        <article class="rounded border p-4">
          <h2 class="font-semibold">Classification</h2>
          <div class="mt-2 text-2xl font-bold" data-testid="classification">
            {@state.classification}
          </div>
          <div data-testid="standing">{@state.standing}</div>
        </article>
        <article class="rounded border p-4">
          <h2 class="font-semibold">Admitted mode</h2>
          <div class="mt-2" data-testid="admitted-mode">{@state.admitted_mode || "NONE"}</div>
          <div class="text-sm" data-testid="confidence-basis">{@state.confidence_basis}</div>
        </article>
        <article class="rounded border p-4">
          <h2 class="font-semibold">Next action</h2>
          <div class="mt-2" data-testid="next-action">{@state.next_action}</div>
          <div class="text-sm" data-testid="owning-team">{@state.owning_team}</div>
        </article>
        <article class="rounded border p-4">
          <h2 class="font-semibold">Authority</h2>
          <div class="mt-2" data-testid="authority">{@state.authority}</div>
          <div class="text-sm" data-testid="human-gate">{@state.human_gate}</div>
        </article>
      </section>

      <section class="mt-6 grid gap-6 md:grid-cols-2">
        <article class="rounded border p-4">
          <h2 class="font-semibold">Evidence</h2>
          <ul data-testid="evidence-list">
            <%= for evidence <- @state.evidence do %>
              <% detail = EvidenceCatalog.fetch(evidence) %>
              <li>
                <strong>{evidence}</strong>
                <span> · {detail.modality}</span>
                <span> · {detail.classification}</span>
                <span data-testid={"source-" <> evidence}> · {detail.source_ref}</span>
              </li>
            <% end %>
          </ul>

          <h3 class="mt-4 font-semibold">Representative multimodal ingestion</h3>
          <ul data-testid="ingestion-modalities">
            <%= for artifact <- @ingestion_fixture.artifacts do %>
              <li>
                {artifact.modality} · {artifact.kind} · {artifact.source_ref}
              </li>
            <% end %>
          </ul>

          <h3 class="mt-4 font-semibold">Missing required evidence</h3>
          <ul data-testid="missing-evidence">
            <%= if @state.missing_evidence == [] do %>
              <li>NONE</li>
            <% else %>
              <%= for evidence <- @state.missing_evidence do %>
                <li>{evidence}</li>
              <% end %>
            <% end %>
          </ul>
        </article>

        <article class="rounded border p-4">
          <h2 class="font-semibold">Ranked hypotheses</h2>
          <ol data-testid="hypothesis-list">
            <%= for hypothesis <- @state.ranked_hypotheses do %>
              <li class="mb-3">
                <strong>{hypothesis.mode}</strong>
                <span> score={hypothesis.score}</span>
                <span> · candidate only</span>
              </li>
            <% end %>
          </ol>
          <h3 class="mt-4 font-semibold">Closest admitted prior art</h3>
          <ul data-testid="prior-cases">
            <%= if @state.prior_cases == [] do %>
              <li>NONE</li>
            <% else %>
              <%= for prior <- @state.prior_cases do %>
                <li>{prior}</li>
              <% end %>
            <% end %>
          </ul>
        </article>
      </section>



      <section class="mt-6 grid gap-6 md:grid-cols-2">
        <article class="rounded border p-4" data-testid="semantic-work">
          <h2 class="font-semibold">Semantic work order</h2>
          <p data-testid="work-id">{@semantic_work.id}</p>
          <p data-testid="work-standing">{@semantic_work.standing}</p>
          <p data-testid="work-obligation">{@semantic_work.obligation}</p>
          <p data-testid="work-owner">owner: {@semantic_work.owner}</p>
          <p data-testid="work-authority">{@semantic_work.authority}</p>
        </article>

        <article class="rounded border p-4" data-testid="case-capabilities">
          <h2 class="font-semibold">Selected bounded capabilities</h2>
          <ul>
            <%= for capability <- @case_capabilities do %>
              <li>{capability.plane} · {capability.id} · {capability.intelligence}</li>
            <% end %>
          </ul>
        </article>
      </section>

      <section class="mt-6 rounded border p-4" data-testid="stogaf-architecture">
        <h2 class="font-semibold">STOGAF architecture standing</h2>
        <p>
          TOGAF-compatible semantic execution profile · repository-local evidence ceiling
        </p>
        <div class="mt-3 grid gap-3 md:grid-cols-4">
          <div>
            <strong>Current</strong>
            <div data-testid="stogaf-current">
              {@architecture.current_conformance}
            </div>
          </div>
          <div>
            <strong>Target</strong>
            <div data-testid="stogaf-target">
              {@architecture.target_conformance}
            </div>
          </div>
          <div>
            <strong>ADM</strong>
            <div data-testid="stogaf-adm-phase">
              {@architecture.current_adm_phase} → {@architecture.next_adm_phase}
            </div>
          </div>
          <div>
            <strong>Authority</strong>
            <div data-testid="stogaf-authority">
              {@architecture.authority}
            </div>
          </div>
        </div>


        <div class="mt-6 grid gap-4 md:grid-cols-4" data-testid="stogaf-dfcm">
          <article class="rounded border p-3">
            <strong>Requirements mapped</strong>
            <div data-testid="stogaf-requirements-count">{@dfcm_metrics.requirements_mapped}</div>
          </article>
          <article class="rounded border p-3">
            <strong>Viewpoints</strong>
            <div data-testid="stogaf-viewpoints-count">{@dfcm_metrics.viewpoints}</div>
          </article>
          <article class="rounded border p-3">
            <strong>ST-6 work orders</strong>
            <div data-testid="stogaf-workorders-count">{@dfcm_metrics.work_orders}</div>
          </article>
          <article class="rounded border p-3">
            <strong>Production levels unclaimed</strong>
            <div data-testid="stogaf-unclaimed-count">{@dfcm_metrics.production_levels_unclaimed}</div>
          </article>
        </div>

        <h3 class="mt-4 font-semibold">Requirement coverage</h3>
        <ul data-testid="stogaf-requirements">
          <%= for requirement <- @requirements do %>
            <li>{requirement.id} · {requirement.name} · {requirement.standing}</li>
          <% end %>
        </ul>

        <h3 class="mt-4 font-semibold">Viewpoints</h3>
        <ul data-testid="stogaf-viewpoints">
          <%= for viewpoint <- @viewpoints do %>
            <li>{viewpoint.view} · {viewpoint.concern}</li>
          <% end %>
        </ul>

        <h3 class="mt-4 font-semibold">ST-6 closure work graph</h3>
        <p data-testid="stogaf-workgraph-boundary">
          SJ-011 → SJ-020 · SELECT/CONSTRUCT only
        </p>


        <h3 class="mt-4 font-semibold">Autonomic work selection</h3>
        <%= case @autonomic_next do %>
          <% {:work, work} -> %>
            <p data-testid="autonomic-next">{work.id} · {work.selection_basis}</p>
            <p data-testid="autonomic-intelligence">
              runtime intelligence: {work.runtime_intelligence}
            </p>
          <% {:blocked, ids} -> %>
            <p data-testid="autonomic-next">BLOCKED · {Enum.join(ids, ",")}</p>
          <% :complete -> %>
            <p data-testid="autonomic-next">COMPLETE</p>
        <% end %>

        <h3 class="mt-4 font-semibold">Architecture building blocks</h3>
        <ul data-testid="stogaf-building-blocks">
          <%= for block <- @architecture.building_blocks do %>
            <li>{block}</li>
          <% end %>
        </ul>
      </section>



      <section class="mt-6 rounded border p-4" data-testid="process-delta">
        <h2 class="font-semibold">Verified replay process delta</h2>
        <p data-testid="delta-before">
          before: {@process_delta.before.classification} · {@process_delta.before.work_standing}
        </p>
        <p data-testid="delta-after">
          after: {@process_delta.after.classification} · {@process_delta.after.work_standing}
        </p>
        <p data-testid="delta-retired">
          novel investigation retired: {if @process_delta.novel_investigation_retired, do: "YES", else: "NO"}
        </p>
        <p data-testid="delta-time">production time saved: {@process_delta.production_time_saved}</p>
      </section>

      <section class="mt-6 rounded border p-4" data-testid="offline-evaluation">
        <h2 class="font-semibold">Offline falsification court</h2>
        <p data-testid="evaluation-controls">
          {@evaluation.controls_passed}/{@evaluation.controls_total} controls passed
        </p>
        <p data-testid="evaluation-ceiling">ceiling: {@evaluation.evidence_ceiling}</p>
        <p data-testid="production-mttr">production MTTR: {@evaluation.production_metrics.mttr}</p>
        <ul>
          <%= for control <- @evaluation.controls do %>
            <li>{control.id} · {if control.passed, do: "PASS", else: "FAIL"}</li>
          <% end %>
        </ul>
      </section>

      <section class="mt-6 rounded border p-4" data-testid="learning-loop">
        <h2 class="font-semibold">Standardized learning</h2>
        <p>UNKNOWN → investigation → verified disposition → MachineExperience → future KNOWN</p>
        <%= if @selected == "novel_x" and not @experience_admitted do %>
          <button
            type="button"
            phx-click="admit_experience"
            data-testid="admit-experience"
            class="mt-3 rounded border px-3 py-2"
          >
            Admit verified MachineExperience fixture
          </button>
        <% end %>

        <%= if @verification_receipt do %>
          <div class="mt-4 rounded border p-3" data-testid="verification-receipt">
            <strong>Independent verification receipt</strong>
            <p data-testid="receipt-digest">{@verification_receipt.receipt_digest}</p>
            <p data-testid="receipt-verifier">verifier: {@verification_receipt.verifier_id}</p>
            <p data-testid="receipt-scope">scope: {@verification_receipt.authority_scope}</p>
            <p data-testid="experience-id">experience: {@machine_experience.id}</p>
            <p data-testid="standard-change">
              standard: {@architecture_change.from_standard} → {@architecture_change.to_standard}
            </p>
            <p data-testid="architecture-change-phase">{@architecture_change.adm_phase}</p>
          </div>
        <% end %>
      </section>
    </main>
    """
  end
end
