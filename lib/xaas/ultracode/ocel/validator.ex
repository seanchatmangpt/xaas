defmodule Xaas.Ultracode.Ocel.Validator do
  @moduledoc """
  OCEL 2.0 conformance court for ultracode run results: decides, mechanically,
  whether a decoded OCEL 2.0 event log is conformant. Spec-derived, not
  emitter-derived — if an emitter's output diverges from the spec, this court
  stays authoritative and the emitter is wrong.

  Pure module: no Ash, no repo, no application config, no dependencies. Files
  are decoded with Elixir's built-in `JSON` module (`validate_file/1` calls
  `JSON.decode/1` first, then `validate/1`).

  ## The enforced law

    * Required top-level keys: `"ocel:objectTypes"`, `"ocel:eventTypes"`,
      `"ocel:events"`, `"ocel:objects"`. A log with zero events is valid ONLY
      if `"ocel:events"` is explicitly `[]` — absence is a missing-key
      violation, never an implicit empty list.
    * Every event: unique non-empty string `"id"`, `"type"` declared in
      `ocel:eventTypes`, `"time"` parseable ISO8601 with zero UTC offset
      (via `DateTime.from_iso8601/1`), `"attributes"` a JSON object;
      optional `"relationships"` list.
    * Every object: unique non-empty string `"id"`, `"type"` declared in
      `ocel:objectTypes`, `"attributes"` object; same optional
      `"relationships"` law.
    * Each relationship: exactly `{objectId, qualifier}` (both strings), with
      `objectId` resolving to an existing object id.
    * Extra keys: reject. Closed vocabulary at the top level and at every
      structural level (event, object, relationship, type declaration). The
      ONLY open surface is attribute VALUES (and only those).

  ## Court decisions where the letter of the spec needed one mechanical rule

    * Type declarations (`ocel:eventTypes`, `ocel:objectTypes` elements):
      a non-empty string declares itself, or an object with exactly one key
      `"name"` whose value is a non-empty string declares that name. Anything
      else is a malformed declaration.
    * Uniqueness is per collection (events among events, objects among
      objects) — the spec letter constrains each collection's ids separately;
      cross-collision is not a named violation class and none is invented.
    * `"qualifier"` must be present and a string; the spec letter names no
      emptiness law for it, and none is invented.
    * Non-cascading: when a structural parent is itself broken (a required
      collection missing or not an array, a type-declaration element
      malformed), checks that depend on that parent are INADMISSIBLE and are
      skipped — the corruption itself is the one violation. A court that
      piles knock-on violations on top of the real defect fails logs for the
      wrong reason.
    * Fail-closed on malformed JSON, unreadable files, non-object top level,
      wrong types everywhere, duplicate ids, dangling relationships,
      undeclared types, non-ISO8601/non-UTC times.

  ## Result

  `{:ok, report}` with a string-keyed JSON-safe summary map, or
  `{:error, violations}` where each violation is `%{path: ..., reason: ...}`
  naming the exact JSON path, e.g.

      %{path: "ocel:events[3].type",
        reason: "'worker_launched' not declared in ocel:eventTypes"}

  Keys must be strings (the shape produced by JSON decoding); an atom-keyed
  map fails closed as missing/extra keys rather than being coerced.
  """

  @typedoc "One conformance violation: exact JSON path + reason."
  @type violation :: %{path: String.t(), reason: String.t()}

  @typedoc """
  JSON-safe summary of a valid log. Concrete string keys (Elixir 1.20
  typespecs reject binary literal map keys, so the shape is spelled out here):
  `"status"` => `"valid"`, `"event_count"` / `"object_count"` =>
  non-negative integers, `"event_types"` / `"object_types"` => sorted
  declared name lists.
  """
  @type report :: %{
          required(binary()) => String.t() | non_neg_integer() | [String.t()]
        }

  @type registry :: MapSet.t(String.t()) | :unknown

  @required_top_level ~w(ocel:objectTypes ocel:eventTypes ocel:events ocel:objects)
  @event_keys ~w(id type time attributes relationships)
  @event_required ~w(id type time attributes)
  @object_keys ~w(id type attributes relationships)
  @object_required ~w(id type attributes)
  @relationship_required ~w(objectId qualifier)
  @relationship_keys_mapset MapSet.new(~w(objectId qualifier))

  # -- public API -----------------------------------------------------------

  @doc """
  Validates an already-decoded OCEL 2.0 log (string keys, the shape produced
  by the built-in JSON decoder). Fail-closed on any non-map input.
  """
  @spec validate(term()) :: {:ok, report()} | {:error, [violation()]}
  def validate(log) when is_map(log) do
    object_registry = type_registry(log, "ocel:objectTypes")
    event_registry = type_registry(log, "ocel:eventTypes")
    object_ids = object_id_registry(log)

    violations =
      top_level(log) ++
        type_declarations(log, "ocel:objectTypes") ++
        type_declarations(log, "ocel:eventTypes") ++
        entities(log, "ocel:objects", :object, object_registry, object_ids) ++
        entities(log, "ocel:events", :event, event_registry, object_ids)

    # ++ chains keep document order: top level, type declarations, objects,
    # events; within each, path order. No reversal needed.
    case violations do
      [] -> {:ok, report(log, event_registry, object_registry)}
      violations -> {:error, violations}
    end
  end

  def validate(other),
    do:
      {:error, [%{path: "$", reason: "top level must be a JSON object, got: #{inspect(other)}"}]}

  @doc """
  Reads `path`, decodes it with the built-in `JSON` module, then `validate/1`.
  Fail-closed on unreadable files and malformed JSON (each is exactly one
  violation at path `"$"`).
  """
  @spec validate_file(term()) :: {:ok, report()} | {:error, [violation()]}
  def validate_file(path) when is_binary(path) do
    with {:read, {:ok, body}} <- {:read, File.read(path)},
         {:decode, {:ok, decoded}} <- {:decode, JSON.decode(body)} do
      validate(decoded)
    else
      {:read, {:error, reason}} ->
        {:error, [%{path: "$", reason: "cannot read file: #{:file.format_error(reason)}"}]}

      {:decode, {:error, decode_error}} ->
        {:error, [%{path: "$", reason: "malformed JSON: #{decode_reason(decode_error)}"}]}
    end
  end

  def validate_file(path),
    do: {:error, [%{path: "$", reason: "path must be a string, got: #{inspect(path)}"}]}

  # Elixir's built-in JSON.decode/1 fails closed with a %JSON.DecodeError{}
  # struct for syntax errors but a bare reason tuple for byte-level errors
  # (e.g. {:invalid_byte, 18, 111}); both are malformed JSON.
  defp decode_reason(error) when is_struct(error), do: Exception.message(error)
  defp decode_reason(other), do: inspect(other)

  # -- top level ------------------------------------------------------------

  defp top_level(log) do
    missing =
      for key <- @required_top_level, not Map.has_key?(log, key) do
        %{path: key, reason: "missing required top-level key"}
      end

    extras =
      log
      |> Map.keys()
      |> MapSet.new()
      |> MapSet.difference(MapSet.new(@required_top_level))
      |> MapSet.to_list()
      |> Enum.sort()
      |> Enum.map(fn key ->
        %{path: key, reason: "unexpected top-level key (closed vocabulary)"}
      end)

    missing ++ extras
  end

  # -- type declarations ----------------------------------------------------

  # The set of declared names, or :unknown when the registry itself is
  # inadmissible (missing — already flagged at top level, not an array, or
  # containing a malformed declaration element). :unknown silences the
  # downstream undeclared-type checks for this run: a corrupt registry cannot
  # adjudicate declarations, and knock-on violations would fail logs for the
  # wrong reason (non-cascading court discipline).
  @spec type_registry(map(), String.t()) :: registry()
  defp type_registry(log, key) do
    case Map.fetch(log, key) do
      {:ok, decls} when is_list(decls) ->
        {status, names} =
          Enum.reduce(decls, {:ok, []}, fn decl, {status, acc} ->
            case decl_name(decl) do
              {:ok, name} -> {status, [name | acc]}
              :error -> {:corrupt, acc}
            end
          end)

        if status == :ok, do: MapSet.new(names), else: :unknown

      _ ->
        :unknown
    end
  end

  defp type_declarations(log, key) do
    case Map.fetch(log, key) do
      {:ok, decls} when is_list(decls) ->
        decls
        |> Enum.with_index()
        |> Enum.reduce([], fn {decl, i}, acc ->
          case decl_name(decl) do
            {:ok, _name} -> acc
            :error -> [malformed_decl_violation(decl, "#{key}[#{i}]") | acc]
          end
        end)
        |> Enum.reverse()

      {:ok, other} ->
        [%{path: key, reason: "must be an array of type declarations, got: #{inspect(other)}"}]

      :error ->
        # Missing key already flagged at the top level.
        []
    end
  end

  defp decl_name(decl) when is_binary(decl), do: if(decl == "", do: :error, else: {:ok, decl})
  defp decl_name(%{"name" => name} = decl) when map_size(decl) == 1, do: decl_name(name)
  defp decl_name(_), do: :error

  defp malformed_decl_violation(decl, path) do
    %{
      path: path,
      reason:
        "malformed type declaration #{inspect(decl)}: must be a non-empty string " <>
          "or an object with exactly one key \"name\" whose value is a non-empty string"
    }
  end

  # -- objects / events -----------------------------------------------------

  # The set of object ids relationships may resolve against, or :unknown when
  # ocel:objects is missing (already flagged) or not an array — in which case
  # dangling-relationship checks are inadmissible for this run.
  @spec object_id_registry(map()) :: registry()
  defp object_id_registry(log) do
    case Map.fetch(log, "ocel:objects") do
      {:ok, objects} when is_list(objects) ->
        objects
        |> Enum.reduce(MapSet.new(), fn
          %{"id" => id}, acc when is_binary(id) -> MapSet.put(acc, id)
          _, acc -> acc
        end)

      _ ->
        :unknown
    end
  end

  defp entities(log, key, kind, type_registry, object_ids) do
    case Map.fetch(log, key) do
      {:ok, items} when is_list(items) ->
        {_, violation_groups} =
          Enum.reduce(Enum.with_index(items), {MapSet.new(), []}, fn {item, i}, {seen, acc} ->
            {seen, viols} =
              check_entity(item, "#{key}[#{i}]", kind, type_registry, object_ids, seen)

            {seen, [viols | acc]}
          end)

        violation_groups |> Enum.reverse() |> List.flatten()

      {:ok, other} ->
        [%{path: key, reason: "must be an array, got: #{inspect(other)}"}]

      :error ->
        # Missing key already flagged at the top level.
        []
    end
  end

  defp check_entity(item, base, kind, type_registry, object_ids, seen) when is_map(item) do
    allowed_keys = if kind == :event, do: @event_keys, else: @object_keys
    required_keys = if kind == :event, do: @event_required, else: @object_required
    type_source = if kind == :event, do: "ocel:eventTypes", else: "ocel:objectTypes"

    extra_key_violations =
      item
      |> Map.keys()
      |> MapSet.new()
      |> MapSet.difference(MapSet.new(allowed_keys))
      |> MapSet.to_list()
      |> Enum.sort()
      |> Enum.map(fn key ->
        %{path: "#{base}.#{key}", reason: "unexpected key '#{key}' (closed vocabulary)"}
      end)

    missing_key_violations =
      for key <- required_keys, not Map.has_key?(item, key) do
        %{path: "#{base}.#{key}", reason: "missing required key"}
      end

    violations =
      extra_key_violations ++
        missing_key_violations ++
        check_id(Map.fetch(item, "id"), base, seen, kind) ++
        check_type(Map.fetch(item, "type"), base, type_registry, type_source) ++
        check_time(Map.fetch(item, "time"), base, kind) ++
        check_attributes(Map.fetch(item, "attributes"), base) ++
        check_relationships(Map.fetch(item, "relationships"), base, object_ids)

    seen =
      case Map.fetch(item, "id") do
        {:ok, id} when is_binary(id) and id != "" -> MapSet.put(seen, id)
        _ -> seen
      end

    {seen, violations}
  end

  defp check_entity(item, base, _kind, _type_registry, _object_ids, seen) do
    {seen, [%{path: base, reason: "must be a JSON object, got: #{inspect(item)}"}]}
  end

  defp check_id({:ok, id}, base, seen, kind) when is_binary(id) do
    cond do
      id == "" ->
        [%{path: "#{base}.id", reason: "must be a non-empty string"}]

      MapSet.member?(seen, id) ->
        [%{path: "#{base}.id", reason: "duplicate #{kind} id '#{id}'"}]

      true ->
        []
    end
  end

  defp check_id({:ok, id}, base, _seen, _kind),
    do: [%{path: "#{base}.id", reason: "must be a string, got: #{inspect(id)}"}]

  defp check_id(:error, _base, _seen, _kind), do: []

  defp check_type({:ok, type}, base, type_registry, type_source) when is_binary(type) do
    if type_registry == :unknown or MapSet.member?(type_registry, type) do
      []
    else
      [%{path: "#{base}.type", reason: "'#{type}' not declared in #{type_source}"}]
    end
  end

  defp check_type({:ok, type}, base, _type_registry, _type_source),
    do: [%{path: "#{base}.type", reason: "must be a string, got: #{inspect(type)}"}]

  defp check_type(:error, _base, _type_registry, _type_source), do: []

  defp check_time({:ok, time}, base, :event) when is_binary(time) do
    case DateTime.from_iso8601(time) do
      {:ok, _utc, 0} ->
        []

      {:ok, _utc, offset} ->
        [
          %{
            path: "#{base}.time",
            reason: "'#{time}' is ISO8601 but not UTC (offset #{offset}s, must be 0)"
          }
        ]

      {:error, _reason} ->
        [%{path: "#{base}.time", reason: "'#{time}' is not parseable ISO8601 UTC"}]
    end
  end

  defp check_time({:ok, time}, base, :event),
    do: [%{path: "#{base}.time", reason: "must be a string, got: #{inspect(time)}"}]

  defp check_time(_fetched, _base, :object), do: []
  # Objects carrying a "time" key are policed by the closed vocabulary
  # (extra-key violation), not here; a missing "time" on an event is already
  # flagged as a missing required key.
  defp check_time(:error, _base, _kind), do: []

  defp check_attributes({:ok, attributes}, _base) when is_map(attributes), do: []

  defp check_attributes({:ok, attributes}, base),
    do: [
      %{path: "#{base}.attributes", reason: "must be a JSON object, got: #{inspect(attributes)}"}
    ]

  defp check_attributes(:error, _base), do: []

  # -- relationships --------------------------------------------------------

  defp check_relationships({:ok, rels}, base, object_ids) when is_list(rels) do
    rels
    |> Enum.with_index()
    |> Enum.flat_map(fn {rel, i} ->
      check_relationship(rel, "#{base}.relationships[#{i}]", object_ids)
    end)
  end

  defp check_relationships({:ok, rels}, base, _object_ids),
    do: [%{path: "#{base}.relationships", reason: "must be an array, got: #{inspect(rels)}"}]

  defp check_relationships(:error, _base, _object_ids), do: []

  defp check_relationship(rel, base, object_ids) when is_map(rel) do
    extra_key_violations =
      rel
      |> Map.keys()
      |> MapSet.new()
      |> MapSet.difference(@relationship_keys_mapset)
      |> MapSet.to_list()
      |> Enum.sort()
      |> Enum.map(fn key ->
        %{path: "#{base}.#{key}", reason: "unexpected key '#{key}' (closed vocabulary)"}
      end)

    missing_key_violations =
      for key <- @relationship_required, not Map.has_key?(rel, key) do
        %{path: "#{base}.#{key}", reason: "missing required key"}
      end

    extra_key_violations ++
      missing_key_violations ++
      check_object_id(Map.fetch(rel, "objectId"), base, object_ids) ++
      check_qualifier(Map.fetch(rel, "qualifier"), base)
  end

  defp check_relationship(rel, base, _object_ids),
    do: [%{path: base, reason: "must be a JSON object, got: #{inspect(rel)}"}]

  defp check_object_id({:ok, object_id}, base, object_ids) when is_binary(object_id) do
    if object_ids == :unknown or MapSet.member?(object_ids, object_id) do
      []
    else
      [
        %{
          path: "#{base}.objectId",
          reason: "objectId '#{object_id}' does not resolve to any object in ocel:objects"
        }
      ]
    end
  end

  defp check_object_id({:ok, object_id}, base, _object_ids),
    do: [%{path: "#{base}.objectId", reason: "must be a string, got: #{inspect(object_id)}"}]

  defp check_object_id(:error, _base, _object_ids), do: []

  defp check_qualifier({:ok, qualifier}, _base) when is_binary(qualifier), do: []

  defp check_qualifier({:ok, qualifier}, base),
    do: [%{path: "#{base}.qualifier", reason: "must be a string, got: #{inspect(qualifier)}"}]

  defp check_qualifier(:error, _base), do: []

  # -- report ---------------------------------------------------------------

  defp report(log, event_registry, object_registry) do
    %{
      "status" => "valid",
      "event_count" => length(Map.fetch!(log, "ocel:events")),
      "object_count" => length(Map.fetch!(log, "ocel:objects")),
      "event_types" => event_registry |> known_names() |> Enum.sort(),
      "object_types" => object_registry |> known_names() |> Enum.sort()
    }
  end

  defp known_names(:unknown), do: []
  defp known_names(%MapSet{} = registry), do: MapSet.to_list(registry)
end
