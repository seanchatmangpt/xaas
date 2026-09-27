defmodule XaaS.CS2.EngineerWorkflow do
  alias XaaS.CS2.GeneratedFleetContract, as: Contract

  def from_a2a(%{upstream: upstream}) do
    %{
      schema: "https://chatman.ai/cs2/engineer-workflow/v1",
      subject: Contract.subject(),
      authority_ceiling: Contract.authority_ceiling(),
      consumer: Contract.consumer(),
      work_id: Contract.work_id(),
      source: %{
        consumer: get(upstream, :consumer),
        work_id: get(upstream, :work_id),
        packet_id: get(upstream, :packet_id),
        provenance: get(upstream, :provenance)
      },
      evidence: list(upstream, :evidence),
      triage: map(upstream, :triage),
      actions: []
    }
  end

  def add_construct_candidate(workflow, candidate) when is_map(candidate) do
    update_in(workflow.actions, &(&1 ++ [Map.put(candidate, :authority, "CONSTRUCT")]))
  end

  defp list(v, k), do: case get(v, k) do x when is_list(x) -> x; _ -> [] end
  defp map(v, k), do: case get(v, k) do x when is_map(x) -> x; _ -> %{} end
  defp get(v, k), do: Map.get(v, k) || Map.get(v, Atom.to_string(k))
end
