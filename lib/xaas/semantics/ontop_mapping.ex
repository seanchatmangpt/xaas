defmodule Xaas.Semantics.OntopMapping do
  @moduledoc """
  Renders the real, admitted `Xaas.Semantics.Registry` R2RML mapping for every
  `Xaas.Resource` module into a real W3C R2RML Turtle document via the published
  `AshR2RML.R2RML` renderer.

  This closes the gap between the two previously-disconnected surfaces:
  `Xaas.Semantics.Registry.r2rml_mapping/1` (the in-memory `AshR2RML.Mapping.Resource`
  IR, already delegated to `AshR2RML.Introspection`/`AshR2RML.Mapping`) and
  `priv/ontop/xaas-mapping.ttl` (the file the real Ontop container actually reads,
  previously hand-written and never regenerated from that IR). Nothing here hand-rolls
  R2RML serialization -- rendering is delegated entirely to `AshR2RML.R2RML.render/1`.

  Per this repo's "generated vs authoritative surfaces" rule, the output of `render!/1`
  is a generated artifact -- never hand-edit `priv/ontop/xaas-mapping.generated.ttl`.
  """

  alias AshR2RML.Mapping.Bundle

  @domains [
    Xaas.Accounts,
    Xaas.Billing,
    Xaas.Governance,
    Xaas.Ledger,
    Xaas.Marketplace,
    Xaas.Operations,
    Xaas.Platform
  ]

  @doc "Every `Xaas.Resource` module reachable from an admitted `Xaas.*` Ash domain."
  @spec resources() :: [module()]
  def resources do
    @domains
    |> Enum.flat_map(&Ash.Domain.Info.resources/1)
    |> Enum.filter(&xaas_resource?/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Builds the real `AshR2RML.Mapping.Bundle` of every admitted resource's R2RML mapping.

  A resource whose `Xaas.Semantics.Registry.r2rml_mapping/1` call errors (e.g. no
  logical table resolvable, or an ash_r2rml refusal) is excluded and returned as a
  `{resource, reason}` pair in the second element of the tuple -- generation never
  silently drops a resource's failure into an incomplete-but-successful bundle.
  """
  @spec bundle() :: {Bundle.t(), [{module(), term()}]}
  def bundle do
    {mappings, failures} =
      resources()
      |> Enum.map(&{&1, Xaas.Semantics.Registry.r2rml_mapping(&1)})
      |> Enum.split_with(fn {_resource, result} -> match?({:ok, _}, result) end)

    resource_mappings = Enum.map(mappings, fn {_resource, {:ok, mapping}} -> mapping end)
    failure_pairs = Enum.map(failures, fn {resource, {:error, reason}} -> {resource, reason} end)

    {%Bundle{resources: resource_mappings}, failure_pairs}
  end

  @doc """
  Renders the real bundle to W3C R2RML Turtle via `AshR2RML.R2RML.render/1`.

  Returns `{:ok, turtle, failures}` where `failures` names any resource excluded from
  the bundle (see `bundle/0`) -- callers decide whether a non-empty `failures` list is
  acceptable for their use (the mix task below fails closed).
  """
  @spec render() :: {:ok, String.t(), [{module(), term()}]} | {:error, term()}
  def render do
    {bundle, failures} = bundle()

    case AshR2RML.R2RML.render(bundle) do
      {:ok, turtle} -> {:ok, turtle, failures}
      {:error, reason} -> {:error, reason}
    end
  end

  @generated_path "priv/ontop/xaas-mapping.generated.ttl"

  @doc "Absolute path to the generated (never hand-edited) R2RML mapping file."
  @spec generated_path() :: String.t()
  def generated_path, do: Path.join(:code.priv_dir(:kanban), "ontop/xaas-mapping.generated.ttl")

  @doc """
  Renders the real bundle and writes it to `#{@generated_path}` via
  `GgenIgniter.Actuate.write_file!/3` -- the real, hash-based write-safety guard from
  `~/ggen_igniter` (path dep, see `mix.exs`): a byte-identical rewrite is a genuine
  `:unchanged` no-op (no mtime churn, no spurious `ggen sync`/git diff on an unchanged
  ontology), rather than this module hand-rolling that idempotency check itself.

  Fails closed: any resource that could not be mapped (see `bundle/0`) causes this to
  return `{:error, {:unmapped_resources, failures}}` rather than writing a silently
  incomplete file.
  """
  @spec write!() :: {:ok, String.t(), GgenIgniter.Actuate.outcome()} | {:error, term()}
  def write! do
    case render() do
      {:ok, _turtle, [_ | _] = failures} ->
        {:error, {:unmapped_resources, failures}}

      {:ok, turtle, []} ->
        path = generated_path()
        {:ok, outcome} = GgenIgniter.Actuate.write_file!(path, turtle)
        {:ok, path, outcome}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp xaas_resource?(resource) do
    Code.ensure_loaded?(resource) and function_exported?(resource, :ontology_projection, 0)
  end
end
