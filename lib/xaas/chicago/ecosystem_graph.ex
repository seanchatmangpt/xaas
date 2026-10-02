defmodule Xaas.Chicago.EcosystemGraph do
  @moduledoc "Chicago demo capability projection; availability never implies authority."
  alias Xaas.Chicago.Subject
  @layers [
    %{id: :sjira, capability: :requirement, module: Xaas.SemanticJira, probe: nil, ceiling: :requirement_evidence, provenance: "xaas"},
    %{id: :sa2a, capability: :capability_delegation, module: AshA2A, probe: nil, ceiling: :delegation_evidence, provenance: "ash_a2a@3325032d9dea201e6deb82ef242c534aacb3b420"},
    %{id: :pplan, capability: :fond_plan, module: AshPPlan, probe: nil, ceiling: :plan_evidence, provenance: "ash_pplan@b9da1ad7590d70afac5eace3bd7ba1a644f7249f"},
    %{id: :graphlaw, capability: :admission_refusal, module: AshGraphlaw, probe: nil, ceiling: :decision_evidence, provenance: "ash_graphlaw dev/test path dependency"},
    %{id: :xaas, capability: :run_state, module: Xaas, probe: nil, ceiling: :runtime_observation, provenance: "xaas"},
    %{id: :ex4pm, capability: :ocel_evidence, module: Ex4pm.OCEL, probe: {:validate_envelope, 1}, ceiling: :process_evidence, provenance: "ex4pm@17e7761ffff482ff1b2ec936ad9705a99356451a"},
    %{id: :affidavit, capability: :standing_evidence, module: AshAffidavit, probe: nil, ceiling: :standing_evidence, provenance: "ash_affidavit dev/test path dependency"}
  ]
  def snapshot, do: Enum.map(@layers, &observe/1)
  defp observe(layer) do
    loaded = Code.ensure_loaded?(layer.module)
    callable = loaded and match?({name, arity} when is_atom(name) and is_integer(arity), layer.probe) and
      (case layer.probe do {name, arity} -> function_exported?(layer.module, name, arity); _ -> false end)
    %{
      subject: Subject.id(), layer: layer.id, capability: layer.capability,
      state: state(loaded, callable, layer.probe),
      evidence_ref: evidence(loaded, callable, layer.module, layer.probe),
      receipt_ref: nil, authority_ceiling: layer.ceiling,
      standing: standing(loaded, callable, layer.probe), provenance: layer.provenance
    }
  end
  defp state(false, _, _), do: :unsupported
  defp state(true, true, _), do: :callable
  defp state(true, false, nil), do: :available_unqualified
  defp state(true, false, _), do: :contract_drift
  defp standing(false, _, _), do: :unqualified
  defp standing(true, true, _), do: :observed_callable
  defp standing(true, false, nil), do: :observed_module_only
  defp standing(true, false, _), do: :refused_contract_drift
  defp evidence(false, _, _, _), do: nil
  defp evidence(true, true, module, {name, arity}), do: {:function, module, name, arity}
  defp evidence(true, false, module, _), do: {:module, module}
end
