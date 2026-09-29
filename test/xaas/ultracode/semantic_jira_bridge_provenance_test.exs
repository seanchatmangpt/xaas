defmodule Xaas.Ultracode.SemanticJiraBridgeProvenanceTest do
  @moduledoc """
  Court-mode provenance, end to end against real sealed receipts (real Postgres,
  real git worktree, the real `Lease.close/4` fabric verifier running a real
  subprocess suite; the worker is a scripted protocol client, no doubles).

  The court map is in force here, so the fabric PRODUCES the IRI-keyed court
  receipt from what `check.sh` prints. `check.sh` lives in the worker's worktree,
  so a worker that rewrites it authors the verdicts. The court refuses that:
  the files that decide a verdict must be the ones the work order was minted
  against (`Xaas.Ultracode.Verifier`, verdict-source pinning). Without the pin, a
  worker that fixes NOTHING and rewrites `check.sh` to print the mapped `PASSED`
  lines is promoted to ALIVE (observed before the fix: `admit_epoch` returned an
  `ALIVE` event for un-fixed work).
  """

  use Xaas.Ultracode.SemanticCase, async: false

  # Needs ggen_igniter >= 26.9.20 (SemanticJira Shacl/TransitionLog.event_digest/1).
  @moduletag :requires_semantic_jira_api

  alias Xaas.Ultracode.{Lease, Receipt, SemanticReceipt, SemanticWork}
  alias Xaas.Ultracode.SemanticJiraBridge, as: Bridge
  alias Xaas.Ultracode.SemanticJiraBridgeFixtures, as: F

  @provider "zcode-provenance"
  @exec_alias "provenance-demo"

  @check_sh """
  rc=0
  if [ -e BROKEN ]; then echo "check.sh::broken_absent FAILED"; rc=1; else echo "check.sh::broken_absent PASSED"; fi
  if [ -f hello.txt ]; then echo "check.sh::no_regression PASSED"; else echo "check.sh::no_regression FAILED"; rc=1; fi
  exit $rc
  """

  # prints the mapped PASSED lines whatever the tree looks like
  @forged_check_sh """
  echo "check.sh::broken_absent PASSED"
  echo "check.sh::no_regression PASSED"
  exit 0
  """

  setup ctx do
    keys = [
      :ultracode_repos,
      :ultracode_worktree_root,
      :ultracode_verifier_suites,
      :ultracode_ticket_dir
    ]

    original = Map.new(keys, &{&1, Application.get_env(:xaas, &1)})

    base = F.tmp_dir("provenance")
    on_exit(fn -> File.rm_rf(base) end)
    repo = Path.join(base, "repo")
    File.mkdir_p!(repo)
    sha = seed_repo(repo)

    Application.put_env(:xaas, :ultracode_repos, %{@exec_alias => repo})
    Application.put_env(:xaas, :ultracode_worktree_root, Path.join(base, "runs"))
    Application.put_env(:xaas, :ultracode_ticket_dir, Path.join(base, "tickets"))

    Application.put_env(:xaas, :ultracode_verifier_suites, %{
      "provenance-suite" => %{
        env: %{"PATH" => "/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin"},
        max_output_bytes: 8192,
        result_format: "pytest_v",
        steps: [%{id: "court", argv: ["/bin/sh", "check.sh"], timeout_ms: 20_000, receipt: true}]
      }
    })

    on_exit(fn -> Enum.each(original, fn {key, value} -> restore_env(key, value) end) end)

    work_order = F.work_order("FIX-BROKEN", sha)

    Map.merge(ctx, %{
      graph: [work_order],
      log: Path.join(base, "log")
    })
  end

  defp materialize!(ctx) do
    assert {:ok, %{execution: execution}} =
             Bridge.descriptor(ctx.graph, ctx.log, "FIX-BROKEN",
               execution_repo_alias: @exec_alias,
               verifier_suite: "provenance-suite",
               provider: @provider,
               graph_digest: F.graph_digest(),
               shapes: F.shapes(),
               court_map:
                 F.court_map("FIX-BROKEN", "check.sh::broken_absent", "check.sh::no_regression")
             )

    assert Map.has_key?(execution, "court_map")
    assert {:ok, %{epoch: epoch, worktree: worktree}} = SemanticWork.materialize(execution)
    {epoch, worktree}
  end

  defp fabric_reason(epoch) do
    [receipt] =
      Receipt
      |> Ash.Query.for_read(:for_epoch, %{epoch_id: epoch.id})
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&Map.has_key?(&1.evidence, "head_verified"))

    receipt.evidence["fabric_verifier"]["reason"]
  end

  test "control: an honest fix with the court's script untouched is promoted", ctx do
    {epoch, worktree} = materialize!(ctx)

    work(epoch, worktree, fn wt ->
      File.rm!(Path.join(wt, "BROKEN"))
      File.write!(Path.join(wt, "notes.txt"), "the fix\n")
    end)

    assert {:ok, export} = SemanticReceipt.export(epoch.id)
    assert export["outcome"] == "alive"
    assert %{"binding" => %{"step_id" => "court"}} = export["fabric_verifier"]["court_receipt"]

    assert {:ok, %{disposition: :appended, event: %{"to" => "ALIVE"}}} =
             Bridge.admit_epoch(ctx.graph, "FIX-BROKEN", epoch.id, ctx.log)
  end

  test "a worker that fixes nothing and rewrites check.sh to print PASSED is not promoted",
       ctx do
    {epoch, worktree} = materialize!(ctx)

    work(epoch, worktree, &File.write!(Path.join(&1, "check.sh"), @forged_check_sh))
    assert File.exists?(Path.join(worktree, "BROKEN"))

    # the court could not witness the verdicts: sealed partial_alive, no court receipt
    assert {:ok, export} = SemanticReceipt.export(epoch.id)
    assert export["outcome"] == "partial_alive"
    assert export["fabric_verifier"]["status"] == "error"
    refute Map.has_key?(export["fabric_verifier"], "court_receipt")

    reason = fabric_reason(epoch)
    assert reason =~ "verdict_source_modified" and reason =~ "check.sh"

    result = Bridge.admit_epoch(ctx.graph, "FIX-BROKEN", epoch.id, ctx.log)

    refute match?({:ok, %{event: %{"to" => "ALIVE"}}}, result),
           "un-fixed work was promoted to ALIVE: #{inspect(result, limit: 4)}"

    assert Bridge.state(ctx.graph, ctx.log)["standings"]["FIX-BROKEN"] != "ALIVE"
  end

  test "an honest-looking edit of the court's script is refused too", ctx do
    {epoch, worktree} = materialize!(ctx)

    work(epoch, worktree, fn wt ->
      File.rm!(Path.join(wt, "BROKEN"))
      File.write!(Path.join(wt, "check.sh"), @check_sh <> "# tidied\n")
    end)

    assert {:ok, export} = SemanticReceipt.export(epoch.id)
    assert export["outcome"] == "partial_alive"
    assert fabric_reason(epoch) =~ "verdict_source_modified"

    result = Bridge.admit_epoch(ctx.graph, "FIX-BROKEN", epoch.id, ctx.log)
    refute match?({:ok, %{event: %{"to" => "ALIVE"}}}, result)
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

  defp seed_repo(repo) do
    {_, 0} =
      System.cmd("git", ["-C", repo, "init", "--quiet", "-b", "main"], stderr_to_stdout: true)

    File.write!(Path.join(repo, "check.sh"), @check_sh)
    File.write!(Path.join(repo, "hello.txt"), "hello\n")
    File.write!(Path.join(repo, "BROKEN"), "the bounded failing condition\n")
    run_git!(repo, ["add", "-A"])
    run_git!(repo, ["commit", "-q", "-m", "seed failing condition"], commit_env())
    run_git!(repo, ["rev-parse", "HEAD"])
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
