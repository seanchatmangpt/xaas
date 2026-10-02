defmodule Xaas.Chicago.EcosystemGraph do
  @moduledoc """
  Truthful, representation-only Chicago demo inventory.

  This module does not reimplement dependency semantics. It reports whether
  the canonical owner is actually loadable in this XaaS runtime and keeps
  authority/standing distinct for AshSurface projection.
  """

  alias Xaas.Chicago.Subject

  @layers [
    %{id: :sjira, capability: :requirement, module: Xaas.SemanticJira, ceiling: :requirement_evidence, provenance: "xaas"},
    %{id: :sa2a, capability: :capability_delegation, module: AshA2A, ceiling: :delegation_evidence, provenance: "ash_a2a@3325032d9dea201e6deb82ef242c534aacb3b420"},
    %{id: :pplan, capability: :fond_plan, module: AshPPlan, ceiling: :plan_evidence, provenance: "ash_pplan@b9da1ad7590d70afac5eace3bd7ba1a644f7249f"},
    %{id: :graphlaw, capability: :admission_refusal, module: AshGraphlaw, ceiling: :decision_evidence, provenance: "ash_graphlaw dev/test path dependency"},
    %{id: :xaas, capability: :run_state, module: Xaas, ceiling: :runtime_observation, provenance: "xaas"},
    %{id: :ex4pm, capability: :ocel_evidence, module: Ex4pm.OCEL, ceiling: :process_evidence, provenance: "ex4pm@17e7761ffff482ff1b2ec936ad9705a99356451a"},
    %{id: :affidavit, capability: :standing_evidence, module: AshAffidavit, ceiling: :standing_evidence, provenance: "ash_affidavit dev/test path dependency"}
  ]

  def snapshot do
    Enum.map(@layers, &observe/1)
  end

  defp observe(layer) do
    loaded? = Code.ensure_loaded?(layer.module)

    %{
      subject: Subject.id(),
      layer: layer.id,
      capability: layer.capability,
      state: if(loaded?, do: :available, else: :unsupported),
      evidence_ref: if(loaded?, do: {:module, layer.module}, else: nil),
      receipt_ref: nil,
      authority_ceiling: layer.ceiling,
      standing: if(loaded?, do: :observed, else: :unqualified),
      provenance: layer.provenance
    }
  end
end
