defmodule Xaas.Ultracode.CapabilityResolver.Receipt do
  @moduledoc """
  The resolution receipt of the Ultracode capability-resolution court
  (`Xaas.Ultracode.CapabilityResolver`): the durable per-item record that
  the fleet's capability closure either already satisfies a sensed item
  (`:reuse`/`:compose`/`:extend`/`:generate`) or provably cannot
  (`:frontier`), or that the court could not lawfully decide (`:unresolved`).

  Plain struct + NDJSON persistence (one JSON object per line), NOT a new
  Ash resource: this receipt is produced and consumed inside one wave's
  run directory (`capability-resolutions.ndjson`, written BEFORE any
  worker may claim the item), the same plain-file evidence convention the
  loop's `ledger.ndjson` and `receipt.json` already use. It mirrors the
  vocabulary of the fabric's standing receipts (`Xaas.Ultracode.Receipt`:
  standing is recorded, never asserted) without reusing the Ash resource
  -- a resolution is not an epoch outcome and must not pollute the
  terminal-receipt invariant (`terminal epoch => receipt`).

  The standing FALSIFIER is carried verbatim on every receipt: an
  already-qualified capability or lawful composition satisfying this
  item's residual requirements refutes this receipt. A `:frontier`
  receipt for which any later reader can name one satisfying capability
  in the closure is thereby falsifiable by construction -- and the court
  itself proves the flip the other way (injecting one satisfying
  capability into a source must flip the item `:frontier -> :reuse`;
  `capability_resolver_test.exs` witnesses it).
  """

  @classes [:reuse, :compose, :extend, :generate, :frontier, :unresolved]

  @enforce_keys [:item_id, :class, :sources_queried, :falsifier, :resolved_at]

  defstruct [
    :item_id,
    :repo,
    :required_capabilities,
    :candidate_capabilities,
    :selected_capabilities,
    :class,
    :residual_requirements,
    :sources_queried,
    :falsifier,
    :resolved_at
  ]

  @type class :: :reuse | :compose | :extend | :generate | :frontier | :unresolved

  @type candidate :: %{
          required(:capability_id) => String.t(),
          required(:satisfies) => [String.t()],
          required(:source) => String.t()
        }

  @type source_status :: %{required(:status) => :ok | :error | :skipped, optional(:detail) => term()}

  @type t :: %__MODULE__{
          item_id: String.t() | nil,
          repo: String.t() | nil,
          required_capabilities: [String.t()],
          candidate_capabilities: [candidate()],
          selected_capabilities: [String.t()],
          class: class(),
          residual_requirements: [String.t()] | nil,
          sources_queried: %{String.t() => source_status()},
          falsifier: String.t(),
          resolved_at: DateTime.t()
        }

  @doc "The receipt class vocabulary."
  @spec classes() :: [class(), ...]
  def classes, do: @classes

  @doc "The standing falsifier, carried verbatim on every receipt."
  @spec falsifier() :: String.t()
  def falsifier,
    do:
      "an already-qualified capability or lawful composition satisfying this " <>
        "residual refutes this receipt"

  @doc """
  Builds one receipt from a keyword list. `residual_requirements` is
  populated only for `:frontier`/`:extend`/`:unresolved` (the requirements
  the closure did not witness); `nil` (not `[]`) for the satisfied
  classes, so absence of a residual is distinguishable from an empty one.
  """
  @spec new(keyword()) :: t()
  def new(fields) when is_list(fields) do
    class = Keyword.fetch!(fields, :class)
    residual = Keyword.get(fields, :residual_requirements)

    residual =
      cond do
        class in [:frontier, :unresolved, :extend] -> residual || []
        true -> nil
      end

    %__MODULE__{
      item_id: Keyword.get(fields, :item_id),
      repo: Keyword.get(fields, :repo),
      required_capabilities: Keyword.get(fields, :required_capabilities) || [],
      candidate_capabilities: Keyword.get(fields, :candidate_capabilities) || [],
      selected_capabilities: Keyword.get(fields, :selected_capabilities) || [],
      class: class,
      residual_requirements: residual,
      sources_queried: Keyword.get(fields, :sources_queried) || %{},
      falsifier: falsifier(),
      resolved_at: Keyword.get(fields, :resolved_at) || DateTime.utc_now()
    }
  end

  @doc "The JSON-safe projection persisted as one NDJSON line."
  @spec to_json_map(t()) :: map()
  def to_json_map(%__MODULE__{} = receipt) do
    %{
      "schema" => "xaas.capability-resolution-receipt/1",
      "item_id" => receipt.item_id,
      "repo" => receipt.repo,
      "required_capabilities" => receipt.required_capabilities,
      "candidate_capabilities" =>
        Enum.map(receipt.candidate_capabilities, fn candidate ->
          %{
            "capability_id" => candidate.capability_id,
            "satisfies" => candidate.satisfies,
            "source" => candidate.source
          }
        end),
      "selected_capabilities" => receipt.selected_capabilities,
      "class" => Atom.to_string(receipt.class),
      "residual_requirements" => receipt.residual_requirements,
      "sources_queried" =>
        Map.new(receipt.sources_queried, fn {name, status} ->
          {name, %{"status" => Atom.to_string(status.status), "detail" => inspect(status[:detail])}}
        end),
      "falsifier" => receipt.falsifier,
      "resolved_at" => DateTime.to_iso8601(receipt.resolved_at)
    }
  end

  @doc """
  Persists receipts as NDJSON (one JSON object per line) at `path`. Called
  by the loop BEFORE the dispatch stage -- no worker can claim an item
  whose resolution receipt is not already on disk.
  """
  @spec persist([t()], String.t()) :: :ok
  def persist(receipts, path) when is_list(receipts) and is_binary(path) do
    lines = Enum.map(receipts, &(Jason.encode!(to_json_map(&1)) <> "\n"))
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, lines)
    :ok
  end
end
