defmodule Xaas.Sjira.ArdCourt do
  @moduledoc """
  Machine acceptance court for a Semantic Jira ARD (architecture decision/requirements record).

  An ARD is accepted or refused as a pure function of files on disk. No human judgement
  sits in the acceptance path: the ARD carries a machine manifest (a fenced
  `json ard-manifest` block) and the court checks every claim in it against the real
  artifacts it names.

  ## Checks

    * `ARD-001` required sections exist.
    * `ARD-002` the machine manifest is present and parses.
    * `ARD-003` the ontology source is named, resolvable, parses as RDF and holds SHACL node shapes.
    * `ARD-004` every public ontology the profile leans on exists, parses and matches its pinned sha256.
    * `ARD-005` the manifest's resources and the ontology's node shapes are the same set, with the
      same target classes.
    * `ARD-006` every `sh:targetClass` and `sh:path` is a term DECLARED in one of the pinned public
      ontologies (class vs property type respected).
    * `ARD-007` the ontology declares no local class or property.
    * `ARD-008` every resource has a generator route: the ggen manifest reads the named ontology,
      declares the named rule with existing query and template files, and the rendered construction
      script contains a framework-generator line for that resource. No resource is hand-written.
    * `ARD-009` every hand-written file carries an explicit `UNSUPPORTED(generator-capability)`
      entry (missing capability + an owner pack that exists), and no product `.ex` file under the
      package `lib/` is undeclared. Generated files are exactly the file each resource module and
      its domain module map to, plus files a ggen rule declares as output (`generated_files`);
      never a glob, which would let a hand-written file hide in a generated directory.
    * `ARD-010` falsifiers exist, are complete and unique, and include a generator-coverage falsifier.
    * `ARD-011` non-goals are stated.
    * `ARD-012` supersession tripwires: if better public prior art has appeared (a path now exists)
      and the profile still targets the old class, the ARD is refused.

  Verdict is `ACCEPTED` only when every check passes. Anything the court cannot evaluate is a
  failed check, never a pass. Exit codes of the CLI: `0` accepted, `1` refused, `2` court could
  not run (unreadable ARD or unwritable receipt).

  The court reads and hashes files and parses RDF and TOML. It executes nothing and grants no
  authority; ACCEPTED is admission of the ARD, not a merge or publish.
  """

  @version "1"
  @sh "http://www.w3.org/ns/shacl#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @class_types [
    "http://www.w3.org/2000/01/rdf-schema#Class",
    "http://www.w3.org/2002/07/owl#Class"
  ]
  @property_types [
    "http://www.w3.org/1999/02/22-rdf-syntax-ns#Property",
    "http://www.w3.org/2002/07/owl#ObjectProperty",
    "http://www.w3.org/2002/07/owl#DatatypeProperty",
    "http://www.w3.org/2002/07/owl#AnnotationProperty"
  ]
  @required_sections [
    "Ontology source",
    "Resources",
    "Generator route",
    "Hand-written residue",
    "Non-goals",
    "Falsifiers",
    "Machine manifest"
  ]

  @type check :: %{String.t() => term()}
  @type receipt :: %{String.t() => term()}

  @doc "Court version, bound into every receipt."
  @spec version() :: String.t()
  def version, do: @version

  @doc """
  Judges the ARD at `ard_path`. Returns `{:ok, receipt}` (verdict `ACCEPTED` or `REFUSED`) or
  `{:error, {:unreadable, path, reason}}` when the court cannot run at all.
  """
  @spec judge(Path.t()) :: {:ok, receipt()} | {:error, term()}
  def judge(ard_path) do
    ard_path = Path.expand(ard_path)

    case File.read(ard_path) do
      {:error, reason} ->
        {:error, {:unreadable, ard_path, reason}}

      {:ok, text} ->
        manifest_result = extract_manifest(text)
        manifest = with {:ok, m} <- manifest_result, do: m
        manifest = if is_map(manifest), do: manifest, else: nil
        base = Path.dirname(ard_path)
        ctx = build_context(manifest, base)

        checks = [
          check("ARD-001", "required sections", fn -> sections(text) end),
          check("ARD-002", "machine manifest parses", fn -> manifest_check(manifest_result) end),
          check("ARD-003", "ontology source named, resolvable, parsed", fn ->
            needs(ctx, &ontology_source/1)
          end),
          check("ARD-004", "public ontologies exist, parse, match pinned sha256", fn ->
            needs(ctx, &public_ontologies/1)
          end),
          check("ARD-005", "resources equal ontology node shapes and target classes", fn ->
            needs(ctx, &resources_match/1)
          end),
          check("ARD-006", "every target class and property path is a declared public term", fn ->
            needs(ctx, &terms_resolve/1)
          end),
          check("ARD-007", "ontology declares no local class or property", fn ->
            needs(ctx, &no_local_vocabulary/1)
          end),
          check("ARD-008", "every resource has a generator route", fn ->
            needs(ctx, &generator_routes/1)
          end),
          check("ARD-009", "hand-written residue carries UNSUPPORTED(generator-capability)", fn ->
            needs(ctx, &handwritten_residue/1)
          end),
          check("ARD-010", "falsifiers present, complete, unique", fn ->
            needs(ctx, &falsifiers/1)
          end),
          check("ARD-011", "non-goals stated", fn -> needs(ctx, &non_goals/1) end),
          check("ARD-012", "supersession tripwires", fn -> needs(ctx, &tripwires/1) end)
        ]

        {:ok, build_receipt(ard_path, text, manifest, ctx, checks)}
    end
  end

  @doc """
  Command-line entry: `FILE [--receipt PATH] [--quiet]`. Prints one line per check, writes the
  receipt if asked, and returns the process exit code (0 accepted, 1 refused, 2 could not run).
  """
  @spec cli([String.t()]) :: 0 | 1 | 2
  def cli(args) do
    {opts, rest, invalid} =
      OptionParser.parse(args, strict: [receipt: :string, quiet: :boolean])

    cond do
      invalid != [] or length(rest) != 1 ->
        IO.puts(:stderr, "usage: mix xaas.sjira.ard_court FILE [--receipt PATH] [--quiet]")
        2

      true ->
        [file] = rest

        case judge(file) do
          {:error, {:unreadable, path, reason}} ->
            IO.puts(:stderr, "COURT_COULD_NOT_RUN: cannot read #{path}: #{inspect(reason)}")
            2

          {:ok, receipt} ->
            unless opts[:quiet], do: print(receipt)
            write_receipt(receipt, opts[:receipt])
        end
    end
  end

  # ------------------------------------------------------------------ context

  defp build_context(nil, base), do: %{manifest: nil, base: base}

  defp build_context(manifest, base) do
    ontology_path = expand(dig(manifest, ["ontology", "source"]), base)

    ontology =
      cond do
        not is_binary(ontology_path) ->
          {:error, "ontology.source is not named"}

        not File.regular?(ontology_path) ->
          {:error, "ontology source does not exist: #{ontology_path}"}

        true ->
          read_graph(ontology_path, dig(manifest, ["ontology", "format"]) || "turtle")
      end

    publics =
      manifest
      |> Map.get("public_ontologies", [])
      |> List.wrap()
      |> Enum.map(fn
        entry when not is_map(entry) ->
          {%{}, nil, {:error, "public_ontologies entry is not an object"}}

        entry ->
          path = expand(entry["path"], base)

          result =
            cond do
              not is_binary(path) -> {:error, "path not named"}
              not File.regular?(path) -> {:error, "file does not exist: #{path}"}
              true -> read_graph(path, entry["format"] || "turtle")
            end

          {entry, path, result}
      end)

    %{
      manifest: manifest,
      base: base,
      ontology_path: ontology_path,
      ontology: ontology,
      publics: publics
    }
  end

  defp needs(%{manifest: nil}, _fun), do: {:fail, ["cannot evaluate: no parsed machine manifest"]}
  defp needs(ctx, fun), do: fun.(ctx)

  # ------------------------------------------------------------------- checks

  defp sections(text) do
    headings =
      ~r/^##\s+(.+?)\s*$/m
      |> Regex.scan(text, capture: :all_but_first)
      |> Enum.map(fn [h] -> h end)

    case Enum.reject(@required_sections, &(&1 in headings)) do
      [] -> {:pass, ["#{length(@required_sections)} required sections present"]}
      missing -> {:fail, Enum.map(missing, &"missing section: ## #{&1}")}
    end
  end

  defp manifest_check({:ok, _}), do: {:pass, ["manifest parsed"]}
  defp manifest_check({:error, reason}), do: {:fail, [reason]}

  defp ontology_source(%{ontology: {:error, msg}}), do: {:fail, [msg]}

  defp ontology_source(%{ontology: {:ok, graph}, ontology_path: path}) do
    case node_shapes(graph) do
      [] -> {:fail, ["ontology parses but holds no sh:NodeShape: #{path}"]}
      shapes -> {:pass, ["#{path}: #{length(shapes)} node shapes"]}
    end
  end

  defp public_ontologies(%{publics: []}), do: {:fail, ["no public_ontologies declared"]}

  defp public_ontologies(%{publics: publics}) do
    failures =
      Enum.flat_map(publics, fn {entry, path, result} ->
        name = entry["name"] || "(unnamed)"
        pinned = entry["sha256"]

        cond do
          match?({:error, _}, result) ->
            ["#{name}: #{elem(result, 1)}"]

          not (is_binary(pinned) and Regex.match?(~r/\A[0-9a-f]{64}\z/, pinned)) ->
            ["#{name}: sha256 not pinned (64 hex chars required)"]

          sha256_file(path) != pinned ->
            ["#{name}: sha256 drift: pinned #{pinned}, actual #{sha256_file(path)}"]

          true ->
            []
        end
      end)

    if failures == [],
      do: {:pass, ["#{length(publics)} public ontologies pinned and matching"]},
      else: {:fail, failures}
  end

  defp resources_match(%{ontology: {:error, _}}), do: {:fail, ["ontology unavailable"]}

  defp resources_match(%{manifest: manifest, ontology: {:ok, graph}}) do
    resources = List.wrap(manifest["resources"])
    shapes = graph |> node_shapes() |> Map.new(&{to_string(&1), target_classes(graph, &1)})
    listed = Enum.map(resources, & &1["shape"])

    listed_failures =
      Enum.flat_map(resources, fn r ->
        name = r["name"] || r["shape"] || "(unnamed resource)"

        cond do
          not (is_binary(r["shape"]) and is_binary(r["class"]) and is_binary(r["module"])) ->
            ["#{name}: resource needs name, module, shape and class"]

          not Map.has_key?(shapes, r["shape"]) ->
            ["#{name}: shape #{r["shape"]} is not a sh:NodeShape in the ontology"]

          shapes[r["shape"]] != [r["class"]] ->
            [
              "#{name}: class #{r["class"]} differs from the ontology target class " <>
                inspect(shapes[r["shape"]])
            ]

          true ->
            []
        end
      end)

    unlisted =
      for shape <- Map.keys(shapes),
          shape not in listed,
          do: "ontology shape #{shape} has no resource entry"

    dups = for {s, n} <- Enum.frequencies(listed), n > 1, do: "shape #{s} listed #{n} times"

    empty = if resources == [], do: ["no resources declared"], else: []

    case empty ++ listed_failures ++ Enum.sort(unlisted) ++ dups do
      [] -> {:pass, ["#{length(resources)} resources match #{map_size(shapes)} node shapes"]}
      failures -> {:fail, failures}
    end
  end

  defp terms_resolve(%{ontology: {:error, _}}), do: {:fail, ["ontology unavailable"]}

  defp terms_resolve(%{ontology: {:ok, graph}, publics: publics}) do
    loaded = for {_e, _p, {:ok, g}} <- publics, do: g

    failures =
      graph
      |> node_shapes()
      |> Enum.flat_map(fn shape ->
        classes =
          for c <- target_classes(graph, shape),
              not declared?(loaded, c, @class_types),
              do:
                "#{shape}: sh:targetClass #{c} is not a declared class in any pinned public ontology"

        paths =
          for p <- property_paths(graph, shape),
              not declared?(loaded, p, @property_types),
              do:
                "#{shape}: sh:path #{p} is not a declared property in any pinned public ontology"

        classes ++ paths
      end)

    if failures == [],
      do: {:pass, ["every class and path resolves in a pinned public ontology"]},
      else: {:fail, failures}
  end

  defp no_local_vocabulary(%{ontology: {:error, _}}), do: {:fail, ["ontology unavailable"]}

  defp no_local_vocabulary(%{ontology: {:ok, graph}}) do
    local =
      for {s, p, o} <- RDF.Graph.triples(graph),
          to_string(p) == @rdf_type,
          to_string(o) in (@class_types ++ @property_types),
          do: "local vocabulary declared: #{s} a #{o}"

    if local == [],
      do: {:pass, ["no local class or property declared"]},
      else: {:fail, Enum.sort(local)}
  end

  defp generator_routes(ctx) do
    %{manifest: manifest, base: base} = ctx
    gen = manifest["generator"] || %{}
    toml_path = expand(gen["manifest"], base)
    script_path = expand(gen["construction_script"], base)
    pack_path = expand(gen["pack"], base)

    pack_failure =
      if is_binary(pack_path) and File.dir?(pack_path),
        do: [],
        else: ["generator.pack does not exist: #{inspect(gen["pack"])}"]

    with true <- is_binary(toml_path) and File.regular?(toml_path),
         {:ok, toml} <- Toml.decode(File.read!(toml_path)) do
      toml_dir = Path.dirname(toml_path)
      toml_source = expand(dig(toml, ["ontology", "source"]), toml_dir)
      rules = dig(toml, ["generation", "rules"]) || []

      source_failure =
        if toml_source == ctx.ontology_path,
          do: [],
          else: [
            "ggen manifest reads #{inspect(toml_source)} but the ARD names #{inspect(ctx.ontology_path)}"
          ]

      rule_failures =
        Enum.flat_map(rules, fn rule ->
          for key <- ["query", "template"],
              file = dig(rule, [key, "file"]),
              not File.regular?(expand(file, toml_dir)),
              do: "rule #{rule["name"]}: #{key} file missing: #{file}"
        end)

      script =
        if is_binary(script_path) and File.regular?(script_path),
          do: File.read!(script_path),
          else: nil

      script_failure =
        if script,
          do: [],
          else: ["construction script does not exist: #{inspect(gen["construction_script"])}"]

      route_failures =
        manifest["resources"]
        |> List.wrap()
        |> Enum.flat_map(fn r ->
          name = r["name"] || r["module"] || "(unnamed resource)"
          route = r["generator_route"] || %{}
          rule = Enum.find(rules, &(&1["name"] == route["rule"]))

          cond do
            r["handwritten"] == true ->
              ["#{name}: hand-written resource where a generator route exists"]

            not is_map(r["generator_route"]) ->
              ["#{name}: no generator_route"]

            is_nil(rule) ->
              ["#{name}: rule #{inspect(route["rule"])} is not declared in the ggen manifest"]

            script &&
                not Regex.match?(
                  ~r/mix ash\.gen\.resource #{Regex.escape(to_string(r["module"]))}(\s|\\|$)/,
                  script
                ) ->
              ["#{name}: construction script has no `mix ash.gen.resource #{r["module"]}` line"]

            true ->
              []
          end
        end)

      case pack_failure ++ source_failure ++ rule_failures ++ script_failure ++ route_failures do
        [] ->
          {:pass,
           ["#{length(List.wrap(manifest["resources"]))} resources routed through #{toml_path}"]}

        failures ->
          {:fail, failures}
      end
    else
      false ->
        {:fail, pack_failure ++ ["ggen manifest does not exist: #{inspect(gen["manifest"])}"]}

      {:error, reason} ->
        {:fail, pack_failure ++ ["ggen manifest does not parse: #{inspect(reason)}"]}
    end
  end

  defp handwritten_residue(%{manifest: manifest, base: base}) do
    package_root = expand(dig(manifest, ["package", "root"]), base)

    if is_binary(package_root) and File.dir?(package_root) do
      entries = List.wrap(manifest["handwritten"])
      entry_failures = Enum.flat_map(entries, &residue_entry_failures(&1, package_root))

      # Generated files are exactly: the file each resource module and its domain module map to
      # (framework-generator convention), plus files a ggen rule declares as its output. A glob
      # would let a hand-written file hide inside a generated directory.
      derived = derived_files(manifest)

      missing =
        for f <- derived,
            not File.regular?(Path.join(package_root, f)),
            do: "generated file missing: #{f}"

      {ggen_failures, ggen_files} = ggen_output_files(manifest, package_root, base)
      handwritten = for e <- entries, is_binary(e["path"]), do: e["path"]
      declared = expand_globs(package_root, derived ++ ggen_files ++ handwritten)
      lib_files = Path.wildcard(Path.join(package_root, "lib/**/*.ex"))

      undeclared =
        for file <- lib_files,
            file not in declared,
            do:
              "undeclared hand-written file (neither generated nor listed): #{Path.relative_to(file, package_root)}"

      case entry_failures ++ missing ++ ggen_failures ++ Enum.sort(undeclared) do
        [] ->
          {:pass,
           [
             "#{length(lib_files)} lib files all generated or declared; " <>
               "#{length(entries)} residue entries carry UNSUPPORTED"
           ]}

        failures ->
          {:fail, failures}
      end
    else
      {:fail, ["package.root does not exist: #{inspect(dig(manifest, ["package", "root"]))}"]}
    end
  end

  defp derived_files(manifest) do
    manifest["resources"]
    |> List.wrap()
    |> Enum.flat_map(fn r ->
      module = r["module"]

      domain =
        if is_binary(module), do: module |> String.split(".") |> Enum.drop(-1) |> Enum.join(".")

      for m <- [module, domain], is_binary(m), m != "", do: "lib/" <> Macro.underscore(m) <> ".ex"
    end)
    |> Enum.uniq()
  end

  # `generated_files` must each be the declared output of a ggen rule; returns {failures, files}.
  defp ggen_output_files(manifest, package_root, base) do
    claimed = List.wrap(manifest["generated_files"])
    toml_path = expand(dig(manifest, ["generator", "manifest"]), base)

    outputs =
      with true <- is_binary(toml_path) and File.regular?(toml_path),
           {:ok, toml} <- Toml.decode(File.read!(toml_path)) do
        for rule <- dig(toml, ["generation", "rules"]) || [],
            out = rule["output_file"],
            is_binary(out),
            do: Path.expand(out, Path.dirname(toml_path))
      else
        _ -> []
      end

    failures =
      Enum.flat_map(claimed, fn file ->
        path = if is_binary(file), do: Path.expand(file, package_root)

        cond do
          is_nil(path) -> ["generated_files entry is not a path: #{inspect(file)}"]
          path not in outputs -> ["claimed generated but no ggen rule outputs it: #{file}"]
          not File.regular?(path) -> ["generated file missing: #{file}"]
          true -> []
        end
      end)

    {failures, Enum.filter(claimed, &is_binary/1)}
  end

  defp residue_entry_failures(entry, package_root) do
    path = entry["path"]
    unsupported = entry["unsupported"] || %{}
    label = "handwritten #{inspect(path)}"
    owner = unsupported["owner_pack_path"]

    [
      if(is_binary(path) and Path.wildcard(Path.join(package_root, path)) != [],
        do: nil,
        else: "#{label}: path matches no file"
      ),
      if(present?(entry["element"]), do: nil, else: "#{label}: no element described"),
      if(unsupported["kind"] == "generator-capability",
        do: nil,
        else: "#{label}: missing UNSUPPORTED(generator-capability) entry"
      ),
      if(present?(unsupported["missing_capability"]),
        do: nil,
        else: "#{label}: UNSUPPORTED entry names no missing capability"
      ),
      if(is_binary(owner) and File.dir?(Path.expand(owner)),
        do: nil,
        else: "#{label}: owner pack does not exist: #{inspect(owner)}"
      )
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp falsifiers(%{manifest: manifest}) do
    list = List.wrap(manifest["falsifiers"])
    ids = Enum.map(list, & &1["id"])

    incomplete =
      for f <- list,
          not (present?(f["id"]) and present?(f["statement"]) and present?(f["check"])),
          do: "falsifier #{inspect(f["id"])}: needs id, statement and check"

    dups = for {id, n} <- Enum.frequencies(ids), n > 1, do: "falsifier id #{id} repeated"

    coverage =
      if Enum.any?(list, &(&1["kind"] == "generator-coverage")),
        do: [],
        else: [
          "no falsifier of kind generator-coverage (hand-written where a pack could generate)"
        ]

    empty = if list == [], do: ["no falsifiers declared"], else: []

    case empty ++ incomplete ++ dups ++ coverage do
      [] -> {:pass, ["#{length(list)} falsifiers"]}
      failures -> {:fail, failures}
    end
  end

  defp non_goals(%{manifest: manifest}) do
    goals = List.wrap(manifest["non_goals"])

    if goals != [] and Enum.all?(goals, &present?/1),
      do: {:pass, ["#{length(goals)} non-goals"]},
      else: {:fail, ["non_goals must be a non-empty list of statements"]}
  end

  defp tripwires(%{ontology: {:error, _}}), do: {:fail, ["ontology unavailable"]}

  defp tripwires(%{manifest: manifest, ontology: {:ok, graph}, base: base}) do
    shapes = graph |> node_shapes() |> Map.new(&{to_string(&1), target_classes(graph, &1)})

    failures =
      manifest
      |> Map.get("supersession_tripwires", [])
      |> List.wrap()
      |> Enum.flat_map(fn t ->
        appeared? = is_binary(t["path"]) and Path.wildcard(expand(t["path"], base)) != []

        cond do
          not appeared? ->
            []

          shapes[t["shape"]] == [t["must_target"]] ->
            []

          true ->
            [
              "superseded: #{t["path"]} now exists, so #{t["shape"]} must target #{t["must_target"]}"
            ]
        end
      end)

    if failures == [], do: {:pass, ["no tripwire fired"]}, else: {:fail, failures}
  end

  # ---------------------------------------------------------------------- RDF

  defp read_graph(path, format) do
    result =
      case format do
        "turtle" -> RDF.Turtle.read_file(path)
        "rdfxml" -> RDF.XML.read_file(path)
        other -> {:error, "unsupported format #{inspect(other)}"}
      end

    case result do
      {:ok, graph} -> {:ok, graph}
      {:error, reason} -> {:error, "#{path} does not parse as #{format}: #{inspect(reason)}"}
    end
  end

  defp node_shapes(graph) do
    for {s, p, o} <- RDF.Graph.triples(graph),
        to_string(p) == @rdf_type,
        to_string(o) == @sh <> "NodeShape",
        uniq: true,
        do: s
  end

  defp target_classes(graph, shape),
    do: objects(graph, shape, @sh <> "targetClass") |> Enum.sort()

  defp property_paths(graph, shape) do
    graph
    |> property_nodes(shape)
    |> Enum.flat_map(&objects(graph, &1, @sh <> "path"))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp property_nodes(graph, shape) do
    case RDF.Graph.description(graph, shape) do
      nil -> []
      desc -> desc |> RDF.Description.get(RDF.iri(@sh <> "property")) |> List.wrap()
    end
  end

  defp objects(graph, subject, predicate) do
    case RDF.Graph.description(graph, subject) do
      nil ->
        []

      desc ->
        desc |> RDF.Description.get(RDF.iri(predicate)) |> List.wrap() |> Enum.map(&to_string/1)
    end
  end

  defp declared?(graphs, iri, types) do
    Enum.any?(graphs, fn graph ->
      graph |> objects(RDF.iri(iri), @rdf_type) |> Enum.any?(&(&1 in types))
    end)
  end

  # -------------------------------------------------------------------- utils

  defp dig(value, []), do: value
  defp dig(%{} = map, [key | rest]), do: dig(Map.get(map, key), rest)
  defp dig(_other, _keys), do: nil

  # A court never crashes on a malformed manifest and never passes on doubt: any exception
  # while evaluating a check is a failed check.
  defp check(id, name, fun) do
    {status, details} =
      try do
        case fun.() do
          {:pass, details} -> {"pass", details}
          {:fail, details} -> {"fail", details}
        end
      rescue
        e -> {"fail", ["court exception while evaluating #{id}: #{Exception.message(e)}"]}
      end

    %{"id" => id, "name" => name, "status" => status, "details" => details}
  end

  defp extract_manifest(text) do
    case Regex.run(~r/```json ard-manifest\n(.*?)\n```/s, text, capture: :all_but_first) do
      nil ->
        {:error, "no ```json ard-manifest fenced block"}

      [json] ->
        case Jason.decode(json) do
          {:ok, %{} = manifest} -> {:ok, manifest}
          {:ok, _} -> {:error, "ard-manifest is not a JSON object"}
          {:error, e} -> {:error, "ard-manifest is not valid JSON: #{Exception.message(e)}"}
        end
    end
  end

  defp expand(nil, _base), do: nil
  defp expand(path, base) when is_binary(path), do: Path.expand(path, base)
  defp expand(_other, _base), do: nil

  defp expand_globs(root, globs),
    do: globs |> Enum.flat_map(&Path.wildcard(Path.join(root, &1))) |> MapSet.new()

  defp present?(value), do: is_binary(value) and String.trim(value) != ""

  defp sha256_file(path),
    do: :crypto.hash(:sha256, File.read!(path)) |> Base.encode16(case: :lower)

  # ------------------------------------------------------------------ receipt

  defp build_receipt(ard_path, text, manifest, ctx, checks) do
    failed = Enum.filter(checks, &(&1["status"] == "fail"))

    body = %{
      "schema" => "xaas.sjira.ard-court-receipt/v1",
      "court_version" => @version,
      "order" => manifest && manifest["order"],
      "verdict" => if(failed == [], do: "ACCEPTED", else: "REFUSED"),
      "ard" => %{"path" => ard_path, "sha256" => sha256(text)},
      "subjects" => subjects(manifest, ctx),
      "counts" => %{"pass" => length(checks) - length(failed), "fail" => length(failed)},
      "checks" => checks
    }

    body
    |> Map.put("receipt_sha256", sha256(canonical(body)))
    |> Map.put(
      "generated_at",
      DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
    )
  end

  defp subjects(nil, _ctx), do: %{}

  defp subjects(manifest, %{base: base} = ctx) do
    file = fn path ->
      p = expand(path, base)

      if is_binary(p) and File.regular?(p),
        do: %{"path" => p, "sha256" => sha256_file(p)},
        else: %{"path" => p, "sha256" => nil}
    end

    %{
      "ontology_source" => file.(dig(manifest, ["ontology", "source"])),
      "ggen_manifest" => file.(dig(manifest, ["generator", "manifest"])),
      "construction_script" => file.(dig(manifest, ["generator", "construction_script"])),
      "public_ontologies" =>
        for {entry, path, _} <- ctx[:publics] || [] do
          %{"name" => entry["name"], "path" => path, "pinned_sha256" => entry["sha256"]}
        end
    }
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)

  # Deterministic JSON: keys sorted recursively, so the receipt hash is replayable.
  defp canonical(%{} = map) do
    inner =
      map
      |> Enum.sort_by(fn {k, _} -> to_string(k) end)
      |> Enum.map_join(",", fn {k, v} -> Jason.encode!(to_string(k)) <> ":" <> canonical(v) end)

    "{" <> inner <> "}"
  end

  defp canonical(list) when is_list(list),
    do: "[" <> Enum.map_join(list, ",", &canonical/1) <> "]"

  defp canonical(other), do: Jason.encode!(other)

  defp print(receipt) do
    for c <- receipt["checks"] do
      IO.puts("#{String.upcase(c["status"])}  #{c["id"]}  #{c["name"]}")
      if c["status"] == "fail", do: Enum.each(c["details"], &IO.puts("      - #{&1}"))
    end

    IO.puts(
      "#{receipt["verdict"]}  #{receipt["order"]}  receipt_sha256=#{receipt["receipt_sha256"]}"
    )
  end

  defp write_receipt(receipt, nil), do: exit_code(receipt)

  defp write_receipt(receipt, path) do
    path = Path.expand(path)

    with :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.write(path, Jason.encode!(receipt, pretty: true) <> "\n") do
      exit_code(receipt)
    else
      {:error, reason} ->
        IO.puts(:stderr, "COURT_COULD_NOT_RUN: cannot write receipt #{path}: #{inspect(reason)}")
        2
    end
  end

  defp exit_code(%{"verdict" => "ACCEPTED"}), do: 0
  defp exit_code(_), do: 1
end
