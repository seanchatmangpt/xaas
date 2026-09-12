defmodule Xaas.Generation.CapabilityRegistry do
  @moduledoc """
  Generator capability registry — the required component naming which
  generator identifiers this repo actually knows about and what artifact
  kinds each one is declared capable of producing.

  Real, bounded scope: this is a static, explicit registry of the
  generator families this repo's own tooling actually documents having
  (`ggen` render targets per `~/ggen-marketplace/packs/xaas-ash-core-pack`,
  and this repo's own hand-authored `Ash.Resource`/`Ash.Reactor` code path
  which is NOT itself a generator). It intentionally does not attempt to
  probe `ggen`, HDDL/PDDL toolchains, or other sibling repos at runtime —
  that would require shelling out to tools this module has no business
  owning. Extending this registry is a deliberate edit, not something
  this module infers.
  """

  @registry %{
    "ggen" => [:ash_resource, :ash_change, :rdf_shacl, :ocel_schema],
    "manual" => []
  }

  @type generator_id :: String.t()
  @type artifact_kind :: atom()

  @spec known_generators() :: [generator_id()]
  def known_generators, do: Map.keys(@registry)

  @spec registered?(generator_id()) :: boolean()
  def registered?(generator_id), do: Map.has_key?(@registry, generator_id)

  @spec supports?(generator_id(), artifact_kind()) :: boolean()
  def supports?(generator_id, artifact_kind) do
    artifact_kind in Map.get(@registry, generator_id, [])
  end

  @spec capabilities(generator_id()) :: [artifact_kind()] | nil
  def capabilities(generator_id), do: Map.get(@registry, generator_id)
end
