defmodule Xaas.Telemetry.OcelNdjson do
  @moduledoc """
  Assembles the ndjson egress of `Xaas.Telemetry.OcelAshEmitter` (since
  the OCEL v2 reshape: one complete, individually-conformant OCEL 2.0
  JSON log per line) into ONE aggregated OCEL 2.0 document and runs the
  real conformance court -- `Xaas.Ultracode.Ocel.Validator` -- over it.

  This is the validation helper the RAISE change added alongside the
  emitter reshape: the court is authoritative ("if an emitter's output
  diverges from the spec, the court stays authoritative and the emitter
  is wrong"), and this module is the mechanical bridge from the
  append-only line format the sink writes to the whole-document shape
  the court adjudicates. It contains no validation law of its own -- it
  only assembles and delegates.

  ## Assembly law (deterministic, order-preserving, fail-closed)

    * Blank lines are skipped (a trailing newline is not an event); the
      1-based line numbers in violation paths never count blanks.
    * Each non-blank line must decode as JSON and carry ALL FOUR OCEL 2.0
      top-level keys as arrays (`ocel:objectTypes`, `ocel:eventTypes`,
      `ocel:events`, `ocel:objects`) -- exactly what the reshaped emitter
      writes per line. Anything else is ONE typed violation at path
      `"line <n>"` and the whole assembly fails closed. This is also the
      permanent tripwire against regressing to the pre-reshape legacy
      flat-event shape (`ocel:eid`/`ocel:activity`/`ocel:vmap`), which is
      named explicitly in its violation reason.
    * Type declarations: a line whose declaration list contains a
      malformed element (neither a non-empty string nor a
      `%{"name" => non-empty-string}` object) is ONE typed violation at
      `"line <n>.<key>[<i>]"` -- the court's declaration law, applied one
      level up, so a corrupt line can never launder itself into a clean
      aggregate.
    * `"ocel:events"`: concatenated in file order (append order ==
      chronological order for this sink). Duplicate event ids are NOT
      silently merged -- the court's duplicate-id law adjudicates them.
    * `"ocel:objects"`: deduplicated by string `"id"`, first occurrence
      wins (every emitter line re-states the same class-level objects;
      the aggregated log states each object once). Non-conforming
      objects are kept as-is for the court to adjudicate -- assembly
      never drops evidence.
    * `"ocel:eventTypes"` / `"ocel:objectTypes"`: union of the lines'
      well-formed declaration names plus every type actually used by an
      assembled event or object -- assembly can never manufacture a
      used-but-undeclared type. Sorted, deduplicated, emitted as
      `%{"name" => t}` declarations (the run-export's declaration form).

  ## API

    * `assemble_document/1` -- lines (enumerable of strings) to
      `{:ok, document}` | `{:error, violations}`.
    * `read_document/1` -- same, from a file path.
    * `validate_ndjson_file/1` -- `read_document/1` then the real court;
      `{:ok, court_report}` | `{:error, violations}`. The report's
      `"event_count"`/`"object_count"` are the aggregated log's counts.
  """

  alias Xaas.Ultracode.Ocel.Validator

  @line_keys ~w(ocel:objectTypes ocel:eventTypes ocel:events ocel:objects)

  @spec assemble_document(Enumerable.t()) ::
          {:ok, map()} | {:error, [Validator.violation()]}
  def assemble_document(lines) do
    lines
    |> Stream.map(&String.trim/1)
    |> Stream.reject(&(&1 == ""))
    |> Enum.with_index(1)
    |> Enum.reduce_while(
      {:ok,
       %{
         events: [],
         objects: [],
         object_ids: MapSet.new(),
         event_types: MapSet.new(),
         object_types: MapSet.new()
       }},
      fn {line, n}, {:ok, acc} ->
        case ingest_line(line, n, acc) do
          {:ok, acc} -> {:cont, {:ok, acc}}
          {:error, violations} -> {:halt, {:error, violations}}
        end
      end
    )
    |> case do
      {:error, violations} -> {:error, violations}
      {:ok, acc} -> {:ok, finalize(acc)}
    end
  end

  @spec read_document(term()) :: {:ok, map()} | {:error, [Validator.violation()]}
  def read_document(path) when is_binary(path) do
    case File.read(path) do
      {:ok, body} ->
        assemble_document(String.split(body, "\n"))

      {:error, reason} ->
        {:error, [%{path: "$", reason: "cannot read file: #{:file.format_error(reason)}"}]}
    end
  end

  def read_document(path),
    do: {:error, [%{path: "$", reason: "path must be a string, got: #{inspect(path)}"}]}

  @doc """
  Assembles the ndjson at `path` and runs the REAL conformance court over
  the aggregated document. Same result shapes as
  `Xaas.Ultracode.Ocel.Validator.validate_file/1`.
  """
  @spec validate_ndjson_file(term()) ::
          {:ok, Validator.report()} | {:error, [Validator.violation()]}
  def validate_ndjson_file(path) do
    case read_document(path) do
      {:ok, document} -> Validator.validate(document)
      {:error, violations} -> {:error, violations}
    end
  end

  # -- per-line ingestion ---------------------------------------------------

  defp ingest_line(line, n, acc) do
    path = "line #{n}"

    case JSON.decode(line) do
      {:ok, %{"ocel:eid" => _, "ocel:activity" => _}} ->
        # The pre-reshape emitter shape, named exactly, BEFORE the generic
        # missing-key law: this module is the permanent tripwire against
        # regressing to that shape, so the violation must name it, not a
        # generic "must be an array".
        {:error,
         [
           %{
             path: path,
             reason:
               "not an OCEL 2.0 document: legacy flat event shape (ocel:eid/ocel:activity) " <>
                 "emitted before the OCEL v2 reshape -- regenerate this log"
           }
         ]}

      {:ok, %{} = doc} ->
        with :ok <- require_line_keys(doc, path),
             :ok <- check_declarations(doc, "ocel:eventTypes", path),
             :ok <- check_declarations(doc, "ocel:objectTypes", path) do
          # All per-line laws passed; merging is total (dedup by id, union
          # of declarations) and cannot fail.
          merge_doc(doc, acc)
        else
          {:error, violations} -> {:error, violations}
        end

      {:ok, other} ->
        {:error, [%{path: path, reason: "not an OCEL 2.0 document: #{inspect(other)}"}]}

      {:error, decode_error} ->
        {:error, [%{path: path, reason: "malformed JSON: #{decode_reason(decode_error)}"}]}
    end
  end

  defp decode_reason(error) when is_struct(error), do: Exception.message(error)
  defp decode_reason(other), do: inspect(other)

  defp require_line_keys(doc, path) do
    violations =
      for key <- @line_keys,
          not is_list(Map.get(doc, key)) do
        %{path: "#{path}.#{key}", reason: "must be an array, got: #{inspect(Map.get(doc, key))}"}
      end

    case violations do
      [] -> :ok
      violations -> {:error, violations}
    end
  end

  # A malformed declaration element in ANY line is a violation naming the
  # exact line path -- the same law the court applies to a document's
  # declaration list, applied per line, so corruption never aggregates.
  defp check_declarations(doc, key, path) do
    {:ok, decls} = Map.fetch(doc, key)

    bad =
      decls
      |> Enum.with_index()
      |> Enum.reject(fn {decl, _i} -> well_formed_declaration?(decl) end)
      |> Enum.map(fn {decl, i} ->
        %{
          path: "#{path}.#{key}[#{i}]",
          reason:
            "malformed type declaration #{inspect(decl)}: must be a non-empty string " <>
              "or an object with exactly one key \"name\" whose value is a non-empty string"
        }
      end)

    case bad do
      [] -> :ok
      violations -> {:error, violations}
    end
  end

  defp well_formed_declaration?(name) when is_binary(name), do: name != ""

  defp well_formed_declaration?(%{"name" => name} = decl) when map_size(decl) == 1,
    do: well_formed_declaration?(name)

  defp well_formed_declaration?(_), do: false

  defp merge_doc(doc, acc) do
    {:ok, events} = Map.fetch(doc, "ocel:events")
    {:ok, objects} = Map.fetch(doc, "ocel:objects")

    {new_objects, object_ids} =
      Enum.reduce(objects, {acc.objects, acc.object_ids}, fn object, {objs, ids} ->
        case object do
          %{"id" => id} when is_binary(id) ->
            if MapSet.member?(ids, id) do
              {objs, ids}
            else
              {objs ++ [object], MapSet.put(ids, id)}
            end

          _ ->
            # Objects without a usable id are kept -- the court
            # adjudicates their exact violation class; assembly never
            # drops evidence.
            {objs ++ [object], ids}
        end
      end)

    used_event_types =
      for %{"type" => t} <- events, is_binary(t), t != "", do: t

    used_object_types =
      for %{"type" => t} <- objects, is_binary(t), t != "", do: t

    {:ok,
     %{
       acc
       | events: acc.events ++ events,
         objects: new_objects,
         object_ids: object_ids,
         event_types:
           MapSet.union(
             acc.event_types,
             MapSet.new(declared_names(doc, "ocel:eventTypes") ++ used_event_types)
           ),
         object_types:
           MapSet.union(
             acc.object_types,
             MapSet.new(declared_names(doc, "ocel:objectTypes") ++ used_object_types)
           )
     }}
  end

  # Precondition: check_declarations/3 already proved every element
  # well-formed, so extraction here is total.
  defp declared_names(doc, key) do
    {:ok, decls} = Map.fetch(doc, key)

    Enum.map(decls, fn
      name when is_binary(name) -> name
      %{"name" => name} -> name
    end)
  end

  defp finalize(acc) do
    %{
      "ocel:objectTypes" => acc.object_types |> Enum.sort() |> Enum.map(&%{"name" => &1}),
      "ocel:eventTypes" => acc.event_types |> Enum.sort() |> Enum.map(&%{"name" => &1}),
      "ocel:events" => acc.events,
      "ocel:objects" => acc.objects
    }
  end
end
