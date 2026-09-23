defmodule Xaas.Ultracode.MachineExperienceTest do
  @moduledoc """
  Chicago qualification of the MachineExperience router, generalization,
  admission and exploration budget (`Xaas.Ultracode.MachineExperience`,
  `Xaas.Ultracode.MachineExperience.Exploration`; GC-26.9.23 GC23-9, PRD
  PR-014/PR-016, ARD section 15).

  Real collaborators only: the real RDF.ex Turtle reader and SPARQL.ex
  engine over the real rendered order and experience graphs, the committed
  reference episode's real OCEL log (docs/sjira/v26.9.23/episodes/fmt-1),
  the real `Xaas.Ultracode.Ocel.Validator`, and real
  `mix xaas.machine_experience` OS processes under the F3 no-LLM court
  environment (`docs/sjira/v26.9.23/courts/no_llm_env.sh`). The experience
  records here are plain data in the exact key set ggen_igniter's
  `SemanticJira.machine_experience/1` emits; the end-to-end module below
  manufactures them with the real function.
  """

  use ExUnit.Case, async: true

  alias Xaas.Ultracode.MachineExperience
  alias Xaas.Ultracode.MachineExperience.{Episode, Exploration}
  alias Xaas.Ultracode.Ocel.Validator
  alias Xaas.Ultracode.SemanticDrive.Ocel

  @no_llm_env Path.expand("../../../docs/sjira/v26.9.23/courts/no_llm_env.sh", __DIR__)
  @fmt1 Path.expand("../../../docs/sjira/v26.9.23/episodes/fmt-1", __DIR__)

  defp row(overrides \\ %{}) do
    Map.merge(
      %{
        "identity" => "EP-A",
        "subject" => "seanchatmangpt/ggen_igniter@v23/episode-me-x#EP-A",
        "repository" => "seanchatmangpt/ggen_igniter",
        "base_sha" => String.duplicate("a", 40),
        "failure_class" => "format_drift",
        "consequence_class" => "postcondition",
        "authority_ceiling" => "CONSTRUCT",
        "evidence_ceiling" => "repository-local",
        "evidence_horizon" => "exact-head run of the format court",
        "path_scope" => ["lib", "test"],
        "exclusions" => ["no LLM provider on the KNOWN path"],
        "required_evidence" => ["https://ggen-igniter.dev/sjira/v26.9.23#evidence-x"],
        "falsifiers" => ["https://ggen-igniter.dev/sjira/v26.9.23#falsifier-x"],
        "replay_identity" => "semantic-jira:v26.9.23:episode:me-x:EP-A",
        "standing" => "UNKNOWN"
      },
      overrides
    )
  end

  defp digest(label), do: MachineExperience.sha256(label)

  # the exact key set GgenIgniter.SemanticJira.machine_experience/1 returns
  defp experience(label \\ "x") do
    %{
      "kind" => "MachineExperience",
      "subject" => "seanchatmangpt/ggen_igniter@v23/episode-me-x#EP-A",
      "work_order_digest" => digest("wo-" <> label),
      "execution_receipt_hash" => digest("receipt-" <> label),
      "observation_refs" => ["drive/receipt.json", "drive/verification.json"],
      "verification_digest" => digest("verification-" <> label),
      "resulting_state_digest" => digest("state-" <> label),
      "replay_identity" => "semantic-jira:v26.9.23:episode:me-x:EP-A",
      "standing" => "CANDIDATE",
      "authority" => "NONE",
      "experience_digest" => digest("experience-" <> label)
    }
  end

  defp evidence(overrides \\ %{}) do
    Map.merge(
      %{
        "drive" => %{
          "standing" => "ALIVE",
          "provider" => %{
            "provider" => "recipe",
            "executor" => "recipe-worker",
            "capability" => "recipe:mix-format"
          },
          "subject" => %{"head" => String.duplicate("b", 40)},
          "frontier" => %{"left" => ["EP-A"], "entered" => ["EP-B"]},
          "transition" => %{"event_digest" => digest("event")}
        },
        "verification" => %{
          "head" => String.duplicate("b", 40),
          "independent" => %{"status" => "pass", "suite" => "ggen-igniter-format"},
          "revert_falsifier" => %{"verdict" => "killed"}
        },
        "receipt" => %{"receipt_digest" => digest("receipt"), "outcome" => "alive"},
        "r" => %{"standing" => %{"value" => "ALIVE"}},
        "hops" => %{
          "hops" => [%{"hop" => "sjira", "request" => %{"graph_digest" => digest("graph")}}]
        },
        "exploration" => %{
          "digest" => digest("exploration"),
          "budget" => %{
            "time_s" => 600,
            "drive_runs" => 1,
            "candidates" => 1,
            "consequence_ceiling" => "CONSTRUCT",
            "evidence_requirement" => Exploration.evidence_kinds()
          },
          "used" => %{"drive_runs" => 1, "candidates" => 1, "elapsed_s" => 42}
        }
      },
      overrides
    )
  end

  defp admitted_ttl!(source_row \\ row(), label \\ "x", capability \\ nil) do
    ev =
      if capability,
        do: put_in(evidence(), ["drive", "provider", "capability"], capability),
        else: evidence()

    {:ok, fields} =
      MachineExperience.generalize(source_row, ev, %{
        "episode" => "me-x",
        "order" => source_row["replay_identity"],
        "exploration_digest" => digest("exploration")
      })

    {:ok, admission} = MachineExperience.admit(experience(label), fields, source_row, ev)
    MachineExperience.to_turtle(experience(label), admission)
  end

  defp graph!(ttl) do
    {:ok, graph} = RDF.Turtle.read_string(ttl)
    graph
  end

  defp without_subject(ttl, iri) do
    graph = graph!(ttl)
    RDF.Graph.delete_descriptions(graph, RDF.iri(iri))
  end

  describe "applicability predicate (generalized from the source order, evaluated by SPARQL.ex)" do
    test "selects the source order and an equivalent order on another subject; nothing else" do
      {:ok, predicate} = MachineExperience.applicability_predicate(row())

      assert {:ok, true} = MachineExperience.applicability(predicate, row())

      other_subject =
        row(%{
          "subject" => "seanchatmangpt/ggen_igniter@v23/episode-me-y#EP-A",
          "base_sha" => String.duplicate("c", 40),
          "replay_identity" => "semantic-jira:v26.9.23:episode:me-y:EP-A"
        })

      assert {:ok, true} = MachineExperience.applicability(predicate, other_subject)

      for excluded <- [
            row(%{"failure_class" => "compile_error"}),
            row(%{"repository" => "seanchatmangpt/xaas"}),
            row(%{"authority_ceiling" => "DO"}),
            row(%{"requires_capability" => "recipe:mix-format"})
          ] do
        assert {:ok, false} = MachineExperience.applicability(predicate, excluded)
      end
    end

    test "a predicate that cannot be judged is a typed error, never 'does not apply'" do
      assert {:error,
              %{"kind" => "sparql_error", "error" => "SPARQL language scanner error" <> _}} =
               MachineExperience.applicability("SELECT nonsense", row())

      assert {:error, %{"kind" => "select_without_order", "variables" => ["x"]}} =
               MachineExperience.applicability("SELECT ?x WHERE { ?x ?p ?o }", row())

      assert {:error, %{"kind" => "not_a_select_result"}} =
               MachineExperience.applicability("CONSTRUCT { ?s ?p ?o } WHERE { ?s ?p ?o }", row())

      assert {:error, %{"kind" => "predicate_not_a_string"}} =
               MachineExperience.applicability(nil, row())
    end

    test "an order without a failure class has nothing to generalize over" do
      assert {:refused, %{"reason" => "problem_class_absent", "broken_term" => "mu_on_O"}} =
               MachineExperience.applicability_predicate(Map.delete(row(), "failure_class"))
    end

    test "consequence bounds contain the source order and refuse a wider one" do
      bounds = MachineExperience.consequence_bounds(row())
      assert MachineExperience.within_bounds?(bounds, row())
      assert MachineExperience.within_bounds?(bounds, row(%{"path_scope" => ["lib"]}))
      refute MachineExperience.within_bounds?(bounds, row(%{"path_scope" => ["lib", "priv"]}))
      refute MachineExperience.within_bounds?(bounds, row(%{"path_scope" => []}))
      refute MachineExperience.within_bounds?(bounds, row(%{"exclusions" => []}))
      refute MachineExperience.within_bounds?(bounds, row(%{"authority_ceiling" => "DO"}))
    end
  end

  describe "admission (MachineExperience.admit/4)" do
    setup do
      {:ok, fields} =
        MachineExperience.generalize(row(), evidence(), %{
          "episode" => "me-x",
          "order" => row()["replay_identity"],
          "exploration_digest" => digest("exploration")
        })

      %{fields: fields}
    end

    test "admits a verified record: every ARD section 15 field, a digest over fields + experience",
         %{fields: fields} do
      assert {:ok, admission} = MachineExperience.admit(experience(), fields, row(), evidence())
      assert admission["admission"] == "ADMITTED"
      assert admission["admitted_capability"] == "recipe:mix-format"
      assert admission["provider_class"] == "recipe"
      assert admission["problem_class"] == "format_drift"
      assert admission["source_episode"] == "me-x"
      assert admission["admission_digest"] =~ ~r/\Asha256:[0-9a-f]{64}\z/

      for field <- MachineExperience.ard_fields() do
        assert admission[field] not in [nil, "", []], field
      end

      assert {:ok, ^admission} = MachineExperience.admit(experience(), fields, row(), evidence())

      assert {:ok, other} =
               MachineExperience.admit(experience("y"), fields, row(), evidence())

      assert other["admission_digest"] != admission["admission_digest"]
    end

    test "refuses what was not verified, not a candidate, or does not cover its own source",
         %{fields: fields} do
      refused = fn experience, fields, row, evidence ->
        {:refused, %{"reason" => reason, "broken_term" => "admission_vacuous"}} =
          MachineExperience.admit(experience, fields, row, evidence)

        reason
      end

      assert refused.(Map.put(experience(), "standing", "ALIVE"), fields, row(), evidence()) ==
               "experience_not_candidate"

      assert refused.(Map.put(experience(), "extra", "x"), fields, row(), evidence()) ==
               "experience_fields_unmapped"

      assert refused.(
               Map.put(experience(), "experience_digest", "sha256:zz"),
               fields,
               row(),
               evidence()
             ) == "experience_digest_malformed"

      assert refused.(experience(), Map.put(fields, "falsifiers", []), row(), evidence()) ==
               "ard_field_missing"

      assert refused.(
               experience(),
               Map.put(fields, "admitted_capability", "Write"),
               row(),
               evidence()
             ) == "invalid_capability"

      assert refused.(
               experience(),
               fields,
               row(%{"failure_class" => "compile_error"}),
               evidence()
             ) == "predicate_excludes_source"

      assert refused.(
               experience(),
               Map.put(fields, "applicability_predicate", "SELECT nonsense"),
               row(),
               evidence()
             ) == "predicate_unevaluable"

      assert refused.(
               experience(),
               fields,
               row(%{"path_scope" => ["priv"]}),
               evidence()
             ) == "bounds_exclude_source"

      assert refused.(
               experience(),
               fields,
               row(),
               put_in(evidence(), ["drive", "standing"], "PARTIAL_ALIVE")
             ) == "source_not_alive"

      assert refused.(
               experience(),
               fields,
               row(),
               put_in(evidence(), ["verification", "revert_falsifier", "verdict"], "survived")
             ) == "source_unverified"
    end

    test "refuses an experience whose exploration is unrecorded, unbound or over budget (PR-016)",
         %{fields: fields} do
      refused = fn fields, evidence ->
        {:refused,
         %{"reason" => reason, "broken_term" => "admission_vacuous", "detail" => detail}} =
          MachineExperience.admit(experience(), fields, row(), evidence)

        {reason, detail}
      end

      assert {"exploration_unrecorded", _} =
               refused.(fields, Map.delete(evidence(), "exploration"))

      assert {"exploration_unrecorded", _} =
               refused.(Map.delete(fields, "source_exploration"), evidence())

      assert {"exploration_unbound", %{"exploration_digest" => "sha256:" <> _}} =
               refused.(fields, put_in(evidence(), ["exploration", "digest"], digest("other")))

      # the doctrine case: proposal time inside the budget, the drive overran it
      assert {"exploration_over_budget",
              %{"exhausted" => "time_s", "used" => %{"elapsed_s" => 601}}} =
               refused.(fields, put_in(evidence(), ["exploration", "used", "elapsed_s"], 601))

      assert {"exploration_over_budget", %{"exhausted" => "drive_runs"}} =
               refused.(fields, put_in(evidence(), ["exploration", "used", "drive_runs"], 2))

      assert {"exploration_over_budget", %{"exhausted" => "time_s"}} =
               refused.(
                 fields,
                 put_in(evidence(), ["exploration", "used"], %{
                   "drive_runs" => 1,
                   "candidates" => 1
                 })
               )

      # exactly at the budget is within it
      assert {:ok, _} =
               MachineExperience.admit(
                 experience(),
                 fields,
                 row(),
                 put_in(evidence(), ["exploration", "used", "elapsed_s"], 600)
               )
    end
  end

  describe "router (MachineExperience.route/2)" do
    test "UNKNOWN with no capability and no experience; KNOWN from a declared capability; refused when malformed" do
      assert {:unknown,
              %{
                "standing" => "UNKNOWN",
                "reason" => "no_capability_no_experience",
                "detail" => %{"experiences_considered" => []}
              }} = MachineExperience.route(row(), nil)

      assert {:unknown, %{"reason" => "no_capability_no_experience"}} =
               MachineExperience.route(row(), RDF.Graph.new())

      assert {:known, %{"source" => "requires_capability", "capability" => "recipe:mix-format"}} =
               MachineExperience.route(row(%{"requires_capability" => "recipe:mix-format"}))

      assert {:refused, %{"reason" => "invalid_capability"}} =
               MachineExperience.route(row(%{"requires_capability" => "Write"}))
    end

    test "KNOWN from the admitted experience by IRI on a different subject; UNKNOWN once the experience or its admission is removed" do
      ttl = admitted_ttl!()
      graph = graph!(ttl)
      [experience] = MachineExperience.experiences(graph)
      iri = experience["machine_experience"]
      assert iri == MachineExperience.iri(experience())

      episode2 =
        row(%{
          "subject" => "seanchatmangpt/ggen_igniter@v23/episode-me-y#EP-A",
          "replay_identity" => "semantic-jira:v26.9.23:episode:me-y:EP-A"
        })

      assert {:known, route} = MachineExperience.route(episode2, graph)
      assert route["source"] == "machine_experience"
      assert route["machine_experience"] == iri
      assert route["admission"] == iri <> "-admission"
      assert route["capability"] == experience["admitted_capability"]
      assert route["experience_digest"] == experience()["experience_digest"]
      refute Map.has_key?(episode2, "requires_capability")

      # falsifier: the route exists only because the admitted experience does
      assert {:unknown, %{"reason" => "no_capability_no_experience"}} =
               MachineExperience.route(episode2, without_subject(ttl, iri))

      assert {:unknown, %{"reason" => "no_capability_no_experience"}} =
               MachineExperience.route(episode2, without_subject(ttl, iri <> "-admission"))

      # the capability comes from the graph: rewrite it there and the route follows
      rewritten =
        ttl
        |> String.replace(
          ~s(xme:admittedCapability "recipe:mix-format"),
          ~s(xme:admittedCapability "recipe:other-fix")
        )
        |> graph!()

      assert {:known, %{"capability" => "recipe:other-fix", "machine_experience" => ^iri}} =
               MachineExperience.route(episode2, rewritten)

      # a different failure class or a wider consequence stays UNKNOWN
      assert {:unknown,
              %{"detail" => %{"experiences_considered" => [^iri], "experiences_applicable" => []}}} =
               MachineExperience.route(%{episode2 | "failure_class" => "compile_error"}, graph)

      assert {:unknown, %{"reason" => "no_capability_no_experience"}} =
               MachineExperience.route(%{episode2 | "path_scope" => ["lib", "priv"]}, graph)
    end

    test "an admitted experience whose predicate cannot be evaluated refuses the route (fails closed), naming it" do
      ttl = admitted_ttl!()
      graph = graph!(ttl)
      [experience] = MachineExperience.experiences(graph)
      admission = RDF.iri(experience["admission"])
      predicate = RDF.iri(MachineExperience.namespaces()["xme"] <> "applicabilityPredicate")

      broken =
        graph
        |> RDF.Graph.delete(
          {admission, predicate, RDF.literal(experience["applicability_predicate"])}
        )
        |> RDF.Graph.add({admission, predicate, RDF.literal("SELECT nonsense")})

      assert [%{"applicability_predicate" => "SELECT nonsense"}] =
               MachineExperience.experiences(broken)

      assert {:refused,
              %{
                "standing" => "REFUSED(experience_predicate_unevaluable)",
                "reason" => "experience_predicate_unevaluable",
                "broken_term" => "mu_on_O",
                "hop" => "route",
                "detail" => %{
                  "machine_experience" => iri,
                  "error" => %{"kind" => "sparql_error"}
                }
              }} = MachineExperience.route(row(), broken)

      assert iri == experience["machine_experience"]

      # beside a sound experience the broken one still refuses: it might apply
      two = RDF.Graph.add(broken, graph!(admitted_ttl!(row(), "y")))
      assert length(MachineExperience.experiences(two)) == 2

      assert {:refused, %{"reason" => "experience_predicate_unevaluable"}} =
               MachineExperience.route(row(), two)
    end

    test "two applicable experiences naming different capabilities are ambiguous (UNKNOWN)" do
      graph =
        RDF.Graph.add(
          graph!(admitted_ttl!(row(), "x")),
          graph!(admitted_ttl!(row(), "y", "recipe:other-fix"))
        )

      assert length(MachineExperience.experiences(graph)) == 2

      assert {:unknown,
              %{
                "reason" => "ambiguous_experience",
                "detail" => %{"capabilities" => ["recipe:mix-format", "recipe:other-fix"]}
              }} = MachineExperience.route(row(), graph)
    end

    test "the Turtle is deterministic, parses, and the ME node carries exactly the ggen_igniter fields" do
      ttl = admitted_ttl!()
      assert ttl == admitted_ttl!()
      graph = graph!(ttl)
      me = RDF.iri(MachineExperience.iri(experience()))
      description = RDF.Graph.description(graph, me)

      properties =
        description
        |> RDF.Description.predicates()
        |> Enum.map(&to_string/1)
        |> Enum.map(&(&1 |> String.split(["#"]) |> List.last()))
        |> Enum.sort()

      assert properties ==
               Enum.sort(
                 ~w(type label subject workOrderDigest executionReceiptHash observationRef verificationDigest resultingStateDigest replayIdentity standing authorityClaim experienceDigest)
               )

      assert MachineExperience.order_turtle(row()) =~ "xme:failureClass \"format_drift\""
      refute MachineExperience.order_turtle(row()) =~ "requiresCapability"
    end
  end

  describe "bounded exploration (Exploration)" do
    defp exploration(overrides \\ %{}) do
      Map.merge(
        %{
          "schema" => Exploration.schema(),
          "order" => "EP-A",
          "problem_class" => "format_drift",
          "producer" => "test:chicago-fixture",
          "producer_class" => "test",
          "started_at" => "2026-09-23T10:00:00Z",
          "finished_at" => "2026-09-23T10:01:00Z",
          "budget" => %{
            "time_s" => 600,
            "drive_runs" => 1,
            "candidates" => 2,
            "consequence_ceiling" => "CONSTRUCT",
            "evidence_requirement" => Exploration.evidence_kinds()
          },
          "candidates" => [
            %{"capability" => "recipe:mix-format", "authority_ceiling" => "CONSTRUCT"},
            %{"capability" => "recipe:deploy", "authority_ceiling" => "DO"},
            %{"capability" => "recipe:third", "authority_ceiling" => "CONSTRUCT"}
          ]
        },
        overrides
      )
    end

    test "admits within budget: over-ceiling candidates rejected, the rest truncated" do
      assert {:ok, plan} = Exploration.admit(exploration(), row(), digest("e"))
      assert plan["proposal_elapsed_s"] == 60
      assert Enum.map(plan["candidates"], & &1["capability"]) == ["recipe:mix-format"]

      assert [%{"reason" => "candidate_exceeds_consequence_ceiling"}] = plan["rejected"]
      assert [%{"capability" => "recipe:third"}] = plan["truncated"]
      assert plan["digest"] == digest("e")
    end

    test "refuses an artifact without an explicit budget, for another order or over its time" do
      for {overrides, field} <- [
            {%{"budget" => Map.delete(exploration()["budget"], "drive_runs")},
             "budget.drive_runs"},
            {%{"budget" => Map.delete(exploration()["budget"], "consequence_ceiling")},
             "budget.consequence_ceiling"},
            {%{"budget" => Map.put(exploration()["budget"], "evidence_requirement", [])},
             "budget.evidence_requirement"},
            {%{"order" => "EP-B"}, "order"},
            {%{"problem_class" => "compile_error"}, "problem_class"},
            {%{"producer" => " "}, "producer"},
            {%{"finished_at" => "2026-09-23T11:00:01Z"}, "time_s_exceeded_by_proposal"},
            {%{"candidates" => []}, "candidates"}
          ] do
        assert {:refused,
                %{
                  "standing" => "REFUSED(exploration_inadmissible)",
                  "broken_term" => "mu_on_O",
                  "detail" => %{"field" => ^field}
                }} = Exploration.admit(exploration(overrides), row(), digest("e")),
               field
      end
    end

    test "the budget meters drives and time; exhaustion is a typed UNKNOWN; evidence gates resolution" do
      {:ok, plan} = Exploration.admit(exploration(), row(), digest("e"))
      assert :ok = Exploration.next(plan, %{"drive_runs" => 0, "elapsed_s" => 60})

      assert {:exhausted, "drive_runs"} =
               Exploration.next(plan, %{"drive_runs" => 1, "elapsed_s" => 60})

      assert {:exhausted, "time_s"} =
               Exploration.next(plan, %{"drive_runs" => 0, "elapsed_s" => 600})

      assert %{
               "standing" => "UNKNOWN",
               "reason" => "exploration_budget_exhausted",
               "detail" => %{"exhausted" => "drive_runs", "exploration_digest" => "sha256:" <> _}
             } = Exploration.exhausted(plan, "drive_runs", %{"drive_runs" => 1}, [])

      shown = Exploration.evidence(evidence())
      assert Enum.sort(shown) == Enum.sort(Exploration.evidence_kinds())
      assert Exploration.resolved?(plan, shown)

      killed_not =
        Exploration.evidence(
          put_in(evidence(), ["verification", "revert_falsifier", "verdict"], "survived")
        )

      refute Exploration.resolved?(plan, killed_not)
    end

    test "after a drive the budget is metered again: within means <= on every dimension" do
      {:ok, plan} = Exploration.admit(exploration(), row(), digest("e"))
      within = %{"drive_runs" => 1, "candidates" => 1, "elapsed_s" => 600}
      assert :ok = Exploration.within_budget(plan, within)

      # proposal 60 s passed the pre-drive check (60 < 600); the drive took 541 s
      assert {:exhausted, "time_s"} =
               Exploration.within_budget(plan, %{within | "elapsed_s" => 601})

      assert {:exhausted, "drive_runs"} =
               Exploration.within_budget(plan, %{within | "drive_runs" => 2})

      assert {:exhausted, "candidates"} =
               Exploration.within_budget(plan, %{within | "candidates" => 3})

      assert {:exhausted, "time_s"} =
               Exploration.within_budget(plan, Map.delete(within, "elapsed_s"))

      assert {:exhausted, "budget_or_usage_unrecorded"} = Exploration.within_budget(plan, nil)
      assert {:exhausted, "budget_or_usage_unrecorded"} = Exploration.within_budget(%{}, within)
    end
  end

  describe "OCEL composition" do
    test "from_court_form/1 inverts court_form/2 on the committed fmt-1 log; extension classes validate" do
      court = @fmt1 |> Path.join("ocel.json") |> File.read!() |> Jason.decode!()
      assert {:ok, observations} = Ocel.from_court_form(court)
      assert Ocel.court_form(observations) == court

      {events, objects} = observations

      extra = %{
        type: "ExplorationStarted",
        time: ~U[2026-09-23 00:00:00.000000Z],
        attributes: %{"producer" => "test:chicago-fixture"},
        relationships: [{"workorder:EP-A", "work-order"}]
      }

      types = Ocel.event_classes() ++ Ocel.extension_classes()
      extended = Ocel.court_form({[extra | events], objects}, types)
      assert {:ok, %{"event_count" => count}} = Validator.validate(extended)
      assert count == length(events) + 1

      # the ARD-only declaration refuses an undeclared extension class
      assert {:error, [_ | _]} = Validator.validate(Ocel.court_form({[extra | events], objects}))
      assert Ocel.equivalent?(extended, Ocel.standard_form({[extra | events], objects}, types))
    end
  end

  describe "mix xaas.machine_experience (real OS process, F3 no-LLM env)" do
    @describetag timeout: 300_000

    test "--route is UNKNOWN (exit 4) without an experience, KNOWN (exit 0) from one, REFUSED (exit 3) with an exposed credential" do
      dir = mktmp("route")
      work = Path.join(dir, "work.json")
      File.write!(work, Jason.encode!(%{"work_orders" => [row()]}))
      ttl = Path.join(dir, "me.ttl")
      File.write!(ttl, admitted_ttl!())

      {unknown, 4} = task([], ["--route", "--work", work])
      assert last_json(unknown)["reason"] == "no_capability_no_experience"

      {known, 0} = task([], ["--route", "--work", work, "--experience", ttl])
      assert last_json(known)["machine_experience"] == MachineExperience.iri(experience())
      assert last_json(known)["standing"] == "KNOWN"

      {refused, 3} =
        task(["ANTHROPIC_API_KEY=x"], ["--route", "--work", work, "--experience", ttl])

      assert last_json(refused)["standing"] == "REFUSED(llm_credential_present)"

      broken = Path.join(dir, "broken.ttl")

      File.write!(
        broken,
        String.replace(
          admitted_ttl!(),
          ~r/xme:applicabilityPredicate "[^"\\]*(?:\\.[^"\\]*)*"/,
          ~s(xme:applicabilityPredicate "SELECT nonsense")
        )
      )

      assert File.read!(broken) =~ ~s(xme:applicabilityPredicate "SELECT nonsense")

      {unevaluable, 3} = task([], ["--route", "--work", work, "--experience", broken])
      assert last_json(unevaluable)["reason"] == "experience_predicate_unevaluable"
    end
  end

  describe "Episode.run/1 no-LLM guard (F3, runner level)" do
    test "a credential variable or an LLM binary on PATH refuses before anything is read or written" do
      out = mktmp("f3-run")
      File.write!(Path.join(out, "work.json"), Jason.encode!(%{"work_orders" => [row()]}))
      bin = mktmp("f3-bin")
      claude = Path.join(bin, "claude")
      File.write!(claude, "#!/bin/sh\nexit 0\n")
      File.chmod!(claude, 0o755)

      for {env, field, named} <- [
            {%{"PATH" => "/usr/bin:/bin", "ANTHROPIC_API_KEY" => "x"}, "variables",
             ["ANTHROPIC_API_KEY"]},
            {%{"PATH" => bin <> ":/usr/bin:/bin"}, "binaries", [claude]}
          ] do
        assert {:refused,
                %{
                  "standing" => "REFUSED(llm_credential_present)",
                  "broken_term" => "mu_on_O",
                  "detail" => detail
                }} =
                 Episode.run(
                   name: "t-me-f3",
                   out_dir: out,
                   ggen_igniter_dir: "/nonexistent",
                   env: env
                 )

        assert detail[field] == named
        assert File.ls!(out) == ["work.json"]
      end

      # the same runner with a clean env reads the order and routes it (UNKNOWN here)
      assert {:unknown, %{"reason" => "no_capability_no_experience"}} =
               Episode.run(
                 name: "t-me-f3",
                 out_dir: out,
                 ggen_igniter_dir: "/nonexistent",
                 env: %{"PATH" => "/usr/bin:/bin"},
                 repo_path: out
               )

      assert File.regular?(Path.join([out, "unknown", "unknown.json"]))
    end
  end

  defp task(assignments, args) do
    System.cmd(
      "sh",
      [@no_llm_env | assignments] ++ ["--", "mix", "xaas.machine_experience" | args],
      env: [{"MIX_ENV", "test"}],
      stderr_to_stdout: true,
      cd: File.cwd!()
    )
  end

  defp last_json(out) do
    out
    |> String.split("\n", trim: true)
    |> Enum.reverse()
    |> Enum.find_value(fn line ->
      case Jason.decode(String.trim(line)) do
        {:ok, %{} = map} -> map
        _ -> nil
      end
    end)
  end

  defp mktmp(label) do
    dir = Path.join(System.tmp_dir!(), "xaas-me-#{label}-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end
end

defmodule Xaas.Ultracode.MachineExperienceEpisodeTest do
  @moduledoc """
  Chicago qualification of the two-episode ratchet end to end
  (`Xaas.Ultracode.MachineExperience.Episode`; GC-26.9.23 GC23-9).

  Every collaborator is real: a real `git clone --local` of the
  GGEN_IGNITER_DIR checkout's repository in a tmp dir with real episode
  branches (`Episode.prepare/1`, git plumbing); the real no-LLM
  `Xaas.Ultracode.SemanticDrive` (real `mix semantic_jira.*` processes in
  GGEN_IGNITER_DIR under a PRIVATE APFS clone of its `_build/test`, real
  sandboxed Postgres, the real recipe provider, fabric court, independent
  verifier and revert falsifier); ggen_igniter's real
  `SemanticJira.machine_experience/1` and real SHACL court
  (`scripts/machine_experience.exs`); the real fleet validator
  (`python3 ~/.claude/dfcm/validate_receipt.py`) and real
  `pm4py.read_ocel2_json`. The exploration artifact is written by this test
  and names this test as its producer (`test:chicago-fixture`).

  Skips (never fails) when `GGEN_IGNITER_DIR` is unset or lacks the restored
  `mix semantic_jira.*` surface.
  """

  use ExUnit.Case, async: false

  alias Xaas.Ultracode.MachineExperience
  alias Xaas.Ultracode.MachineExperience.{Episode, Exploration}
  alias Xaas.Ultracode.SemanticDrive
  alias Xaas.Ultracode.SemanticDrive.Episode, as: DriveEpisode

  @moduletag timeout: 1_800_000

  @ggen_dir System.get_env("GGEN_IGNITER_DIR")
  @validator Path.expand("~/.claude/dfcm/validate_receipt.py")
  @s1 "lib/ggen_igniter/semantic_jira/reconciler.ex"
  @s2 "lib/ggen_igniter/semantic_jira/transition_log.ex"

  @moduletag skip:
               (cond do
                  is_nil(@ggen_dir) ->
                    "GGEN_IGNITER_DIR unset (the graph-side checkout under judgement)"

                  not File.regular?(
                    Path.join(@ggen_dir, "lib/mix/tasks/semantic_jira.descriptor.ex")
                  ) ->
                    "GGEN_IGNITER_DIR #{@ggen_dir} lacks the restored mix semantic_jira.* surface (FRI-T6)"

                  true ->
                    false
                end)

  # The episode SUBJECT base is episode data, not the checkout under
  # judgement: the committed episodes me-1/me-2 recorded theirs in
  # prepare.json ("base"), a commit whose tree is format-clean under the
  # repository's pinned toolchain, so the drift commit is the only format
  # failure and the recipe's consequence is exactly the drift file. The
  # graph side (every `mix semantic_jira.*`, `machine_experience/1`, SHACL)
  # still runs from GGEN_IGNITER_DIR at its own HEAD. A GGEN_IGNITER_DIR
  # HEAD is not a sound subject base in general: ggen_igniter-int 3937a4f
  # carries lib/ggen_igniter/semantic_jira/bootstrap.ex unformatted under
  # its .tool-versions Elixir 1.18.4 (clean under 1.19.5), so the recipe
  # also reformats that file. Falls back to HEAD only when the recorded
  # base is not in the repository.
  @recorded_base Path.expand(
                   "../../../docs/sjira/v26.9.23/episodes/me-1/prepare.json",
                   __DIR__
                 )

  setup_all do
    base = mktmp_all("me-all")
    {:ok, repo} = DriveEpisode.repo_root(@ggen_dir)
    subject = Path.join(base, "subject")
    {_, 0} = System.cmd("git", ["clone", "-q", "--local", "--no-checkout", repo, subject])
    build = Path.join(base, "build")
    File.mkdir_p!(build)
    {_, 0} = System.cmd("cp", ["-cRp", Path.join(@ggen_dir, "_build/test"), build])
    {head, 0} = System.cmd("git", ["-C", @ggen_dir, "rev-parse", "HEAD"])
    on_exit(fn -> File.rm_rf(base) end)
    %{subject: subject, build: Path.join(build, "test"), base_sha: subject_base(subject, head)}
  end

  defp subject_base(subject, head) do
    recorded = @recorded_base |> File.read!() |> Jason.decode!() |> Map.fetch!("base")

    case System.cmd("git", ["-C", subject, "cat-file", "-e", recorded <> "^{commit}"],
           stderr_to_stdout: true
         ) do
      {_, 0} -> recorded
      _ -> String.trim(head)
    end
  end

  setup %{subject: subject} do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Xaas.Repo, shared: true)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    original = %{
      repos: Application.get_env(:xaas, :ultracode_repos),
      root: Application.get_env(:xaas, :ultracode_worktree_root),
      suites: Application.get_env(:xaas, :ultracode_verifier_suites)
    }

    on_exit(fn ->
      restore_env(:ultracode_repos, original.repos)
      restore_env(:ultracode_worktree_root, original.root)
      restore_env(:ultracode_verifier_suites, original.suites)
    end)

    root = canonical(mktmp("me-runs"))
    Application.put_env(:xaas, :ultracode_repos, %{"ggen_igniter" => subject})
    Application.put_env(:xaas, :ultracode_worktree_root, root)

    Application.put_env(:xaas, :ultracode_verifier_suites, %{
      "ggen-igniter-format" => Mix.Tasks.Xaas.Episode.court_suite()
    })

    %{root: root}
  end

  test "episode 1 UNKNOWN -> bounded exploration -> admitted MachineExperience; episode 2 on another subject routes KNOWN from it with zero exploration and fewer events; without it, UNKNOWN and nothing executes",
       ctx do
    eps = mktmp("eps")
    n1 = name("one")
    n2 = name("two")
    ep1 = Path.join(eps, n1)
    ep2 = Path.join(eps, n2)

    {:ok, p1} = prepare(ctx, n1, @s1, ep1)
    {:ok, p2} = prepare(ctx, n2, @s2, ep2)
    assert p1["subject_sha"] != p2["subject_sha"]

    for dir <- [ep1, ep2], order <- read!(dir, "work.json")["work_orders"] do
      refute Map.has_key?(order, "requires_capability")
      assert order["failure_class"] == "format_drift"
    end

    # -- episode 1, before exploration: UNKNOWN, receipted, nothing executed
    assert {:unknown, %{"reason" => "no_capability_no_experience", "receipt" => receipt}} =
             run(ctx, n1, ep1, [])

    assert receipt == Path.join([ep1, "unknown", "unknown.json"])
    assert read!(ep1, "unknown/unknown.json")["standing"]["value"] == "UNKNOWN"
    assert validate!(receipt) =~ "ADMITTED"
    refute File.exists?(Path.join(ep1, "drive"))

    # -- episode 1 with a bounded exploration artifact
    write_exploration!(ep1, "recipe:mix-format", drive_runs: 1)
    assert {:ok, s1} = run(ctx, n1, ep1, [])
    assert s1["standing"] == "ALIVE"
    assert s1["decision"] == "UNKNOWN"
    assert s1["route"]["source"] == "exploration"
    assert s1["exploration"]["used"]["drive_runs"] == 1
    assert s1["ocel"]["exploration_events"] == 2
    assert s1["ocel"]["llm_provider_events"] > 0
    assert s1["ocel"]["by_class"]["MachineExperienceAdmitted"] == 1
    assert "validate" in s1["steps"]

    me_iri = s1["machine_experience"]["machine_experience"]
    ttl = Path.join(ep1, "machine_experience.ttl")
    record = read!(ep1, "machine_experience.json")
    assert record["shape_report"]["conforms"] == true
    assert "machine_experience_shape" in record["shape_report"]["shapes_checked"]
    assert record["experience"]["standing"] == "CANDIDATE"
    assert record["admission"]["admission"] == "ADMITTED"
    assert validate!(Path.join([ep1, "drive", "receipt.r.json"])) =~ "ADMITTED"
    assert pm4py_count!(Path.join(ep1, "ocel2.json")) == s1["ocel"]["events"]

    # re-running a driven episode is refused: evidence is never overwritten
    assert {:refused, %{"reason" => "episode_already_driven"}} = run(ctx, n1, ep1, [ttl])

    # -- episode 2: another subject, same failure class, the admitted experience
    assert {:ok, s2} = run(ctx, n2, ep2, [ttl])
    assert s2["standing"] == "ALIVE"
    assert s2["decision"] == "KNOWN"
    assert s2["route"]["source"] == "machine_experience"
    assert s2["route"]["machine_experience"] == me_iri
    assert s2["route"]["capability"] == record["admission"]["admitted_capability"]
    assert s2["exploration"] == nil
    refute File.exists?(Path.join(ep2, "exploration.json"))
    assert s2["ocel"]["llm_provider_events"] == 0
    assert s2["ocel"]["exploration_events"] == 0
    assert s2["ocel"]["events"] < s1["ocel"]["events"]
    assert s2["step_count"] < s1["step_count"]

    ocel2 = read!(ep2, "ocel.json")

    for kind <- ~w(RouteDecided CapabilityResolved) do
      [event] = Enum.filter(ocel2["ocel:events"], &(&1["type"] == kind))
      assert event["attributes"]["machine_experience"] == me_iri

      assert %{"objectId" => "machine-experience:" <> ^me_iri} =
               Enum.find(event["relationships"], &(&1["qualifier"] == "machine-experience"))
    end

    head2 = s2["drive"]["head"]
    assert git!(ctx.subject, ["rev-parse", head2 <> "^"]) == p2["subject_sha"]
    assert git!(ctx.subject, ["diff", "--name-only", p2["subject_sha"], head2]) == @s2

    # -- falsifier: the same order without the experience is UNKNOWN; nothing runs
    {:ok, graph} = MachineExperience.load([ttl])
    bare = Path.join(mktmp("bare"), "no-me.ttl")

    File.write!(
      bare,
      graph |> RDF.Graph.delete_descriptions(RDF.iri(me_iri)) |> RDF.Turtle.write_string!()
    )

    n3 = name("three")
    ep3 = Path.join(eps, n3)
    File.mkdir_p!(ep3)
    File.cp!(Path.join(ep2, "work.json"), Path.join(ep3, "work.json"))
    File.write!(Path.join(ep3, "ledger.ndjson"), "")

    assert {:unknown, %{"reason" => "no_capability_no_experience"}} = run(ctx, n3, ep3, [bare])
    refute File.exists?(Path.join(ep3, "drive"))
    assert File.read!(Path.join(ep3, "ledger.ndjson")) == ""
    assert File.ls!(ctx.root) == []
  end

  test "a candidate that resolves only by overrunning time_s is exhausted, not resolved: receipted UNKNOWN naming the drive's head, no experience",
       ctx do
    eps = mktmp("eps-t")
    n = name("overrun")
    ep = Path.join(eps, n)
    {:ok, _} = prepare(ctx, n, @s1, ep)
    # proposal 5 s of a 6 s budget: the pre-drive check passes (5 < 6), the
    # real drive takes more than the remaining second
    write_exploration!(ep, "recipe:mix-format", drive_runs: 1, time_s: 6)

    assert {:unknown,
            %{
              "reason" => "exploration_budget_exhausted",
              "detail" => %{
                "exhausted" => "time_s",
                "attempts" => [attempt],
                "used" => %{"drive_runs" => 1, "elapsed_s" => elapsed}
              },
              "receipt" => receipt
            }} = run(ctx, n, ep, [])

    assert elapsed > 6
    assert attempt["over_budget"] == "time_s"
    assert attempt["standing"] == "ALIVE"
    assert attempt["resolved"] == true
    assert receipt == Path.join(ep, "unknown.json")
    assert validate!(receipt) =~ "ADMITTED"
    unknown = read!(ep, "unknown.json")
    assert unknown["standing"]["value"] == "UNKNOWN"
    assert unknown["consequence"]["commits"] == [attempt["head"]]
    assert unknown["authority"]["grant"] =~ "no MachineExperience admitted"
    refute File.exists?(Path.join(ep, "machine_experience.ttl"))
    refute File.exists?(Path.join(ep, "machine_experience.json"))
    refute File.exists?(Path.join(ep, "episode.json"))
  end

  test "the drive refuses a route whose capability is not the tuple's (route_capability_mismatch) before any lease",
       ctx do
    eps = mktmp("eps-m")
    n = name("mismatch")
    ep = Path.join(eps, n)
    {:ok, _} = prepare(ctx, n, @s1, ep)
    dir = Path.join(ep, "drive")
    File.mkdir_p!(dir)

    routed =
      ep
      |> read!("work.json")
      |> Map.update!("work_orders", fn rows ->
        Enum.map(rows, fn row ->
          if row["identity"] == "EP-A",
            do: Map.put(row, "requires_capability", "recipe:mix-format"),
            else: row
        end)
      end)

    File.write!(Path.join(dir, "work.json"), Jason.encode!(routed))

    assert {:refused,
            %{
              "reason" => "route_capability_mismatch",
              "hop" => "resolve",
              "broken_term" => "admission_vacuous",
              "detail" => %{"capability" => "recipe:mix-format"}
            }} =
             SemanticDrive.drive(
               ggen_igniter_dir: @ggen_dir,
               work_graph: Path.join(dir, "work.json"),
               ledger: Path.join(ep, "ledger.ndjson"),
               order: "EP-A",
               out_dir: dir,
               env: clean_env(),
               ggen_build_path: ctx.build,
               route: %{
                 "source" => "exploration",
                 "capability" => "recipe:other-fix",
                 "producer" => "test:chicago-fixture",
                 "producer_class" => "test",
                 "exploration_digest" => MachineExperience.sha256("x")
               }
             )

    refusal = read!(dir, "refused.json")
    assert refusal["outcome"]["reason"] == "route_capability_mismatch"
    refute "CapabilityResolved" in refusal["ocel_reached"]
    assert File.read!(Path.join(ep, "ledger.ndjson")) == ""
    assert File.ls!(ctx.root) == []
  end

  test "an exploration whose only candidate cannot be driven exhausts its budget: receipted UNKNOWN, no experience",
       ctx do
    eps = mktmp("eps-x")
    n = name("exhaust")
    ep = Path.join(eps, n)
    {:ok, _} = prepare(ctx, n, @s1, ep)
    write_exploration!(ep, "recipe:not-registered", drive_runs: 1)

    assert {:unknown,
            %{
              "reason" => "exploration_budget_exhausted",
              "detail" => %{"attempts" => [attempt], "used" => %{"drive_runs" => 1}},
              "receipt" => receipt
            }} = run(ctx, n, ep, [])

    assert attempt["refused"]["reason"] == "unregistered_capability"
    assert receipt == Path.join(ep, "unknown.json")
    assert validate!(receipt) =~ "ADMITTED"
    refute File.exists?(Path.join(ep, "machine_experience.ttl"))
    refute File.exists?(Path.join(ep, "episode.json"))
    assert File.read!(Path.join(ep, "ledger.ndjson")) == ""
  end

  # -- helpers ------------------------------------------------------------------------

  defp prepare(ctx, name, drift, out_dir) do
    Episode.prepare(
      repo: ctx.subject,
      name: name,
      base: ctx.base_sha,
      drift: drift,
      out_dir: out_dir
    )
  end

  defp run(ctx, name, out_dir, experience) do
    Episode.run(
      name: name,
      out_dir: out_dir,
      ggen_igniter_dir: @ggen_dir,
      experience: experience,
      ggen_build_path: ctx.build,
      repo_path: ctx.subject,
      env: clean_env()
    )
  end

  defp write_exploration!(dir, capability, opts) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    File.write!(
      Path.join(dir, "exploration.json"),
      Jason.encode!(%{
        "schema" => Exploration.schema(),
        "order" => "EP-A",
        "problem_class" => "format_drift",
        "producer" => "test:chicago-fixture",
        "producer_class" => "test",
        "started_at" => DateTime.to_iso8601(DateTime.add(now, -5, :second)),
        "finished_at" => DateTime.to_iso8601(now),
        "budget" => %{
          "time_s" => Keyword.get(opts, :time_s, 1_200),
          "drive_runs" => Keyword.fetch!(opts, :drive_runs),
          "candidates" => 1,
          "consequence_ceiling" => "CONSTRUCT",
          "evidence_requirement" => Exploration.evidence_kinds()
        },
        "candidates" => [%{"capability" => capability, "authority_ceiling" => "CONSTRUCT"}]
      })
    )
  end

  defp clean_env do
    System.get_env()
    |> Enum.reject(fn {name, _} ->
      name == "CLAUDECODE" or
        Enum.any?(SemanticDrive.llm_variables().prefixes, &String.starts_with?(name, &1))
    end)
    |> Map.new()
    |> Map.put("PATH", "/usr/bin:/bin")
  end

  defp validate!(path) do
    {out, _code} = System.cmd("python3", [@validator, path], stderr_to_stdout: true)
    out
  end

  defp pm4py_count!(path) do
    {out, 0} =
      System.cmd(
        "python3",
        ["-c", "import pm4py, sys; print(len(pm4py.read_ocel2_json(sys.argv[1]).events))", path],
        stderr_to_stdout: true
      )

    out |> String.split("\n", trim: true) |> List.last() |> String.to_integer()
  end

  defp name(label), do: "t-me-#{label}-#{System.unique_integer([:positive])}"

  defp read!(dir, file), do: dir |> Path.join(file) |> File.read!() |> Jason.decode!()

  defp git!(dir, args) do
    {out, 0} = System.cmd("git", ["-C", dir | args], stderr_to_stdout: true)
    String.trim(out)
  end

  defp restore_env(key, nil), do: Application.delete_env(:xaas, key)
  defp restore_env(key, value), do: Application.put_env(:xaas, key, value)

  defp mktmp(label) do
    dir = Path.join(System.tmp_dir!(), "xaas-#{label}-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end

  defp mktmp_all(label) do
    dir = Path.join(System.tmp_dir!(), "xaas-#{label}-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    dir
  end

  defp canonical(path) do
    {out, 0} = System.cmd("pwd", ["-P"], cd: path)
    String.trim(out)
  end
end
