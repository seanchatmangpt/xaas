defmodule Xaas.Generation.Manifest do
  @moduledoc """
  Canonical generation manifest — the required component from
  `docs/jira/v26.9.11/deterministic-generation-closure.md` naming the
  declared set of `g(CanonicalGraph) -> Projection` edges this repo
  currently knows about.

  ## Real scope of this module (bounded, honest)

  This is a real, structural manifest: an ordered list of
  `%Xaas.Generation.Manifest.Entry{}` structs, each naming one declared
  source -> projection edge and (optionally) the reason a projection is a
  registered, irreducible handwritten residue rather than a live
  generation target.

  ## What this module does NOT do (explicit, bounded UNSUPPORTED)

  It does not walk this repo's actual canonical RDF/ontology graph (there
  is no generic, repo-wide "canonical graph -> all projections" traversal
  API in this codebase yet — `ggen` packs, HDDL/PDDL definitions, and Ash
  resource generators each have their own, non-unified provenance story).
  Building that traversal for real is out of scope for this slice; entries
  here are declared by the caller (a config list, a test, or a future
  loader), not discovered. See `Xaas.Generation.UnsupportedReceipt` for how
  a caller should report a manifest gap it cannot yet close.
  """

  defmodule Entry do
    @moduledoc "One declared source -> projection generation edge."

    @enforce_keys [:source_path, :projection_path, :generator_id]
    defstruct [:source_path, :projection_path, :generator_id, residue_reason: nil]

    @type t :: %__MODULE__{
            source_path: String.t(),
            projection_path: String.t(),
            generator_id: String.t(),
            residue_reason: String.t() | nil
          }
  end

  @type t :: [Entry.t()]

  @doc """
  Builds a manifest from plain maps (e.g. loaded from config or a test
  fixture). Raises `ArgumentError` on a map missing a required key —
  fail loud on a malformed manifest rather than admit a partial entry.
  """
  @spec load([map()]) :: t()
  def load(raw_entries) when is_list(raw_entries) do
    Enum.map(raw_entries, fn raw ->
      %Entry{
        source_path: Map.fetch!(raw, :source_path),
        projection_path: Map.fetch!(raw, :projection_path),
        generator_id: Map.fetch!(raw, :generator_id),
        residue_reason: Map.get(raw, :residue_reason)
      }
    end)
  end

  @doc "All projection paths declared in the manifest."
  @spec projection_paths(t()) :: [String.t()]
  def projection_paths(entries), do: Enum.map(entries, & &1.projection_path)

  @doc "The entry for a given projection path, if declared."
  @spec find_by_projection(t(), String.t()) :: Entry.t() | nil
  def find_by_projection(entries, projection_path) do
    Enum.find(entries, &(&1.projection_path == projection_path))
  end
end
