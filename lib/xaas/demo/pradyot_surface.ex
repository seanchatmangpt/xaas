defmodule Xaas.Demo.PradyotSurface do
  @moduledoc """
  Read-only projection model for the Pradyot demo.

  The contained Chicago seed is evidence for surface behavior, not runtime
  authority or a claim that unavailable ecosystem services executed.
  """
  @subject "urn:chicago:agentic-payment:purchase-001"

  @layers [
    {:sjira, "Requirement", :contained, "Agentic payment requirement admitted for the demo episode."},
    {:graphlaw, "GraphLaw", :partial, "Admission evidence is projected; live engine evidence is not required by the contained seed."},
    {:sa2a, "SA2A", :contained, "Capability/delegation projection; no DO authority is created by this UI."},
    {:ash_pplan, "ash_pplan / ferroplan", :contained, "Plan candidate and realization boundary are visible."},
    {:realization, "Realization", :contained, "Executable realization identity is represented separately from authority."},
    {:xaas, "XaaS", :contained, "Demo run projection; consequential execution remains behind XaaS/BRCE."},
    {:ex4pm, "ex4pm / OCEL", :partial, "Evidence slot is typed partial when no live OCEL event is available."},
    {:beam4pm, "beam4pm", :unsupported, "Conformance/replay is visible as unsupported until evidence is attached."},
    {:affidavit, "Affidavit", :partial, "Evidence boundary is present; contained seed does not fabricate an affidavit."},
    {:ash_surface, "AshSurface", :contained, "Read-only standing projection for this exact subject."}
  ]

  def subject, do: @subject

  def chicago do
    %{
      subject: @subject,
      mode: :contained_demo,
      outcome: "Show how one Agentic Payments requirement remains the same subject across the ecosystem.",
      authority: :none,
      standing: :partial,
      freshness: :seeded,
      layers: Enum.map(@layers, &layer/1),
      receipts: [%{id: "demo-seed", state: :contained, replay: :deterministic}],
      cases: demo_cases()
    }
  end

  def system do
    %{
      subject: "xaas/system",
      mode: :live_projection,
      authority: :none,
      exists: ["XaaS", "Phoenix/LiveView", "Ash resources", "execution fabric"],
      running: runtime_state(),
      capabilities: ["read semantic state", "render exact subjects", "render typed evidence gaps"],
      obligations: ["preserve exact subject identity", "never infer runtime authority from UI standing"],
      candidates: ["attach live OCEL evidence", "attach Affidavit evidence", "project planner realization"],
      execution: %{mode: :read_only, unknown_after_dispatch: :reconcile_never_replay},
      receipts: [],
      evidence: %{ocel: :partial, affidavit: :partial},
      standing: :partial,
      replay: %{freshness: :runtime_observed}
    }
  end

  def seller do
    episode = chicago()

    %{
      subject: episode.subject,
      customer_problem: "Agentic payments span requirements, policy, delegation, planning, execution and evidence without one legible subject view.",
      desired_outcome: "Trace one payment outcome from requirement to replayable evidence without moving authority into the presentation layer.",
      capabilities: Enum.map(episode.layers, & &1.label),
      proposed_path: "Requirement -> admission -> delegation -> plan -> realization -> run -> OCEL -> conformance -> evidence -> standing",
      evidence_now: Enum.filter(episode.layers, &(&1.state in [:contained, :partial])),
      boundaries: %{ui_authority: :none, consequential_do: "XaaS/BRCE only"},
      demonstrated: "Deterministic contained projection with typed evidence states.",
      hypothetical: "Live external layers remain partial/unsupported until exact evidence is attached.",
      delivery_status: :demo_ready_surface
    }
  end

  defp demo_cases do
    [
      %{id: "CHI-CASE-001", outcome: :admitted, do: :bounded},
      %{id: "CHI-CASE-002", outcome: :refused, reason: :amount_exceeds_delegated_limit, do: :none},
      %{id: "CHI-CASE-003", outcome: :refused, reason: :wrong_principal, do: :none},
      %{id: "CHI-CASE-004", outcome: :refused, reason: :expired_delegation, do: :none},
      %{id: "CHI-CASE-006", outcome: :unknown_after_dispatch, recovery: :reconcile_original, replay: :forbidden}
    ]
  end

  defp layer({id, label, state, evidence}),
    do: %{id: id, label: label, state: state, evidence: evidence, subject: @subject}

  defp runtime_state do
    %{
      node: Atom.to_string(Node.self()),
      otp_release: List.to_string(:erlang.system_info(:otp_release)),
      applications: Application.started_applications() |> Enum.map(&elem(&1, 0)) |> Enum.sort()
    }
  end
end
