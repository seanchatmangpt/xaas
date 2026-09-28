defmodule Mix.Tasks.Xaas.Ash.Gen do
  @shortdoc "Manufactures Ash enums + resources from an ontology graph via Ash's own igniter generators"

  @moduledoc """
  The ontology -> Ash bridge (GC-26927-SELFDIGEST, "Ash is the executable
  state"): loads one RDF/TTL ontology, SPARQLs manufacturing facts out of it
  (ucsd:EnumSpec / ucsd:AshResource / ucsd:AttrSpec / ucsd:RelSpec vocabulary,
  queries live in `queries/` beside the ontology file), and composes Ash's OWN
  generators — `ash.gen.enum`, `ash.gen.resource` (which itself composes
  `ash.gen.domain` and registers every resource) — through
  `Igniter.compose_task/3`. No Ash DSL is re-rendered here: the pack owns the
  semantics, Ash owns the code shapes.

      mix xaas.ash.gen --ontology priv/ggen/ultracode-self-digest-pack/ontology.ttl

  Attribute rows map to `--attribute name:type[:required][:public]` and
  relationship rows to `--relationship kind:name:Target[:required]`, exactly
  the ash.gen.resource CLI contract (`resolve_type/1`: dotted tokens become
  modules, so an Ash.Type.Enum module rides through as an attribute type).
  """

  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :xaas,
      example: "mix xaas.ash.gen --ontology priv/ggen/ultracode-self-digest-pack/ontology.ttl",
      schema: [ontology: :string],
      required: [:ontology]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    ontology_path = igniter.args.options[:ontology]
    queries_dir = Path.join(Path.dirname(ontology_path), "queries")

    graph = GgenIgniter.Ontology.load!(ontology_path)

    query = fn name ->
      GgenIgniter.Query.Oxigraph.run(graph, File.read!(Path.join(queries_dir, "#{name}.rq")))
    end

    enums = query.("enums")
    resources = query.("resources")
    attrs = query.("attributes")
    rels = query.("relationships")

    igniter =
      Enum.reduce(enums, igniter, fn e, acc ->
        values = e["enumValues"] |> String.split() |> Enum.join(",")

        Igniter.compose_task(acc, "ash.gen.enum", [
          e["enumModule"],
          values,
          "--short-name",
          e["shortName"],
          "--ignore-if-exists"
        ])
      end)

    Enum.reduce(resources, igniter, fn r, acc ->
      module = r["moduleName"]

      attr_args =
        attrs
        |> Enum.filter(&(&1["moduleName"] == module))
        |> Enum.sort_by(& &1["attrOrder"])
        |> Enum.flat_map(fn a ->
          spec =
            [a["attrName"], a["attrType"]] ++
              bool_modifiers(a["attrRequired"], a["attrPublic"])

          ["--attribute", Enum.join(spec, ":")]
        end)

      rel_args =
        rels
        |> Enum.filter(&(&1["moduleName"] == module))
        |> Enum.sort_by(& &1["relName"])
        |> Enum.flat_map(fn rel ->
          spec =
            [rel["relKind"], rel["relName"], rel["relTarget"]] ++
              bool_modifiers("false", "false")

          ["--relationship", Enum.join(spec, ":")]
        end)

      args =
        [
          module,
          "--domain",
          r["resourceDomain"],
          "--uuid-primary-key",
          "id",
          "--timestamps",
          "--default-actions",
          r["defaultActions"] || "create,read,update",
          "--ignore-if-exists"
        ] ++ attr_args ++ rel_args

      Igniter.compose_task(acc, "ash.gen.resource", args)
      |> Igniter.compose_task("ash.extend", [
        module,
        "postgres"
      ])
    end)
    |> Igniter.add_notice(
      "xaas.ash.gen: #{length(enums)} enums + #{length(resources)} resources composed from #{Path.basename(ontology_path)}"
    )
  end

  defp bool_modifiers(required, public) do
    []
    |> maybe_add(required == "true", "required")
    |> maybe_add(public == "true", "public")
  end

  defp maybe_add(list, true, item), do: list ++ [item]
  defp maybe_add(list, false, _item), do: list
end
