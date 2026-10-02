defmodule Xaas.Chicago.EcosystemGraph do
  @moduledoc "Chicago demo capability projection; availability never implies authority."
  alias Xaas.Chicago.Subject

  @layers [
    %{id: :sjira, capability: :requirement, module: Xaas.SemanticJira, probes: [], ceiling: :requirement_evidence, provenance: "xaas"},
    %{id: :sa2a, capability: :capability_delegation, module: AshA2A, probes: [], ceiling: :delegation_evidence, provenance: "ash_a2a@3325032d9dea201e6deb82ef242c534aacb3b420"},
    %{id: :pplan, capability: :fond_plan, module: AshPPlan, probes: [], ceiling: :plan_evidence, provenance: "ash_pplan@b9da1ad7590d70afac5eace3bd7ba1a644f7249f"},
    %{id: :graphlaw, capability: :admission_refusal, module: AshGraphlaw, probes: [], ceiling: :decision_evidence, provenance: "ash_graphlaw dev/test path dependency"},
    %{id: :xaas, capability: :run_state, module: Xaas, probes: [], ceiling: :runtime_observation, provenance: "xaas"},
    %{id: :ex4pm, capability: :ocel_evidence, module: Ex4pm.OCEL, probes: [{:validate_envelope, 1}], ceiling: :process_evidence, provenance: "ex4pm@17e7761ffff482ff1b2ec936ad9705a99356451a"},
    %{id: :affidavit, capability: :standing_evidence, module: AshAffidavit, probes: [], ceiling: :standing_evidence, provenance: "ash_affidavit dev/test path dependency"}
  ]

  def snapshot, do: Enum.map(@layers, &observe/1)

  # This is deliberately structural. XaaS observes owner contracts; it does not
  # invoke a foreign capability merely to make the demo graph look ALIVE.
  defp observe(layer) do
    loaded = Code.ensure_loaded?(layer.module)
    exports = if loaded, do: layer.module.__info__(:functions), else: []
    expected = Map.get(layer, :probes, [])
    missing = expected -- exports

    %{
      subject: Subject.id(),
      layer: layer.id,
      capability: layer.capability,
      state: state(loaded, expected, missing),
      evidence_ref: evidence(loaded, layer.module, expected, missing),
      receipt_ref: nil,
      authority_ceiling: layer.ceiling,
      standing: standing(loaded, expected, missing),
      provenance: layer.provenance
    }
  end

  defp state(false, _, _), do: :unsupported
  defp state(true, [], _), do: :available_unqualified
  defp state(true, _, []), do: :callable
  defp state(true, _, _), do: :contract_drift

  defp standing(false, _, _), do: :unqualified
  defp standing(true, [], _), do: :observed_module_only
  defp standing(true, _, []), do: :observed_callable
  defp standing(true, _, _), do: :refused_contract_drift

  defp evidence(false, _, _, _), do: nil
  defp evidence(true, module, [], _), do: %{module: module, exports_observed: module.__info__(:functions)}
  defp evidence(true, module, expected, []), do: %{module: module, callable: expected}
  defp evidence(true, module, expected, missing), do: %{module: module, expected: expected, missing: missing}
end
