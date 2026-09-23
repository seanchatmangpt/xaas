defmodule Xaas.Sjira.ArdCourtTest do
  @moduledoc """
  Chicago-style qualification of `Xaas.Sjira.ArdCourt`: real files on disk, real RDF and TOML
  parsing, real sha256 pins, no mocks and no stubs. Every court check has a NEGATIVE witness:
  a good fixture is mutated in exactly one way and the court must refuse with that check id.

  The fixture is a tiny but complete package (public ontology, SHACL profile, ggen manifest,
  construction script, generated lib files). A final test judges the REAL ash-atlassian ARD
  against the real `~/ash_atlassian` and `~/ggen-marketplace` (named skip when absent).
  """
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Xaas.Sjira.ArdCourt

  @real_ard Path.expand("../../../docs/sjira/v26.9.21/ash-atlassian-ard.md", __DIR__)
  @real_ready File.dir?(Path.expand("~/ash_atlassian")) and
                File.dir?(Path.expand("~/ggen-marketplace/ontologies/public"))

  @thing "https://example.org/pub#Thing"
  @shape "https://example.org/shape#Thing"

  @sections ["Ontology source", "Resources", "Generator route", "Hand-written residue"] ++
              ["Non-goals", "Falsifiers", "Machine manifest"]

  # ------------------------------------------------------------------ fixture

  defp fixture do
    dir = Path.join(System.tmp_dir!(), "ard_court_#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf(dir) end)

    File.mkdir_p!(Path.join(dir, "pkg/lib/fixture"))
    File.mkdir_p!(Path.join(dir, "pkg/queries"))
    File.mkdir_p!(Path.join(dir, "pkg/templates"))
    File.mkdir_p!(Path.join(dir, "pack"))
    File.mkdir_p!(Path.join(dir, "owner-pack"))

    File.write!(Path.join(dir, "pub.ttl"), """
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
    @prefix pub: <https://example.org/pub#> .
    pub:Thing a rdfs:Class .
    pub:name a rdf:Property .
    """)

    File.write!(Path.join(dir, "profile.ttl"), """
    @prefix sh: <http://www.w3.org/ns/shacl#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
    @prefix pub: <https://example.org/pub#> .
    @prefix shape: <https://example.org/shape#> .
    shape:Thing a sh:NodeShape ;
      sh:name "Thing" ;
      sh:targetClass pub:Thing ;
      sh:property [ sh:path pub:name ; sh:name "name" ; sh:order 1 ; sh:datatype xsd:string ] .
    """)

    File.write!(Path.join(dir, "pkg/ggen.toml"), """
    [project]
    name = "fixture"
    version = "1.0.0"

    [ontology]
    source = "../profile.ttl"

    [generation]
    output_dir = "."

    [[generation.rules]]
    name = "construct"
    query = { file = "queries/q.rq" }
    template = { file = "templates/t.tera" }
    output_file = "generate.sh"

    [[generation.rules]]
    name = "semantic-map"
    query = { file = "queries/q.rq" }
    template = { file = "templates/t.tera" }
    output_file = "lib/fixture/semantics.ex"
    """)

    File.write!(Path.join(dir, "pkg/queries/q.rq"), "SELECT ?s WHERE { ?s ?p ?o } ORDER BY ?s\n")
    File.write!(Path.join(dir, "pkg/templates/t.tera"), "x\n")

    File.write!(Path.join(dir, "pkg/generate.sh"), """
    #!/usr/bin/env bash
    mix ash.gen.resource Fixture.Thing \\
      --domain Fixture --yes
    """)

    File.write!(Path.join(dir, "pkg/lib/fixture.ex"), "defmodule Fixture do\nend\n")
    File.write!(Path.join(dir, "pkg/lib/fixture/thing.ex"), "defmodule Fixture.Thing do\nend\n")

    File.write!(
      Path.join(dir, "pkg/lib/fixture/semantics.ex"),
      "defmodule Fixture.Semantics do\nend\n"
    )

    manifest = %{
      "order" => "SJ-TEST",
      "package" => %{"name" => "fixture", "root" => Path.join(dir, "pkg")},
      "ontology" => %{"source" => Path.join(dir, "profile.ttl"), "format" => "turtle"},
      "public_ontologies" => [
        %{
          "name" => "pub",
          "path" => Path.join(dir, "pub.ttl"),
          "format" => "turtle",
          "sha256" => sha(Path.join(dir, "pub.ttl"))
        }
      ],
      "generator" => %{
        "pack" => Path.join(dir, "pack"),
        "manifest" => Path.join(dir, "pkg/ggen.toml"),
        "construction_script" => Path.join(dir, "pkg/generate.sh")
      },
      "resources" => [
        %{
          "name" => "Thing",
          "module" => "Fixture.Thing",
          "shape" => @shape,
          "class" => @thing,
          "generator_route" => %{"rule" => "construct"},
          "handwritten" => false
        }
      ],
      "generated_files" => ["lib/fixture/semantics.ex"],
      "handwritten" => [
        %{
          "path" => "ggen.toml",
          "element" => "consumer-local generator manifest",
          "unsupported" => %{
            "kind" => "generator-capability",
            "missing_capability" => "the pack cannot render a manifest for another profile",
            "owner_pack" => "owner-pack",
            "owner_pack_path" => Path.join(dir, "owner-pack")
          }
        }
      ],
      "falsifiers" => [
        %{
          "id" => "F1",
          "kind" => "generator-coverage",
          "statement" => "a resource is hand-written where a pack could generate it",
          "check" => "mix xaas.sjira.ard_court"
        }
      ],
      "non_goals" => ["no transport"],
      "supersession_tripwires" => []
    }

    fx = %{dir: dir, ard: Path.join(dir, "ard.md"), manifest: manifest, sections: @sections}
    write_ard(fx)
    fx
  end

  defp write_ard(%{ard: ard, manifest: manifest, sections: sections}) do
    body =
      sections
      |> Enum.reject(&(&1 == "Machine manifest"))
      |> Enum.map_join("\n", &"## #{&1}\n\ntext\n")

    tail =
      if "Machine manifest" in sections,
        do:
          "\n## Machine manifest\n\n```json ard-manifest\n#{Jason.encode!(manifest, pretty: true)}\n```\n",
        else: ""

    File.write!(ard, "# ARD: fixture\n\n" <> body <> tail)
  end

  defp mutate(fx, fun) do
    fx = %{fx | manifest: fun.(fx.manifest)}
    write_ard(fx)
    fx
  end

  defp sha(path), do: :crypto.hash(:sha256, File.read!(path)) |> Base.encode16(case: :lower)

  defp judge!(fx) do
    assert {:ok, receipt} = ArdCourt.judge(fx.ard)
    receipt
  end

  defp failed(receipt) do
    for %{"status" => "fail", "id" => id, "details" => d} <- receipt["checks"],
        into: %{},
        do: {id, Enum.join(d, " | ")}
  end

  defp assert_refused(receipt, id, pattern) do
    assert receipt["verdict"] == "REFUSED"
    failures = failed(receipt)
    assert Map.has_key?(failures, id), "expected #{id} to fail, failures: #{inspect(failures)}"

    assert failures[id] =~ pattern,
           "#{id} detail #{inspect(failures[id])} did not match #{inspect(pattern)}"

    receipt
  end

  # ----------------------------------------------------------------- positive

  describe "a complete ARD" do
    test "is ACCEPTED, every check passes, and the receipt is written and replayable" do
      fx = fixture()
      receipt = judge!(fx)

      assert receipt["verdict"] == "ACCEPTED"
      assert receipt["counts"] == %{"pass" => 12, "fail" => 0}
      assert Enum.all?(receipt["checks"], &(&1["status"] == "pass"))
      assert receipt["ard"]["sha256"] == sha(fx.ard)

      assert receipt["subjects"]["ontology_source"]["sha256"] ==
               sha(Path.join(fx.dir, "profile.ttl"))

      # replay: the receipt identity is a pure function of the subjects (no clock in the hash)
      assert judge!(fx)["receipt_sha256"] == receipt["receipt_sha256"]

      out = Path.join(fx.dir, "receipts/out.json")
      capture_io(fn -> assert ArdCourt.cli([fx.ard, "--receipt", out]) == 0 end)
      written = out |> File.read!() |> Jason.decode!()
      assert written["verdict"] == "ACCEPTED"
      assert written["receipt_sha256"] == receipt["receipt_sha256"]
    end

    test "changing one byte of the ontology changes the receipt identity" do
      fx = fixture()
      before = judge!(fx)["receipt_sha256"]

      File.write!(
        Path.join(fx.dir, "profile.ttl"),
        File.read!(Path.join(fx.dir, "profile.ttl")) <> "\n# edit\n"
      )

      assert judge!(fx)["receipt_sha256"] != before
    end
  end

  # ------------------------------------------------------- the five listed laws

  describe "ontology source not named or not resolvable (ARD-003)" do
    test "source not named" do
      fx = fixture() |> mutate(&put_in(&1, ["ontology", "source"], nil))
      fx |> judge!() |> assert_refused("ARD-003", ~r/not named/)
    end

    test "source path does not exist" do
      fx = fixture()
      File.rm!(Path.join(fx.dir, "profile.ttl"))
      fx |> judge!() |> assert_refused("ARD-003", ~r/does not exist/)
    end

    test "source exists but is not RDF" do
      fx = fixture()
      File.write!(Path.join(fx.dir, "profile.ttl"), "this is { not turtle")
      fx |> judge!() |> assert_refused("ARD-003", ~r/does not parse/)
    end

    test "source parses but holds no SHACL node shape" do
      fx = fixture()

      File.write!(
        Path.join(fx.dir, "profile.ttl"),
        "@prefix pub: <https://example.org/pub#> .\npub:a pub:name \"x\" .\n"
      )

      fx |> judge!() |> assert_refused("ARD-003", ~r/no sh:NodeShape/)
    end
  end

  describe "resource without a generator route (ARD-008)" do
    test "resource has no generator_route" do
      fx =
        fixture()
        |> mutate(
          &update_in(&1, ["resources", Access.at(0)], fn r -> Map.delete(r, "generator_route") end)
        )

      fx |> judge!() |> assert_refused("ARD-008", ~r/Thing: no generator_route/)
    end

    test "route names a rule the ggen manifest does not declare" do
      fx =
        fixture()
        |> mutate(&put_in(&1, ["resources", Access.at(0), "generator_route", "rule"], "ghost"))

      fx |> judge!() |> assert_refused("ARD-008", ~r/rule "ghost" is not declared/)
    end

    test "the construction script never generates the resource" do
      fx = fixture()
      File.write!(Path.join(fx.dir, "pkg/generate.sh"), "#!/usr/bin/env bash\necho nothing\n")

      fx
      |> judge!()
      |> assert_refused("ARD-008", ~r/no `mix ash.gen.resource Fixture.Thing` line/)
    end

    test "a resource module that is only a prefix of a generated one does not count" do
      fx = fixture()

      File.write!(
        Path.join(fx.dir, "pkg/generate.sh"),
        "mix ash.gen.resource Fixture.ThingExtra --yes\n"
      )

      fx
      |> judge!()
      |> assert_refused("ARD-008", ~r/no `mix ash.gen.resource Fixture.Thing` line/)
    end

    test "resource is declared hand-written where a route exists" do
      fx = fixture() |> mutate(&put_in(&1, ["resources", Access.at(0), "handwritten"], true))
      fx |> judge!() |> assert_refused("ARD-008", ~r/hand-written resource/)
    end

    test "the ggen manifest reads a different ontology than the ARD names" do
      fx = fixture()
      File.write!(Path.join(fx.dir, "other.ttl"), File.read!(Path.join(fx.dir, "profile.ttl")))
      toml = Path.join(fx.dir, "pkg/ggen.toml")
      File.write!(toml, String.replace(File.read!(toml), "../profile.ttl", "../other.ttl"))
      fx |> judge!() |> assert_refused("ARD-008", ~r/ggen manifest reads/)
    end

    test "a rule's template file is missing" do
      fx = fixture()
      File.rm!(Path.join(fx.dir, "pkg/templates/t.tera"))
      fx |> judge!() |> assert_refused("ARD-008", ~r/template file missing/)
    end

    test "the ggen manifest does not exist" do
      fx = fixture()
      File.rm!(Path.join(fx.dir, "pkg/ggen.toml"))
      fx |> judge!() |> assert_refused("ARD-008", ~r/ggen manifest does not exist/)
    end

    test "the pack path does not exist" do
      fx = fixture()
      File.rm_rf!(Path.join(fx.dir, "pack"))
      fx |> judge!() |> assert_refused("ARD-008", ~r/generator.pack does not exist/)
    end
  end

  describe "hand-written product code without UNSUPPORTED(generator-capability) (ARD-009)" do
    test "an undeclared hand-written lib file appears" do
      fx = fixture()

      File.write!(
        Path.join(fx.dir, "pkg/lib/fixture/rogue.ex"),
        "defmodule Fixture.Rogue do\nend\n"
      )

      fx |> judge!() |> assert_refused("ARD-009", ~r/undeclared hand-written file.*rogue\.ex/)
    end

    test "declaring the rogue file without UNSUPPORTED is still refused" do
      fx = fixture()

      File.write!(
        Path.join(fx.dir, "pkg/lib/fixture/rogue.ex"),
        "defmodule Fixture.Rogue do\nend\n"
      )

      fx =
        mutate(fx, fn m ->
          Map.update!(
            m,
            "handwritten",
            &[%{"path" => "lib/fixture/rogue.ex", "element" => "rogue"} | &1]
          )
        end)

      fx |> judge!() |> assert_refused("ARD-009", ~r/missing UNSUPPORTED\(generator-capability\)/)
    end

    test "a wrong UNSUPPORTED kind is refused" do
      fx =
        fixture()
        |> mutate(&put_in(&1, ["handwritten", Access.at(0), "unsupported", "kind"], "todo"))

      fx |> judge!() |> assert_refused("ARD-009", ~r/missing UNSUPPORTED\(generator-capability\)/)
    end

    test "an UNSUPPORTED entry that names no missing capability is refused" do
      fx =
        fixture()
        |> mutate(
          &put_in(&1, ["handwritten", Access.at(0), "unsupported", "missing_capability"], "  ")
        )

      fx |> judge!() |> assert_refused("ARD-009", ~r/names no missing capability/)
    end

    test "an UNSUPPORTED entry whose owner pack does not exist is refused" do
      fx = fixture()
      File.rm_rf!(Path.join(fx.dir, "owner-pack"))
      fx |> judge!() |> assert_refused("ARD-009", ~r/owner pack does not exist/)
    end

    test "a file claimed as ggen-generated that no ggen rule outputs is refused" do
      fx =
        fixture()
        |> mutate(&Map.update!(&1, "generated_files", fn g -> g ++ ["lib/fixture/thing.ex"] end))

      fx
      |> judge!()
      |> assert_refused("ARD-009", ~r/claimed generated but no ggen rule outputs it/)
    end

    test "a resource file that was never generated is refused" do
      fx = fixture()
      File.rm!(Path.join(fx.dir, "pkg/lib/fixture/thing.ex"))

      fx
      |> judge!()
      |> assert_refused("ARD-009", ~r/generated file missing: lib\/fixture\/thing\.ex/)
    end

    test "a ggen-declared output that is missing on disk is refused" do
      fx = fixture()
      File.rm!(Path.join(fx.dir, "pkg/lib/fixture/semantics.ex"))

      fx
      |> judge!()
      |> assert_refused("ARD-009", ~r/generated file missing: lib\/fixture\/semantics\.ex/)
    end

    test "a residue entry whose path matches no file is refused" do
      fx = fixture() |> mutate(&put_in(&1, ["handwritten", Access.at(0), "path"], "nope.toml"))
      fx |> judge!() |> assert_refused("ARD-009", ~r/path matches no file/)
    end
  end

  describe "falsifiers (ARD-010)" do
    test "no falsifiers" do
      fx = fixture() |> mutate(&Map.put(&1, "falsifiers", []))
      fx |> judge!() |> assert_refused("ARD-010", ~r/no falsifiers declared/)
    end

    test "a falsifier with no runnable check" do
      fx = fixture() |> mutate(&put_in(&1, ["falsifiers", Access.at(0), "check"], ""))
      fx |> judge!() |> assert_refused("ARD-010", ~r/needs id, statement and check/)
    end

    test "no generator-coverage falsifier" do
      fx = fixture() |> mutate(&put_in(&1, ["falsifiers", Access.at(0), "kind"], "other"))
      fx |> judge!() |> assert_refused("ARD-010", ~r/generator-coverage/)
    end

    test "duplicate falsifier ids" do
      fx = fixture() |> mutate(&Map.update!(&1, "falsifiers", fn [f] -> [f, f] end))
      fx |> judge!() |> assert_refused("ARD-010", ~r/repeated/)
    end
  end

  describe "referenced ontology or pack path does not exist (ARD-004)" do
    test "public ontology file missing" do
      fx = fixture()
      File.rm!(Path.join(fx.dir, "pub.ttl"))
      fx |> judge!() |> assert_refused("ARD-004", ~r/does not exist/)
    end

    test "public ontology drifted from its pin" do
      fx = fixture()

      File.write!(
        Path.join(fx.dir, "pub.ttl"),
        File.read!(Path.join(fx.dir, "pub.ttl")) <> "\n# drift\n"
      )

      fx |> judge!() |> assert_refused("ARD-004", ~r/sha256 drift/)
    end

    test "public ontology not pinned" do
      fx =
        fixture()
        |> mutate(
          &update_in(&1, ["public_ontologies", Access.at(0)], fn e -> Map.delete(e, "sha256") end)
        )

      fx |> judge!() |> assert_refused("ARD-004", ~r/sha256 not pinned/)
    end

    test "no public ontologies declared" do
      fx = fixture() |> mutate(&Map.put(&1, "public_ontologies", []))
      fx |> judge!() |> assert_refused("ARD-004", ~r/no public_ontologies declared/)
    end
  end

  # ------------------------------------------------------- the remaining laws

  describe "public term resolution (ARD-006) and no local vocabulary (ARD-007)" do
    test "a target class that no pinned public ontology declares" do
      fx = fixture()
      profile = Path.join(fx.dir, "profile.ttl")

      File.write!(
        profile,
        String.replace(
          File.read!(profile),
          "sh:targetClass pub:Thing",
          "sh:targetClass pub:Ghost"
        )
      )

      fx =
        mutate(
          fx,
          &put_in(&1, ["resources", Access.at(0), "class"], "https://example.org/pub#Ghost")
        )

      fx |> judge!() |> assert_refused("ARD-006", ~r/pub#Ghost is not a declared class/)
    end

    test "a property path that no pinned public ontology declares" do
      fx = fixture()
      profile = Path.join(fx.dir, "profile.ttl")

      File.write!(
        profile,
        String.replace(File.read!(profile), "sh:path pub:name", "sh:path pub:ghost")
      )

      fx |> judge!() |> assert_refused("ARD-006", ~r/pub#ghost is not a declared property/)
    end

    test "a class term used where a property is required is not accepted" do
      fx = fixture()
      profile = Path.join(fx.dir, "profile.ttl")

      File.write!(
        profile,
        String.replace(File.read!(profile), "sh:path pub:name", "sh:path pub:Thing")
      )

      fx |> judge!() |> assert_refused("ARD-006", ~r/pub#Thing is not a declared property/)
    end

    test "the profile invents a local class" do
      fx = fixture()
      profile = Path.join(fx.dir, "profile.ttl")

      File.write!(
        profile,
        File.read!(profile) <>
          "\n@prefix owl: <http://www.w3.org/2002/07/owl#> .\nshape:Invented a owl:Class .\n"
      )

      fx |> judge!() |> assert_refused("ARD-007", ~r/local vocabulary declared.*Invented/)
    end
  end

  describe "resources versus shapes (ARD-005)" do
    test "an ontology shape with no resource entry" do
      fx = fixture()
      profile = Path.join(fx.dir, "profile.ttl")

      File.write!(
        profile,
        File.read!(profile) <> "\nshape:Extra a sh:NodeShape ; sh:targetClass pub:Thing .\n"
      )

      fx |> judge!() |> assert_refused("ARD-005", ~r/shape .*Extra has no resource entry/)
    end

    test "a resource whose class disagrees with the ontology" do
      fx =
        fixture()
        |> mutate(
          &put_in(&1, ["resources", Access.at(0), "class"], "https://example.org/pub#Other")
        )

      fx |> judge!() |> assert_refused("ARD-005", ~r/differs from the ontology target class/)
    end

    test "a resource pointing at a shape the ontology does not hold" do
      fx =
        fixture()
        |> mutate(
          &put_in(&1, ["resources", Access.at(0), "shape"], "https://example.org/shape#Nope")
        )

      fx |> judge!() |> assert_refused("ARD-005", ~r/is not a sh:NodeShape/)
    end

    test "no resources" do
      fx = fixture() |> mutate(&Map.put(&1, "resources", []))
      fx |> judge!() |> assert_refused("ARD-005", ~r/no resources declared/)
    end
  end

  describe "non-goals (ARD-011) and supersession tripwires (ARD-012)" do
    test "no non-goals" do
      fx = fixture() |> mutate(&Map.put(&1, "non_goals", []))
      fx |> judge!() |> assert_refused("ARD-011", ~r/non_goals/)
    end

    test "a tripwire that has not fired passes" do
      fx =
        fixture()
        |> mutate(fn m ->
          Map.put(m, "supersession_tripwires", [
            %{
              "path" => "/nonexistent/lock.toml",
              "shape" => @shape,
              "must_target" => "https://example.org/pub#Better"
            }
          ])
        end)

      assert judge!(fx)["verdict"] == "ACCEPTED"
    end

    test "a tripwire whose better prior art has appeared refuses the stale ARD" do
      fx = fixture()
      lock = Path.join(fx.dir, "better.lock.toml")
      File.write!(lock, "[lock]\nname = \"better\"\n")

      fx =
        mutate(fx, fn m ->
          Map.put(m, "supersession_tripwires", [
            %{
              "path" => lock,
              "shape" => @shape,
              "must_target" => "https://example.org/pub#Better"
            }
          ])
        end)

      fx |> judge!() |> assert_refused("ARD-012", ~r/superseded/)
    end
  end

  describe "structure (ARD-001, ARD-002) and failure containment" do
    test "a missing required section" do
      fx = fixture()
      fx = %{fx | sections: List.delete(fx.sections, "Non-goals")}
      write_ard(fx)
      fx |> judge!() |> assert_refused("ARD-001", ~r/missing section: ## Non-goals/)
    end

    test "no machine manifest: every dependent check fails, none passes on doubt" do
      fx = fixture()
      fx = %{fx | sections: List.delete(fx.sections, "Machine manifest")}
      write_ard(fx)
      receipt = judge!(fx)
      assert receipt["verdict"] == "REFUSED"
      failures = failed(receipt)
      assert failures["ARD-002"] =~ "no ```json ard-manifest"

      for id <-
            ~w(ARD-003 ARD-004 ARD-005 ARD-006 ARD-007 ARD-008 ARD-009 ARD-010 ARD-011 ARD-012) do
        assert failures[id] =~ "no parsed machine manifest", "#{id} did not fail closed"
      end
    end

    test "a malformed manifest is refused, not a crash" do
      fx = fixture()
      File.write!(fx.ard, "## Machine manifest\n\n```json ard-manifest\n{ not json\n```\n")
      assert_refused(judge!(fx), "ARD-002", ~r/not valid JSON/)
    end

    test "type-confused manifest fields fail their checks instead of crashing the court" do
      fx =
        fixture()
        |> mutate(fn m ->
          m
          |> Map.put("generator", "a string, not an object")
          |> Map.put("resources", ["not an object"])
          |> Map.put("handwritten", [42])
          |> Map.put("public_ontologies", ["nope"])
        end)

      receipt = judge!(fx)
      assert receipt["verdict"] == "REFUSED"
      failures = failed(receipt)

      for id <- ~w(ARD-004 ARD-005 ARD-008 ARD-009),
          do: assert(Map.has_key?(failures, id), "#{id} should fail")
    end
  end

  describe "cli exit codes" do
    test "0 accepted, 1 refused, 2 could not run" do
      fx = fixture()
      capture_io(fn -> assert ArdCourt.cli([fx.ard]) == 0 end)

      refused = fx |> mutate(&Map.put(&1, "non_goals", []))
      out = capture_io(fn -> assert ArdCourt.cli([refused.ard]) == 1 end)
      assert out =~ "FAIL  ARD-011"
      assert out =~ "REFUSED"

      capture_io(:stderr, fn -> assert ArdCourt.cli([Path.join(fx.dir, "missing.md")]) == 2 end)
      capture_io(:stderr, fn -> assert ArdCourt.cli([]) == 2 end)
      capture_io(:stderr, fn -> assert ArdCourt.cli([fx.ard, "--bogus"]) == 2 end)
    end

    test "an unwritable receipt path is exit 2, never a silent pass" do
      fx = fixture()
      blocker = Path.join(fx.dir, "blocker")
      File.write!(blocker, "a file, not a directory")

      capture_io(:stderr, fn ->
        capture_io(fn ->
          assert ArdCourt.cli([fx.ard, "--receipt", Path.join(blocker, "r.json")]) == 2
        end)
      end)
    end
  end

  # ----------------------------------------------------------- the real ARD

  describe "the real ash-atlassian ARD" do
    @describetag skip:
                   if(@real_ready,
                     do: false,
                     else: "~/ash_atlassian or ~/ggen-marketplace not present"
                   )

    test "is ACCEPTED against the real package, ontology, pins and generator" do
      assert {:ok, receipt} = ArdCourt.judge(@real_ard)
      assert receipt["order"] == "SJ-007"
      assert failed(receipt) == %{}
      assert receipt["verdict"] == "ACCEPTED"
      assert receipt["counts"] == %{"pass" => 12, "fail" => 0}
    end

    test "is REFUSED when the real ontology loses its identity binding to a public term" do
      # Negative witness on the REAL artifacts, done on copies so the package is never touched.
      dir = Path.join(System.tmp_dir!(), "ard_real_#{System.unique_integer([:positive])}")
      on_exit(fn -> File.rm_rf(dir) end)
      File.mkdir_p!(dir)

      ard = File.read!(@real_ard)
      profile = File.read!(Path.expand("~/ash_atlassian/ontology/atlassian-profile.ttl"))

      broken =
        String.replace(profile, "schema:alternateName", "schema:notARealTerm", global: false)

      broken_path = Path.join(dir, "profile.ttl")
      File.write!(broken_path, broken)

      copy = Path.join(dir, "ard.md")

      File.write!(
        copy,
        String.replace(ard, "~/ash_atlassian/ontology/atlassian-profile.ttl", broken_path)
      )

      assert {:ok, receipt} = ArdCourt.judge(copy)
      assert receipt["verdict"] == "REFUSED"
      assert Map.has_key?(failed(receipt), "ARD-006")
      assert failed(receipt)["ARD-006"] =~ "notARealTerm"
    end
  end
end
