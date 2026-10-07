defmodule Xaas.Ultracode.SemanticJiraBridgeTest do
  @moduledoc """
  Chicago-style, no doubles, no database: every collaborator is real -- the
  `ggen_igniter` kernel (admission, frontier, projection, promotion), the real
  file-backed `TransitionLog`, the real `Reconciler`, the real SHACL court, the
  real semantic-jira-pack ontology and A2A gates, and `SemanticWork.admit/1`.

  The exports fed to `reconciler_receipt/2` here are map literals with the exact
  key set of `Xaas.Ultracode.SemanticReceipt.export/1`. That is the input
  DATA of a pure mapping function under test; the end-to-end suite
  (`SemanticJiraBridgeCrownTest`) exports every receipt from a real sealed
  Epoch instead. Every refusal asserts the log directory is still empty.
  """

  use ExUnit.Case, async: false

  # Needs ggen_igniter >= 26.9.20 (SemanticJira Shacl/TransitionLog.event_digest/1).

  alias GgenIgniter.{SemanticA2A, SemanticJira}
  alias GgenIgniter.SemanticJira.{Reconciler, TransitionLog}
  alias Xaas.Ultracode.SemanticJiraBridge, as: Bridge
  alias Xaas.Ultracode.SemanticJiraBridgeFixtures, as: F
  alias Xaas.Ultracode.{SemanticReceipt, SemanticWork}

  @base F.sha("base")
  @prefix "urn:semantic-jira:work-order:"

  setup do
    dir = F.tmp_dir("log")
    on_exit(fn -> File.rm_rf(dir) end)

    root = F.work_order("FIX-BROKEN", @base)
    dependent = F.work_order("VERIFY-CLEAN", @base, ["FIX-BROKEN"])

    %{
      dir: dir,
      root: root,
      dependent: dependent,
      graph: [root, dependent],
      opts: [
        execution_repo_alias: "demo",
        verifier_suite: "bridge-suite",
        graph_digest: F.graph_digest(),
        court_map: F.court_map("FIX-BROKEN", "check.sh::broken_absent", "check.sh::no_regression")
      ]
    }
  end

  defp descriptor!(graph, dir, identity, opts) do
    assert {:ok, %{descriptor: v1, execution: execution}} =
             Bridge.descriptor(graph, dir, identity, opts)

    {v1, execution}
  end

  defp root_export(ctx, export_opts \\ []) do
    {_v1, execution} = descriptor!(ctx.graph, ctx.dir, "FIX-BROKEN", ctx.opts)
    F.export(ctx.root, execution["bridge"], export_opts)
  end

  defp assert_log_empty(dir), do: assert(TransitionLog.read(dir) == [])

  describe "descriptor emission from the admitted frontier" do
    test "carries definition_digest and snapshot digest, is XaaS-admissible, authority NONE",
         ctx do
      {v1, execution} = descriptor!(ctx.graph, ctx.dir, "FIX-BROKEN", ctx.opts)

      assert {:ok, definition} = SemanticJira.definition_digest(ctx.root)
      assert {:ok, admitted} = SemanticJira.admit_work_order(ctx.root)

      assert v1["schema"] == "semantic-jira/execution-descriptor/v1"
      assert v1["definition_digest"] == definition
      assert v1["snapshot_digest"] == admitted["work_order_digest"]
      assert v1["graph_digest"] == F.graph_digest()
      assert v1["base_sha"] == @base
      assert v1["authority"] == "NONE"

      # the same identity travels, verbatim, in the XaaS bridge that the sealed export echoes
      assert execution["bridge"]["definition_digest"] == definition
      assert execution["bridge"]["source_snapshot_digest"] == admitted["work_order_digest"]
      assert execution["bridge"]["graph_digest"] == F.graph_digest()
      assert execution["work_order_iri"] == @prefix <> "FIX-BROKEN"

      assert execution["checkpoint_iri"] ==
               "urn:semantic-jira:checkpoint:sha256:" <> String.duplicate("0", 64)

      assert {:ok, input} = SemanticWork.admit(execution)
      assert input.base_sha == @base
      assert input.execution_policy == :autonomic_wave_attempt
      assert input.dependencies == []
      assert input.court_map == ctx.opts[:court_map]
    end

    test "an unmet dependency is not on the frontier: typed refusal, no descriptor", ctx do
      assert {:error, {:refused_bridge, {:not_on_frontier, "dependencies_unsatisfied"}}} =
               Bridge.descriptor(ctx.graph, ctx.dir, "VERIFY-CLEAN", ctx.opts)
    end

    test "an unknown identity is refused", ctx do
      assert {:error, {:refused_bridge, :unknown_work_order}} =
               Bridge.descriptor(ctx.graph, ctx.dir, "NOPE", ctx.opts)
    end

    test "a work order the kernel does not admit is refused (a branch is not an exact SHA)",
         ctx do
      bad = Map.put(ctx.root, "base_sha", "main")

      assert {:error, {:refused_bridge, {:unadmitted, _}}} =
               Bridge.descriptor([bad], ctx.dir, "FIX-BROKEN", ctx.opts)
    end

    test "SHACL admission runs when shapes are given and refuses a violating candidate", ctx do
      opts = Keyword.put(ctx.opts, :shapes, F.shapes())
      assert {:ok, _} = Bridge.descriptor(ctx.graph, ctx.dir, "FIX-BROKEN", opts)

      # Kernel admission needs 40-hex base_sha too; violate a SHACL-only constraint instead.
      lowercase = Map.put(ctx.root, "identity", "fix-broken")

      assert {:error, {:refused_bridge, {:shacl, violations}}} =
               Bridge.admit_candidate(lowercase, shapes: F.shapes())

      assert Enum.any?(violations, &(inspect(&1) =~ "identifier"))
    end

    test "options are required, never invented", ctx do
      for key <- [:execution_repo_alias, :verifier_suite, :graph_digest] do
        assert {:error, {:refused_bridge, {:missing_option, ^key}}} =
                 Bridge.descriptor(
                   ctx.graph,
                   ctx.dir,
                   "FIX-BROKEN",
                   Keyword.delete(ctx.opts, key)
                 )
      end

      assert {:error, {:refused_bridge, {:invalid_option, :graph_digest}}} =
               Bridge.descriptor(
                 ctx.graph,
                 ctx.dir,
                 "FIX-BROKEN",
                 Keyword.put(ctx.opts, :graph_digest, "not-a-digest")
               )
    end

    test "a court map binding an IRI the work order does not own is refused, never trimmed",
         ctx do
      foreign =
        Keyword.put(
          ctx.opts,
          :court_map,
          %{"acceptance" => %{"https://elsewhere.example/acc" => %{"test" => "t::a"}}}
        )

      assert {:error, {:refused_bridge, {:court_map, {:foreign_iri, "acceptance", [_]}}}} =
               Bridge.descriptor(ctx.graph, ctx.dir, "FIX-BROKEN", foreign)

      malformed = Keyword.put(ctx.opts, :court_map, %{"acceptance" => %{}, "courts" => ["", 1]})

      assert {:error, {:refused_bridge, _}} =
               Bridge.descriptor(ctx.graph, ctx.dir, "FIX-BROKEN", malformed)
    end

    test "after the upstream is ALIVE in the log the dependent's descriptor carries the typed receipt edge",
         ctx do
      {_v1, execution} = descriptor!(ctx.graph, ctx.dir, "FIX-BROKEN", ctx.opts)
      export = F.export(ctx.root, execution["bridge"])

      assert {:ok, %{event: event, disposition: :appended, frontier: front}} =
               Bridge.admit(ctx.graph, "FIX-BROKEN", export, ctx.dir, fabric_check: false)

      assert ["VERIFY-CLEAN"] == Enum.map(front.eligible, & &1["identity"])

      dep_opts = Keyword.put(ctx.opts, :court_map, nil)
      {v1, dep_execution} = descriptor!(ctx.graph, ctx.dir, "VERIFY-CLEAN", dep_opts)

      assert [edge] = dep_execution["dependencies"]
      assert edge["work_order_iri"] == @prefix <> "FIX-BROKEN"
      assert edge["required_standing"] == "ALIVE" and edge["observed_standing"] == "ALIVE"
      assert edge["receipt_digest"] == event["receipt_digest"]
      assert edge["receipt_iri"] == "urn:semantic-jira:receipt:" <> event["receipt_digest"]

      assert dep_execution["checkpoint_iri"] ==
               "urn:semantic-jira:checkpoint:" <> event["event_digest"]

      assert {:ok, %{dependencies: [_]}} = SemanticWork.admit(dep_execution)
      assert v1["work_order_id"] == "VERIFY-CLEAN"

      # a retry of the same ledger tail gets its own checkpoint (own worktree name)
      {_v1, retry} =
        descriptor!(ctx.graph, ctx.dir, "VERIFY-CLEAN", Keyword.put(dep_opts, :attempt, 2))

      assert retry["checkpoint_iri"] == dep_execution["checkpoint_iri"] <> ":attempt-2"
    end
  end

  describe "receipt mapping is pure and refuses tampering" do
    test "an ALIVE export maps to a receipt the real Reconciler admits", ctx do
      export = root_export(ctx)
      assert {:ok, receipt} = Bridge.reconciler_receipt(export, ctx.root)

      assert receipt["target"] == "ALIVE"
      assert receipt["candidate_sha"] == export["final_head"]
      assert receipt["definition_digest"] == export["bridge"]["definition_digest"]
      assert receipt["snapshot_digest"] == export["bridge"]["source_snapshot_digest"]
      assert receipt["evidence"]["court_results"] == %{F.court_iri() => %{"passed" => true}}

      assert receipt["evidence"]["acceptance_results"] == %{
               F.acceptance_iri("FIX-BROKEN") => true
             }

      assert receipt["evidence"]["falsifier_results"] ==
               %{F.falsifier_iri("FIX-BROKEN") => "survived"}

      assert receipt["evidence"]["evidence_ceiling"] == "repository-local"
      assert F.evidence_iri() in receipt["evidence"]["evidence_types"]
      assert receipt["xaas"]["receipt_digest"] == export["receipt_digest"]

      assert {:ok, event, :appended} = Reconciler.reconcile(ctx.root, receipt, ctx.dir)

      assert event["from"] == "UNKNOWN" and event["to"] == "ALIVE" and
               event["authority"] == "NONE"
    end

    test "a tampered export (digest not recomputed) is refused and the log does not move",
         ctx do
      export = root_export(ctx)
      moved = Map.put(export, "final_head", F.sha("someone-elses-head"))

      assert {:error, {:refused_bridge, :receipt_digest_mismatch}} =
               Bridge.admit(ctx.graph, "FIX-BROKEN", moved, ctx.dir, fabric_check: false)

      flipped = put_in(export, ["fabric_verifier", "court_receipt", "acceptance_results"], %{})

      assert {:error, {:refused_bridge, :receipt_digest_mismatch}} =
               Bridge.reconciler_receipt(flipped, ctx.root)

      undigested = Map.delete(export, "receipt_digest")

      assert {:error, {:refused_bridge, :invalid_receipt_digest}} =
               Bridge.reconciler_receipt(undigested, ctx.root)

      assert_log_empty(ctx.dir)
    end

    test "claims the fabric did not make are refused even when the forger recomputes the digest",
         ctx do
      export = root_export(ctx)

      failed = F.reseal(export, &put_in(&1, ["fabric_verifier", "status"], "fail"))

      assert {:error, {:refused_bridge, :alive_without_verifier_pass}} =
               Bridge.reconciler_receipt(failed, ctx.root)

      unverified = F.reseal(export, &Map.put(&1, "head_verified", false))

      assert {:error, {:refused_bridge, :alive_without_head_verification}} =
               Bridge.reconciler_receipt(unverified, ctx.root)

      bad_head = F.reseal(export, &Map.put(&1, "final_head", "main"))

      assert {:error, {:refused_bridge, :invalid_final_head}} =
               Bridge.reconciler_receipt(bad_head, ctx.root)

      odd = F.reseal(export, &Map.put(&1, "outcome", "heartbeat"))

      assert {:error, {:refused_bridge, {:unsupported_outcome, "heartbeat"}}} =
               Bridge.reconciler_receipt(odd, ctx.root)

      assert {:error, {:refused_bridge, :not_a_map}} = Bridge.reconciler_receipt("nope", ctx.root)
      assert_log_empty(ctx.dir)
    end

    test "a court receipt bound to some other head earns no credit: promotion is refused",
         ctx do
      export = root_export(ctx, court_head: F.sha("a-different-head"))
      assert {:ok, receipt} = Bridge.reconciler_receipt(export, ctx.root)

      assert receipt["evidence"]["acceptance_results"] ==
               %{F.acceptance_iri("FIX-BROKEN") => false}

      assert receipt["evidence"]["court_results"] == %{F.court_iri() => %{"passed" => false}}

      assert receipt["evidence"]["falsifier_results"] ==
               %{F.falsifier_iri("FIX-BROKEN") => "unobserved"}

      assert {:error, {:refused_bridge, {:promotion_refused, failed}}} =
               Bridge.admit(ctx.graph, "FIX-BROKEN", export, ctx.dir, fabric_check: false)

      assert :courts in failed and :acceptance in failed and :falsifiers in failed
      assert_log_empty(ctx.dir)
    end

    test "a failing acceptance verdict or a killed falsifier keeps the work order on the frontier",
         ctx do
      for verdicts <- [[acceptance: false], [falsifier: "failed"]] do
        export = root_export(ctx, verdicts)

        assert {:error, {:refused_bridge, {:promotion_refused, _}}} =
                 Bridge.admit(ctx.graph, "FIX-BROKEN", export, ctx.dir, fabric_check: false)
      end

      assert_log_empty(ctx.dir)

      assert ["FIX-BROKEN"] ==
               Enum.map(Bridge.frontier(ctx.graph, ctx.dir).eligible, & &1["identity"])
    end

    test "a BUILD_BROKEN receipt is mapped and refused: no promotion without a passing court",
         ctx do
      export = root_export(ctx, outcome: "build_broken", status: "fail")

      assert {:ok, %{"target" => "BUILD_BROKEN"} = receipt} =
               Bridge.reconciler_receipt(export, ctx.root)

      assert receipt["evidence"]["court_results"] == %{F.court_iri() => %{"passed" => false}}
      assert receipt["evidence"]["observed_execution"] == false

      assert {:error, {:refused_bridge, {:promotion_refused, failed}}} =
               Bridge.admit(ctx.graph, "FIX-BROKEN", export, ctx.dir, fabric_check: false)

      assert :courts in failed
      assert_log_empty(ctx.dir)
    end

    test "the fabric cannot promote past its ceiling: a work order demanding more is refused",
         ctx do
      demanding = F.work_order("FIX-BROKEN", @base, [], %{"evidence_ceiling" => "observed"})
      {_v1, execution} = descriptor!([demanding], ctx.dir, "FIX-BROKEN", ctx.opts)
      export = F.export(demanding, execution["bridge"])

      assert {:error, {:refused_bridge, {:promotion_refused, [:ceiling]}}} =
               Bridge.admit([demanding], "FIX-BROKEN", export, ctx.dir, fabric_check: false)

      assert_log_empty(ctx.dir)
    end
  end

  describe "admission into the log" do
    test "stale or mismatched definition digests are refused: :definition_mismatch", ctx do
      export = root_export(ctx)
      edited = Map.put(ctx.root, "description", "A different, later definition.")

      assert {:error, {:refused_bridge, :definition_mismatch}} =
               Bridge.admit([edited, ctx.dependent], "FIX-BROKEN", export, ctx.dir,
                 fabric_check: false
               )

      forged = F.reseal(export, &put_in(&1, ["bridge", "definition_digest"], F.graph_digest()))

      assert {:error, {:refused_bridge, :definition_mismatch}} =
               Bridge.admit(ctx.graph, "FIX-BROKEN", forged, ctx.dir, fabric_check: false)

      assert_log_empty(ctx.dir)
    end

    test "a stale snapshot alone stays admissible (sibling transitions are not invalidated)",
         ctx do
      export = root_export(ctx)

      stale =
        F.reseal(export, &put_in(&1, ["bridge", "source_snapshot_digest"], F.graph_digest()))

      assert {:ok, %{disposition: :appended}} =
               Bridge.admit(ctx.graph, "FIX-BROKEN", stale, ctx.dir, fabric_check: false)
    end

    test "an unadmitted work order takes no transition: unmet dependencies", ctx do
      {_v1, execution} = descriptor!(ctx.graph, ctx.dir, "FIX-BROKEN", ctx.opts)
      export = F.export(ctx.dependent, %{execution["bridge"] | "identity" => "VERIFY-CLEAN"})

      # The bridge is FIX-BROKEN's definition, so the definition would also mismatch; the
      # frontier check comes first and names the real reason.
      assert {:error, {:refused_bridge, {:not_on_frontier, "dependencies_unsatisfied"}}} =
               Bridge.admit(ctx.graph, "VERIFY-CLEAN", export, ctx.dir, fabric_check: false)

      assert {:error, {:refused_bridge, :unknown_work_order}} =
               Bridge.admit(ctx.graph, "NOPE", export, ctx.dir, fabric_check: false)

      assert_log_empty(ctx.dir)
    end

    test "an export for another work order is refused: :bridge_identity_mismatch", ctx do
      export = root_export(ctx)

      assert {:error, {:refused_bridge, :bridge_identity_mismatch}} =
               Bridge.reconciler_receipt(export, ctx.dependent)
    end

    test "replaying the same export is idempotent; a different receipt for ALIVE work is refused",
         ctx do
      export = root_export(ctx)

      assert {:ok, %{disposition: :appended, event: event}} =
               Bridge.admit(ctx.graph, "FIX-BROKEN", export, ctx.dir, fabric_check: false)

      assert {:ok, %{disposition: :already_recorded, event: ^event}} =
               Bridge.admit(ctx.graph, "FIX-BROKEN", export, ctx.dir, fabric_check: false)

      assert length(TransitionLog.read(ctx.dir)) == 1

      {_v1, execution} =
        descriptor!(ctx.graph, ctx.dir, "VERIFY-CLEAN", Keyword.put(ctx.opts, :court_map, nil))

      second = F.export(ctx.root, export["bridge"], head: F.sha("second-attempt"))

      assert {:error, {:refused_bridge, {:not_on_frontier, "standing=ALIVE"}}} =
               Bridge.admit(ctx.graph, "FIX-BROKEN", second, ctx.dir, fabric_check: false)

      assert execution["work_order_iri"] == @prefix <> "VERIFY-CLEAN"
      assert length(TransitionLog.read(ctx.dir)) == 1
    end

    test "concurrent receipts for one work order: exactly one transition lands", ctx do
      bridge = root_export(ctx)["bridge"]

      exports = for n <- 1..8, do: F.export(ctx.root, bridge, head: F.sha("racer-#{n}"))

      results =
        exports
        |> Task.async_stream(
          &Bridge.admit(ctx.graph, "FIX-BROKEN", &1, ctx.dir, fabric_check: false),
          max_concurrency: 8,
          timeout: 60_000
        )
        |> Enum.map(fn {:ok, result} -> result end)

      assert Enum.count(results, &match?({:ok, %{disposition: :appended}}, &1)) == 1

      assert Enum.count(
               results,
               &match?({:error, {:refused_bridge, {:not_on_frontier, "standing=ALIVE"}}}, &1)
             ) == 7

      assert [%{"to" => "ALIVE"}] = TransitionLog.read(ctx.dir)
    end

    test "a candidate_sha the work order pins must match the sealed head", ctx do
      pinned = F.work_order("FIX-BROKEN", @base, [], %{"candidate_sha" => F.sha("pinned")})
      {_v1, execution} = descriptor!([pinned], ctx.dir, "FIX-BROKEN", ctx.opts)
      export = F.export(pinned, execution["bridge"], head: F.sha("actual"))

      assert {:error, {:refused_bridge, :candidate_sha_mismatch}} =
               Bridge.admit([pinned], "FIX-BROKEN", export, ctx.dir, fabric_check: false)

      assert_log_empty(ctx.dir)
    end

    test "the new frontier and the replayable state come back from admit", ctx do
      assert %{"eligible" => ["FIX-BROKEN"], "standings" => standings} =
               Bridge.state(ctx.graph, ctx.dir)

      assert standings == %{"FIX-BROKEN" => "UNKNOWN", "VERIFY-CLEAN" => "UNKNOWN"}

      assert {:ok, %{frontier: front}} =
               Bridge.admit(ctx.graph, "FIX-BROKEN", root_export(ctx), ctx.dir,
                 fabric_check: false
               )

      assert ["VERIFY-CLEAN"] == Enum.map(front.eligible, & &1["identity"])

      state = Bridge.state(ctx.graph, ctx.dir)
      assert state["eligible"] == ["VERIFY-CLEAN"]
      assert state["standings"] == %{"FIX-BROKEN" => "ALIVE", "VERIFY-CLEAN" => "UNKNOWN"}

      assert [%{"identity" => "FIX-BROKEN", "from" => "UNKNOWN", "to" => "ALIVE"}] =
               state["events"]

      assert state["ledger_tail"] == hd(state["events"])["event_digest"]
    end
  end

  describe "digest equivalence with the kernel (why receipt_digest/1 is not deleted)" do
    test "on real exports SemanticReceipt.receipt_digest/1 is SemanticJira.digest/1", ctx do
      base = root_export(ctx)

      variants = [
        base,
        put_in(base, ["fabric_verifier", "steps"], [%{"id" => "é✓", "status" => "pass"}]),
        Map.put(base, "bridge", Map.put(base["bridge"], "work_order_digest", "nested-is-kept")),
        Map.put(base, "final_head", nil),
        Map.put(base, "extra", [%{"z" => 1, "a" => [true, false, nil]}, 3.5, "s"])
      ]

      for export <- variants do
        assert SemanticReceipt.receipt_digest(export) == SemanticJira.digest(export)
      end
    end

    test "they DIVERGE on a reserved top-level key: the kernel drops it, the export digest binds it",
         ctx do
      base = root_export(ctx)

      for key <-
            ~w(work_order_digest transition_digest evidence_digest experience_digest repair_digest finding_digest composition_digest) do
        tampered = Map.put(base, key, "forged")

        assert SemanticJira.digest(tampered) == SemanticJira.digest(base)
        refute SemanticReceipt.receipt_digest(tampered) == SemanticReceipt.receipt_digest(base)
      end
    end
  end

  describe "the A2A projection stays consistent with the descriptor" do
    test "task metadata carries the descriptor's graph identity verbatim; authority NONE", ctx do
      {v1, _execution} = descriptor!(ctx.graph, ctx.dir, "FIX-BROKEN", ctx.opts)
      assert {:ok, task} = Bridge.a2a_task(v1, ctx.root)

      assert task["taskId"] == "urn:" <> ctx.root["replay_identity"]
      assert task["contextId"] == v1["graph_digest"]
      assert task["metadata"]["definitionDigest"] == v1["definition_digest"]
      assert task["metadata"]["snapshotDigest"] == v1["snapshot_digest"]
      assert task["metadata"]["baseSha"] == v1["base_sha"]
      assert task["metadata"]["graphDigest"] == v1["graph_digest"]
      assert task["metadata"]["authority"] == v1["authority"]
      assert task["metadata"]["schema"] == v1["schema"]

      assert [%{"kind" => "data", "data" => data}] = task["input"]
      assert data["definition_digest"] == v1["definition_digest"]
    end

    test "a task for a drifted work order is refused (the descriptor no longer describes it)",
         ctx do
      {v1, _execution} = descriptor!(ctx.graph, ctx.dir, "FIX-BROKEN", ctx.opts)
      drifted = Map.put(ctx.root, "description", "Changed after the descriptor was emitted.")

      assert {:error, {:refused_bridge, {:a2a, {:identity_mismatch, "definition_digest"}}}} =
               Bridge.a2a_task(v1, drifted)
    end

    test "the agent card the pack manufactures agrees with the descriptor and the task state",
         ctx do
      {v1, _execution} = descriptor!(ctx.graph, ctx.dir, "FIX-BROKEN", ctx.opts)
      card = golden_agent_card()

      # authority: the card, the descriptor and the task all say NONE
      assert card["authority"] == "NONE"
      assert v1["authority"] == card["authority"]
      assert {:ok, task} = Bridge.a2a_task(v1, ctx.root)
      assert task["metadata"]["authority"] == card["authority"]

      # the card's state map IS the ontology map the task state is derived from
      ontology_rows =
        SemanticA2A.state_map()
        |> Enum.map(
          &%{
            "standing" => &1.standing,
            "receipted" => &1.receipted,
            "state" => &1.state,
            "reasonCode" => &1.reason_code
          }
        )
        |> Enum.sort_by(&{&1["standing"], &1["receipted"]})

      assert card["stateMap"] == ontology_rows

      # the UNKNOWN work order the descriptor was emitted for is a state the card declares
      state = task["status"]["state"]
      assert Enum.any?(card["stateMap"], &(&1["standing"] == "UNKNOWN" and &1["state"] == state))

      # ALIVE completes a task only with a valid receipt, and the card says the same
      assert {:ok, %{state: "completed"}} =
               SemanticA2A.state_for("ALIVE", [
                 SemanticA2A.receipt(%{"work_order" => "FIX-BROKEN"})
               ])

      assert Enum.any?(
               card["stateMap"],
               &(&1["standing"] == "ALIVE" and &1["receipted"] == "true" and
                   &1["state"] == "completed")
             )

      assert {:error, {:refused, :completed_requires_alive_with_receipt}} =
               SemanticA2A.admit_completion("ALIVE", [])

      # skills advertised by the card never include a consequential DO capability
      names = Enum.map(card["skills"], & &1["semanticSkill"])

      for forbidden <- ~w(push_candidate publish_candidate run_exact_head_court),
          do: refute(forbidden in names)

      assert card["refusedSkills"] |> Enum.map(& &1["name"]) |> Enum.sort() ==
               Enum.sort(~w(publish_candidate push_candidate run_exact_head_court))
    end
  end

  # The pack's own a2a_agent_card template, rendered over the pack's real
  # ontology through its real SPARQL gates (the same projection `mix
  # ggen_igniter.sync --pack semantic-jira-pack:a2a_agent_card` writes).
  defp golden_agent_card do
    pack = SemanticA2A.pack_dir()
    graph = GgenIgniter.Ontology.load!(SemanticA2A.ontology_path())

    gate = fn name ->
      GgenIgniter.Query.run(graph, File.read!(Path.join([pack, "gates", name])))
    end

    template =
      [pack, "templates", "a2a_agent_card.json.eex"]
      |> Path.join()
      |> File.read!()
      |> String.replace(~r/\A---\n.*?\n---\n/s, "")

    template
    |> GgenIgniter.Render.render(
      a2a_target: gate.("063_a2a_target.rq"),
      a2a_skills: gate.("060_a2a_skills.rq"),
      a2a_refusals: gate.("062_a2a_refusals.rq"),
      a2a_state_map: gate.("061_a2a_state_map.rq")
    )
    |> Jason.decode!()
  end
end
