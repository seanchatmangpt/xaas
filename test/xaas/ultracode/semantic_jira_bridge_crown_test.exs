defmodule Xaas.Ultracode.SemanticJiraBridgeCrownTest do
  @moduledoc """
  The Semantic Jira <-> Ultracode crown, Chicago-style and end to end, with the
  graph side called in-process through `Xaas.Ultracode.SemanticJiraBridge`.

  Every collaborator is real except the model's judgment:

    * a real git repository with a real failing condition (`BROKEN` present, so
      `check.sh` exits 1) at an exact base SHA;
    * the real `ggen_igniter` kernel, SHACL court, `Reconciler` and file-backed
      `TransitionLog` (`GgenIgniter.SemanticJira.*`);
    * sandboxed Postgres, real `SemanticWork.materialize/2` (Run, Epoch, git
      worktree at the exact base SHA), real leases, and the REAL
      `Lease.close/4` fabric verifier running a real subprocess suite whose
      per-test output the fabric turns into the IRI-keyed court receipt;
    * the sealed receipt is read back from Postgres by
      `SemanticReceipt.export/1` -- no export in this file is hand-written.

  The worker is a scripted protocol client (claim, edit, commit, close). It
  stands in only for the model's judgment; nothing decides "done" except the
  fabric court. The crown ends by killing the producer process and replaying
  the standing state from a copy of the log alone.
  """

  use Xaas.Ultracode.SemanticCase, async: false

  # Needs ggen_igniter >= 26.9.20 (SemanticJira Shacl/TransitionLog.event_digest/1).

  alias GgenIgniter.SemanticJira
  alias GgenIgniter.SemanticJira.TransitionLog
  alias Xaas.Ultracode.{Epoch, Lease, Run, SemanticReceipt, SemanticWork}
  alias Xaas.Ultracode.SemanticJiraBridge, as: Bridge
  alias Xaas.Ultracode.SemanticJiraBridgeFixtures, as: F

  @provider "zcode-bridge"
  @exec_alias "bridge-demo"

  @check_sh """
  rc=0
  if [ -e BROKEN ]; then echo "check.sh::broken_absent FAILED"; rc=1; else echo "check.sh::broken_absent PASSED"; fi
  if [ -f hello.txt ]; then echo "check.sh::no_regression PASSED"; else echo "check.sh::no_regression FAILED"; rc=1; fi
  exit $rc
  """

  @verify_sh """
  rc=0
  if [ -e BROKEN ]; then echo "verify.sh::broken_absent FAILED"; rc=1; else echo "verify.sh::broken_absent PASSED"; fi
  if [ -f VERIFIED ]; then echo "verify.sh::verified_marker PASSED"; else echo "verify.sh::verified_marker FAILED"; rc=1; fi
  exit $rc
  """

  setup ctx do
    keys = [
      :ultracode_repos,
      :ultracode_worktree_root,
      :ultracode_verifier_suites,
      :ultracode_ticket_dir
    ]

    original = Map.new(keys, &{&1, Application.get_env(:xaas, &1)})

    base = F.tmp_dir("bridge")
    on_exit(fn -> File.rm_rf(base) end)
    repo = Path.join(base, "repo")
    File.mkdir_p!(repo)
    sha = init_failing_repo(repo)

    Application.put_env(:xaas, :ultracode_repos, %{@exec_alias => repo})
    Application.put_env(:xaas, :ultracode_worktree_root, Path.join(base, "runs"))
    Application.put_env(:xaas, :ultracode_ticket_dir, Path.join(base, "tickets"))

    Application.put_env(:xaas, :ultracode_verifier_suites, %{
      "bridge-fix" => suite("check.sh"),
      "bridge-verify" => suite("verify.sh")
    })

    on_exit(fn -> Enum.each(original, fn {key, value} -> restore_env(key, value) end) end)

    log = Path.join(base, "log")
    root = F.work_order("FIX-BROKEN", sha)
    dependent = F.work_order("VERIFY-CLEAN", sha, ["FIX-BROKEN"])

    Map.merge(ctx, %{
      repo: repo,
      base_sha: sha,
      log: log,
      root: root,
      dependent: dependent,
      graph: [root, dependent],
      graph_path: write_graph(base, [root, dependent])
    })
  end

  test "crown: failing condition -> candidate -> SHACL -> frontier -> descriptor -> real receipt -> transition -> dependent eligible -> kill producer -> replay",
       ctx do
    # 1. the bounded failing condition is real at the exact base SHA
    {out0, code0} = System.cmd("sh", ["check.sh"], cd: ctx.repo, stderr_to_stdout: true)
    assert code0 == 1
    assert out0 =~ "check.sh::broken_absent FAILED"

    # 2. observed process finding: a candidate with no authority
    assert {:ok, finding} =
             SemanticJira.process_finding(%{
               "normative_model_digest" => GgenIgniter.Digest.sha256("check.sh: BROKEN absent"),
               "observed_model_digest" => GgenIgniter.Digest.sha256("BROKEN at #{ctx.base_sha}"),
               "delta" => "BROKEN exists",
               "observation_receipt_digest" => GgenIgniter.Digest.sha256(out0)
             })

    assert finding["admission_state"] == "CANDIDATE" and finding["authority"] == "NONE"

    # 3. candidate WorkOrders: kernel + real SHACL admission; a branch name is not a SHA
    for work_order <- ctx.graph do
      assert {:ok, _} = Bridge.admit_candidate(work_order, shapes: F.shapes())
    end

    assert {:error, {:refused_bridge, {:unadmitted, _}}} =
             Bridge.admit_candidate(Map.put(ctx.root, "base_sha", "main"), shapes: F.shapes())

    assert {:error, {:refused_bridge, {:shacl, _}}} =
             Bridge.admit_candidate(Map.put(ctx.root, "identity", "fix-broken"),
               shapes: F.shapes()
             )

    # 4. frontier over the (empty) log: only the root is eligible
    assert %{
             eligible: [%{"identity" => "FIX-BROKEN"}],
             blocked: [%{"identity" => "VERIFY-CLEAN"}]
           } =
             Bridge.frontier(ctx.graph, ctx.log)

    # 5. descriptor from the admitted frontier; the dependent gets none yet
    assert {:error, {:refused_bridge, {:not_on_frontier, "dependencies_unsatisfied"}}} =
             Bridge.descriptor(ctx.graph, ctx.log, "VERIFY-CLEAN", opts("VERIFY-CLEAN"))

    {v1, execution} = descriptor!(ctx, "FIX-BROKEN")
    assert v1["definition_digest"] == execution["bridge"]["definition_digest"]
    assert v1["snapshot_digest"] == execution["bridge"]["source_snapshot_digest"]

    # 6. real Run/Epoch/worktree at the exact base SHA
    assert {:ok, %{run: run, epoch: epoch, worktree: worktree}} =
             SemanticWork.materialize(execution)

    assert run_git!(worktree, ["rev-parse", "HEAD"]) == ctx.base_sha
    assert run.semantic_bridge == execution["bridge"]

    # 7. the worker fixes the condition and closes; the FABRIC judges the exact head
    head = work(epoch, worktree, &File.rm!(Path.join(&1, "BROKEN")))

    # 8. the real sealed receipt, read back from Postgres
    assert {:ok, export} = SemanticReceipt.export(epoch.id)
    assert export["outcome"] == "alive" and export["head_verified"] == true
    assert export["final_head"] == head
    assert export["fabric_verifier"]["status"] == "pass"
    assert export["bridge"] == execution["bridge"]
    assert export["receipt_digest"] == SemanticReceipt.receipt_digest(export)

    court = export["fabric_verifier"]["court_receipt"]
    assert court["binding"]["head"] == head and court["binding"]["step_id"] == "court"
    assert court["acceptance_results"] == %{F.acceptance_iri("FIX-BROKEN") => true}
    assert court["falsifier_results"] == %{F.falsifier_iri("FIX-BROKEN") => "survived"}

    # 9. the graph side admits it: transition appended, NEW frontier returned
    assert {:ok, %{event: event, disposition: :appended, receipt: receipt, frontier: front}} =
             Bridge.admit_epoch(ctx.graph, "FIX-BROKEN", epoch.id, ctx.log)

    assert event["from"] == "UNKNOWN" and event["to"] == "ALIVE" and event["authority"] == "NONE"
    assert event["definition_digest"] == v1["definition_digest"]
    assert receipt["candidate_sha"] == head
    assert receipt["xaas"]["receipt_digest"] == export["receipt_digest"]
    assert ["VERIFY-CLEAN"] == Enum.map(front.eligible, & &1["identity"])

    # 10. the dependent: descriptor carries the upstream ALIVE receipt edge, runs the same way
    {_v1, dep_execution} = descriptor!(ctx, "VERIFY-CLEAN")
    assert [edge] = dep_execution["dependencies"]
    assert edge["receipt_digest"] == event["receipt_digest"]

    assert {:ok, %{epoch: dep_epoch, worktree: dep_worktree}} =
             SemanticWork.materialize(dep_execution)

    work(dep_epoch, dep_worktree, fn wt ->
      File.rm!(Path.join(wt, "BROKEN"))
      File.write!(Path.join(wt, "VERIFIED"), "clean\n")
    end)

    # 11. the second transition is admitted by a PRODUCER process, which is then killed
    parent = self()

    producer =
      spawn(fn ->
        result = Bridge.admit_epoch(ctx.graph, "VERIFY-CLEAN", dep_epoch.id, ctx.log)
        send(parent, {:produced, self(), result})
        Process.sleep(:infinity)
      end)

    assert_receive {:produced, ^producer, {:ok, %{disposition: :appended, frontier: final}}},
                   60_000

    assert final.eligible == []

    live = Bridge.state(ctx.graph, ctx.log)
    assert live["standings"] == %{"FIX-BROKEN" => "ALIVE", "VERIFY-CLEAN" => "ALIVE"}
    assert live["eligible"] == []

    assert [
             %{"seq" => 1, "identity" => "FIX-BROKEN"},
             %{"seq" => 2, "identity" => "VERIFY-CLEAN"}
           ] =
             live["events"]

    ref = Process.monitor(producer)
    Process.exit(producer, :kill)
    assert_receive {:DOWN, ^ref, :process, ^producer, :killed}
    refute Process.alive?(producer)

    # 12. replay from a COPY of the log alone, with the work orders re-read from disk:
    #     zero ticket editing, and the same frontier
    copy = ctx.log <> "-replay"
    on_exit(fn -> File.rm_rf(copy) end)
    File.cp_r!(ctx.log, copy)
    replayed_graph = ctx.graph_path |> File.read!() |> Jason.decode!()

    assert replayed_graph == ctx.graph
    assert Bridge.state(replayed_graph, copy) == live
    assert Bridge.frontier(replayed_graph, copy).eligible == []
    assert {:ok, d1} = SemanticJira.definition_digest(ctx.root)
    assert d1 == v1["definition_digest"]
    assert {:ok, ^d1} = SemanticJira.definition_digest(Map.put(ctx.root, "standing", "ALIVE"))

    # both epochs are sealed and completed in Postgres
    for id <- [epoch.id, dep_epoch.id] do
      assert Ash.get!(Epoch, id, action: :read_unscoped, authorize?: false).state == :completed
    end

    assert Ash.get!(Run, run.id, action: :read_unscoped, authorize?: false).id == run.id
  end

  @tag :subprocess
  test "replay in a fresh OS process from the copied log gives the same frontier", ctx do
    {_v1, execution} = descriptor!(ctx, "FIX-BROKEN")
    {:ok, %{epoch: epoch, worktree: worktree}} = SemanticWork.materialize(execution)
    work(epoch, worktree, &File.rm!(Path.join(&1, "BROKEN")))

    assert {:ok, %{disposition: :appended}} =
             Bridge.admit_epoch(ctx.graph, "FIX-BROKEN", epoch.id, ctx.log)

    live = ctx.graph |> Bridge.state(ctx.log) |> Jason.encode!() |> Jason.decode!()
    copy = ctx.log <> "-os-replay"
    on_exit(fn -> File.rm_rf(copy) end)
    File.cp_r!(ctx.log, copy)

    script = """
    graph = System.fetch_env!("SJB_GRAPH") |> File.read!() |> Jason.decode!()
    state = Xaas.Ultracode.SemanticJiraBridge.state(graph, System.fetch_env!("SJB_LOG"))
    IO.puts("SJB_STATE:" <> Jason.encode!(state))
    """

    {out, 0} =
      System.cmd(
        "mix",
        ["run", "--no-start", "--no-compile", "--no-deps-check", "-e", script],
        cd: File.cwd!(),
        stderr_to_stdout: true,
        env: [
          {"MIX_ENV", "test"},
          {"SJB_GRAPH", ctx.graph_path},
          {"SJB_LOG", copy}
        ]
      )

    [line] = out |> String.split("\n") |> Enum.filter(&String.starts_with?(&1, "SJB_STATE:"))
    replayed = line |> String.replace_prefix("SJB_STATE:", "") |> Jason.decode!()

    assert replayed == live
    assert replayed["eligible"] == ["VERIFY-CLEAN"]
  end

  describe "refusals against real sealed receipts" do
    test "a claimed ALIVE that fails the court is sealed build_broken and never promoted; a retry lands",
         ctx do
      {_v1, execution} = descriptor!(ctx, "FIX-BROKEN")
      {:ok, %{epoch: epoch, worktree: worktree}} = SemanticWork.materialize(execution)

      # the worker "fixes" nothing (BROKEN stays) but claims alive
      work(epoch, worktree, &File.write!(Path.join(&1, "notes.txt"), "no fix\n"))

      assert {:ok, export} = SemanticReceipt.export(epoch.id)
      assert export["outcome"] == "build_broken"
      assert export["fabric_verifier"]["status"] == "fail"

      assert export["fabric_verifier"]["court_receipt"]["acceptance_results"] ==
               %{F.acceptance_iri("FIX-BROKEN") => false}

      assert {:error, {:refused_bridge, {:promotion_refused, failed}}} =
               Bridge.admit_epoch(ctx.graph, "FIX-BROKEN", epoch.id, ctx.log)

      assert :courts in failed and :acceptance in failed
      assert TransitionLog.read(ctx.log) == []

      assert ["FIX-BROKEN"] ==
               Enum.map(Bridge.frontier(ctx.graph, ctx.log).eligible, & &1["identity"])

      # forgery: flip the sealed build_broken export to alive and RECOMPUTE its digest
      forged =
        F.reseal(export, fn e ->
          e |> Map.put("outcome", "alive") |> put_in(["fabric_verifier", "status"], "pass")
        end)

      assert {:error, {:refused_bridge, :export_not_sealed_by_fabric}} =
               Bridge.admit(ctx.graph, "FIX-BROKEN", forged, ctx.log)

      # ...and even offline (no fabric check) the missing court witness refuses it
      assert {:error, {:refused_bridge, {:promotion_refused, offline}}} =
               Bridge.admit(ctx.graph, "FIX-BROKEN", forged, ctx.log, fabric_check: false)

      assert :courts in offline and :acceptance in offline

      # tampering without recomputing the digest
      moved = Map.put(export, "final_head", F.sha("elsewhere"))

      assert {:error, {:refused_bridge, :receipt_digest_mismatch}} =
               Bridge.admit(ctx.graph, "FIX-BROKEN", moved, ctx.log)

      assert TransitionLog.read(ctx.log) == []

      # a retry (own checkpoint, own worktree) that really fixes it lands
      {_v1, retry} = descriptor!(ctx, "FIX-BROKEN", attempt: 2)
      assert retry["checkpoint_iri"] == execution["checkpoint_iri"] <> ":attempt-2"
      {:ok, %{epoch: epoch2, worktree: worktree2}} = SemanticWork.materialize(retry)
      work(epoch2, worktree2, &File.rm!(Path.join(&1, "BROKEN")))

      assert {:ok, %{disposition: :appended}} =
               Bridge.admit_epoch(ctx.graph, "FIX-BROKEN", epoch2.id, ctx.log)

      # the OLD failed epoch's receipt can never be replayed onto the now-ALIVE work order
      assert {:error, {:refused_bridge, {:not_on_frontier, "standing=ALIVE"}}} =
               Bridge.admit_epoch(ctx.graph, "FIX-BROKEN", epoch.id, ctx.log)

      assert length(TransitionLog.read(ctx.log)) == 1
    end

    test "a stale definition is refused without burning the receipt; the same export lands under the true definition",
         ctx do
      {_v1, execution} = descriptor!(ctx, "FIX-BROKEN")
      {:ok, %{epoch: epoch, worktree: worktree}} = SemanticWork.materialize(execution)
      work(epoch, worktree, &File.rm!(Path.join(&1, "BROKEN")))

      edited = Map.put(ctx.root, "description", "A later, different definition of the work.")

      assert {:error, {:refused_bridge, :definition_mismatch}} =
               Bridge.admit_epoch([edited, ctx.dependent], "FIX-BROKEN", epoch.id, ctx.log)

      assert TransitionLog.read(ctx.log) == []

      assert {:ok, %{disposition: :appended}} =
               Bridge.admit_epoch(ctx.graph, "FIX-BROKEN", epoch.id, ctx.log)

      assert {:ok, %{disposition: :already_recorded}} =
               Bridge.admit_epoch(ctx.graph, "FIX-BROKEN", epoch.id, ctx.log)

      assert length(TransitionLog.read(ctx.log)) == 1
    end

    test "without a court map the fabric witnesses no verdict: sealed alive, still not promoted",
         ctx do
      {_v1, execution} = descriptor!(ctx, "FIX-BROKEN", court_map: nil)
      refute Map.has_key?(execution, "court_map")
      {:ok, %{epoch: epoch, worktree: worktree}} = SemanticWork.materialize(execution)
      work(epoch, worktree, &File.rm!(Path.join(&1, "BROKEN")))

      assert {:ok, export} = SemanticReceipt.export(epoch.id)
      assert export["outcome"] == "alive"
      refute Map.has_key?(export["fabric_verifier"], "court_receipt")

      assert {:error, {:refused_bridge, {:promotion_refused, failed}}} =
               Bridge.admit_epoch(ctx.graph, "FIX-BROKEN", epoch.id, ctx.log)

      assert :acceptance in failed and :falsifiers in failed
      assert TransitionLog.read(ctx.log) == []
    end

    test "unsealed and unknown epochs are typed refusals", ctx do
      {_v1, execution} = descriptor!(ctx, "FIX-BROKEN")
      {:ok, %{epoch: open}} = SemanticWork.materialize(execution)

      assert {:error, {:refused_bridge, {:no_sealed_receipt, {:epoch_not_completed, :running}}}} =
               Bridge.admit_epoch(ctx.graph, "FIX-BROKEN", open.id, ctx.log)

      assert {:error, {:refused_bridge, {:no_sealed_receipt, :epoch_not_found}}} =
               Bridge.admit_epoch(ctx.graph, "FIX-BROKEN", Ecto.UUID.generate(), ctx.log)

      export = F.export(ctx.root, execution["bridge"])

      assert {:error, {:refused_bridge, {:no_sealed_receipt, :epoch_not_found}}} =
               Bridge.admit(ctx.graph, "FIX-BROKEN", export, ctx.log)

      assert TransitionLog.read(ctx.log) == []
    end
  end

  # -- descriptor options ------------------------------------------------------

  defp opts(identity, overrides \\ []) do
    {suite, acceptance, falsifier} =
      case identity do
        "FIX-BROKEN" ->
          {"bridge-fix", "check.sh::broken_absent", "check.sh::no_regression"}

        "VERIFY-CLEAN" ->
          {"bridge-verify", "verify.sh::verified_marker", "verify.sh::broken_absent"}
      end

    Keyword.merge(
      [
        execution_repo_alias: @exec_alias,
        verifier_suite: suite,
        provider: @provider,
        graph_digest: F.graph_digest(),
        shapes: F.shapes(),
        court_map: F.court_map(identity, acceptance, falsifier)
      ],
      overrides
    )
  end

  defp descriptor!(ctx, identity, overrides \\ []) do
    assert {:ok, %{descriptor: v1, execution: execution}} =
             Bridge.descriptor(ctx.graph, ctx.log, identity, opts(identity, overrides))

    {v1, execution}
  end

  # -- the scripted worker (a protocol client: claim, edit, commit, close) --------

  defp work(epoch, worktree, edit) do
    {:ok, _claimed, token, _run} =
      Lease.claim_next(@provider, "worker-#{epoch.id}", epoch_id: epoch.id)

    edit.(worktree)
    run_git!(worktree, ["add", "-A"])
    run_git!(worktree, ["commit", "-q", "-m", "worker"], commit_env())
    head = run_git!(worktree, ["rev-parse", "HEAD"])
    {:ok, _epoch, _receipt} = Lease.close(token, head, :alive, %{"note" => "worker done"})
    head
  end

  # -- fixtures --------------------------------------------------------------------

  defp suite(script) do
    %{
      env: %{"PATH" => "/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin"},
      max_output_bytes: 8192,
      result_format: "pytest_v",
      steps: [
        %{id: "court", argv: ["/bin/sh", script], timeout_ms: 20_000, receipt: true}
      ]
    }
  end

  defp init_failing_repo(repo) do
    {_, 0} =
      System.cmd("git", ["-C", repo, "init", "--quiet", "-b", "main"], stderr_to_stdout: true)

    File.write!(Path.join(repo, "check.sh"), @check_sh)
    File.write!(Path.join(repo, "verify.sh"), @verify_sh)
    File.write!(Path.join(repo, "hello.txt"), "hello\n")
    File.write!(Path.join(repo, "BROKEN"), "the bounded failing condition\n")
    run_git!(repo, ["add", "-A"])
    run_git!(repo, ["commit", "-q", "-m", "seed failing condition"], commit_env())
    run_git!(repo, ["rev-parse", "HEAD"])
  end

  defp write_graph(base, graph) do
    path = Path.join(base, "work-orders.json")
    File.write!(path, Jason.encode!(graph))
    path
  end

  defp commit_env do
    [
      {"GIT_AUTHOR_NAME", "t"},
      {"GIT_AUTHOR_EMAIL", "t@t"},
      {"GIT_COMMITTER_NAME", "t"},
      {"GIT_COMMITTER_EMAIL", "t@t"}
    ]
  end

  defp run_git!(dir, args, env \\ []) do
    {out, 0} = System.cmd("git", ["-C", dir | args], stderr_to_stdout: true, env: env)
    String.trim(out)
  end
end
