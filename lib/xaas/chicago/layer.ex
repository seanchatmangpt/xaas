defmodule Xaas.Chicago.Layer do
  @moduledoc """
  Contract layer ids and helpers over machine-projection layers.

  The ten contract slugs below are fixed in resolution R2/R4
  (`docs/sjira/v26.10.1/RESOLUTIONS.md`). They map onto the source graph IRIs
  `chi:layer-*` with the aliases `ex4pm <-> ocel` and `ashsurface <-> surface`.
  The order here is the presentation order for every consumer surface.

  Standing law (R8): a layer's standing comes only from its own machine
  projection `status` field, which is `"UNKNOWN"` until a real receipt binds
  observed execution. No layer's standing is ever derived from another layer.
  """

  @required_ids ~w(sjira graphlaw sa2a pplan xaas ex4pm beam4pm affidavit ashsurface marketplace)a

  # Successor layers ride in the machine projection (12 ids total) but are not
  # required for the Monday surface; presentation order stays the 10 contract ids.
  @successor_ids ~w(wasm4pm castle)a

  @labels %{
    sjira: "Semantic Jira work orders",
    graphlaw: "Graphlaw admission kernel",
    sa2a: "SA2A capability actuation",
    pplan: "Bounded planning (FOND/HTN)",
    xaas: "XaaS execution fabric",
    ex4pm: "Process evidence (ex4pm/OCEL)",
    beam4pm: "BEAM process mining (beam4pm)",
    affidavit: "Affidavit receipt chain",
    ashsurface: "AshSurface projection",
    marketplace: "Marketplace admission",
    wasm4pm: "WASM process mining (wasm4pm)",
    castle: "CASTLE consequence bridge"
  }

  # text keys; `required` is validated as boolean, `evidenceRefs`/`receiptRefs`
  # as string arrays, `status` defaults to UNKNOWN
  @layer_keys ~w(id identifier label repository pathScope boundaryClass authorityCeiling capabilityId evidenceHorizon)

  @type id ::
          unquote(
            Enum.reduce(Enum.reverse(@required_ids), fn id, acc ->
              quote do: unquote(id) | unquote(acc)
            end)
          )

  @spec required_ids :: [id]
  def required_ids, do: @required_ids

  @doc "Successor layer ids present in the render but not required."
  @spec successor_ids :: [atom]
  def successor_ids, do: @successor_ids

  @spec label(id | String.t()) :: String.t()
  def label(id), do: Map.fetch!(@labels, to_id(id))

  @spec known?(term) :: boolean
  def known?(id) when is_binary(id) do
    Enum.any?(@required_ids ++ @successor_ids, fn a -> Atom.to_string(a) == id end)
  end

  def known?(id) when is_atom(id), do: id in (@required_ids ++ @successor_ids)
  def known?(_), do: false

  @doc "Keys a machine-projection layer object must carry (plus optional `status`)."
  @spec required_keys :: [String.t()]
  def required_keys, do: @layer_keys

  @doc "All machine layers in contract order; validated input assumed."
  @spec list(map) :: [map]
  def list(machine) do
    by_id = Map.new(machine["layers"], fn l -> {l["id"], l} end)

    Enum.map(@required_ids, fn id -> Map.fetch!(by_id, Atom.to_string(id)) end)
  end

  @spec fetch(map, id | String.t()) :: {:ok, map} | {:refused, {:chicago_layer_unknown, term}}
  def fetch(machine, id) do
    case Enum.find(machine["layers"], fn l -> l["id"] == to_string_id(id) end) do
      nil -> {:refused, {:chicago_layer_unknown, id}}
      layer -> {:ok, layer}
    end
  end

  @doc "Layer standing from the layer's own status only; defaults to UNKNOWN per R2/R8."
  @spec standing(map) :: String.t()
  def standing(layer), do: Map.get(layer, "status") || "UNKNOWN"

  defp to_string_id(id) when is_atom(id), do: Atom.to_string(id)
  defp to_string_id(id) when is_binary(id), do: id

  defp to_id(id) when is_binary(id), do: String.to_existing_atom(id)
  defp to_id(id) when is_atom(id), do: id
end
