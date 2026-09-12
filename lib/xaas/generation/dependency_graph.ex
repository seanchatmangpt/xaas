defmodule Xaas.Generation.DependencyGraph do
  @moduledoc """
  Source-to-projection dependency graph — the required component naming
  which canonical sources produce which generated projections.

  ## Real scope

  This is computed structurally, in-process, from a real
  `Xaas.Generation.Manifest.t()` — it groups declared entries by
  `source_path` into `source_path => [projection_path]`. No mocking: the
  input is the manifest itself (already real data), and the grouping is
  plain `Enum` work.

  ## Bounded UNSUPPORTED

  This does not derive edges by parsing RDF/SHACL/ggen templates to
  discover *undeclared* dependencies — it only reports what the manifest
  already declares. Discovering dependencies that aren't in the manifest
  yet is a real, separate capability this repo does not have a generic
  implementation for (each generator family — ggen, HDDL, Ash codegen —
  would need its own real parser); callers who hit that gap should use
  `Xaas.Generation.UnsupportedReceipt`.
  """

  alias Xaas.Generation.Manifest

  @type t :: %{String.t() => [String.t()]}

  @spec build(Manifest.t()) :: t()
  def build(entries) do
    entries
    |> Enum.group_by(& &1.source_path, & &1.projection_path)
    |> Map.new(fn {source, projections} -> {source, Enum.sort(projections)} end)
  end

  @doc "All projections reachable from a given source path, or [] if none declared."
  @spec projections_for(t(), String.t()) :: [String.t()]
  def projections_for(graph, source_path), do: Map.get(graph, source_path, [])
end
