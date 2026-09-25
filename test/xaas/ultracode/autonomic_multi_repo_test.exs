defmodule Xaas.Ultracode.AutonomicMultiRepoTest do
  use ExUnit.Case, async: false

  @moduledoc """
  The Campaign-3 qualification: ONE autonomic wave over SEVERAL repositories
  (`repo: "nounverb,eds"`), every collaborator real except the LLM -- the real
  per-repo backlog scripts, real git worktrees, real leases, and the REAL
  per-repo verifier suites (`eds-dod`, `nounverb-dod`) as the courts.

  The worker is the same scripted protocol client shape as the single-repo
  suite (`autonomic_test.exs`), except it needs no domain work: the target
  suites are the cheapest sound check (compile + tests, no ticket semantics),
  so a worker that claims, commits (empty -- the suites are green at base and
  must STAY green), and closes honestly is exactly the worker under test.

  What this test proves (the step-[7] handoff law, multi-repo-run.md §10):

    * one wave senses BOTH repos with their OWN scripts at their OWN base
      shas, and the ledger `start` event names every repo with its per-repo
      base sha;
    * items carry their repo through dispatch, the epoch subject, and the
      RUN's `execution_repo_alias` (per-repo attribution);
    * each repo's item is judged by THAT repo's suite, and each repo gets its
      OWN integration worktree + canonical court at the integration head;
    * the standing law is the same across repos: ALIVE only when every item
      is done AND every repo's canonical court passes.
  """

  alias Xaas.Ultracode.{Autonomic, Epoch, Lease, Receipt, Run, TargetSuites}

  @provider "zcode-multi-autonomic-test"
  @nv_source Path.expand("~/xaas/worktrees/repos/nounverb")
  @eds_source Path.expand("~/xaas/worktrees/repos/eds")

  # The last eds sha with a GREEN suite (59 passed, observed this session).
  # The operator clone's HEAD (`w7-crown-seed` @ 0132a24) carries the crown
  # chain's deliberately-seeded RED condition (test_w7_crown_seed.py's
  # casefold guard) whose landed fix is incomplete -- so an empty-commit
  # worker could never satisfy eds-dod at HEAD. This test pins the TEST's
  # own clone to the green base; the LIVE campaign scopes eds out until the
  # seed is closed (recorded failed edge, wave-9 dispatch).
  @eds_green_base "02f7c98"

  @moduletag :subprocess
  @moduletag timeout: 1_200_000

  @moduletag skip:
               (cond do
                  not File.dir?(Path.join(@nv_source, ".git")) ->
                    "operator nounverb clone missing at #{@nv_source}"

                  not File.dir?(Path.join(@eds_source, ".git")) ->
                    "operator eds clone missing at #{@eds_source}"

                  is_nil(System.find_executable("python3")) ->
                    "python3 not on PATH"

                  not is_binary(System.get_env("MIX_ARCHIVES")) and
                      not File.dir?(Path.expand("~/xaas/worktrees/toolchain/mix-archives")) ->
                    "pinned MIX_ARCHIVES missing (nounverb-dod deps step would hang)"

                  true ->
                    false
                end)

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    keys = [
      :ultracode_verifier_suites,
      :ultracode_worktree_root,
      :ultracode_ticket_dir,
      :ultracode_repos,
      :ultracode_backlog_scripts
    ]

    original = for key <- keys, into: %{}, do: {key, Application.get_env(:xaas, key)}

    base = mktmp("base")
    nv = Path.join(base, "nounverb")
    eds = Path.join(base, "eds")

    {_, 0} = System.cmd("git", ["clone", "-q", @nv_source, nv], stderr_to_stdout: true)
    {_, 0} = System.cmd("git", ["clone", "-q", @eds_source, eds], stderr_to_stdout: true)

    {_, 0} =
      System.cmd("git", ["-C", eds, "checkout", "-q", "--detach", @eds_green_base],
        stderr_to_stdout: true
      )

    # The REAL suite declarations (exactly what Campaign 3's fabric court
    # runs) and the REAL per-repo backlog scripts.
    suites = Map.take(TargetSuites.devs(), ["nounverb-dod", "eds-dod"])

    Application.put_env(:xaas, :ultracode_worktree_root, Path.join(base, "runs"))
    Application.put_env(:xaas, :ultracode_ticket_dir, Path.join(base, "tickets"))

    Application.put_env(:xaas, :ultracode_repos, %{
      "nounverb" => %{
        "path" => nv,
        "suite" => "nounverb-dod",
        "canonical_suite" => "nounverb-dod"
      },
      "eds" => %{"path" => eds, "suite" => "eds-dod", "canonical_suite" => "eds-dod"}
    })

    Application.put_env(:xaas, :ultracode_verifier_suites, suites)

    Application.put_env(:xaas, :ultracode_backlog_scripts, %{
      "nounverb" => "nounverb_backlog.py",
      "eds" => "eds_backlog.py"
    })

    on_exit(fn ->
      for {key, value} <- original do
        if is_nil(value),
          do: Application.delete_env(:xaas, key),
          else: Application.put_env(:xaas, key, value)
      end
    end)

    %{base: base, nv: nv, eds: eds}
  end

  test "one wave works several repos end to end: per-repo sense, courts, integration, attribution",
       %{
         nv: nv,
         eds: eds
       } do
    # The bounded backlog: the FIRST sensed item of each repo (deterministic
    # id order), so the wave proves the per-repo machinery without working
    # every open item the clones happen to have.
    [%{"id" => nv_item} | _] = sense_items("nounverb", nv)
    [%{"id" => eds_item} | _] = sense_items("eds", eds)

    nv_base = git(nv, ["rev-parse", "HEAD"])
    eds_base = git(eds, ["rev-parse", "HEAD"])

    worker = fn epoch, _ctx ->
      worker_id = "scripted-multi-#{String.slice(epoch.id, 0, 8)}"

      {:ok, claimed, token, _run} = Lease.claim_next(@provider, worker_id, epoch_id: epoch.id)
      worktree = claimed.worktree

      env = [
        {"GIT_AUTHOR_NAME", "scripted"},
        {"GIT_AUTHOR_EMAIL", "s@s"},
        {"GIT_COMMITTER_NAME", "scripted"},
        {"GIT_COMMITTER_EMAIL", "s@s"}
      ]

      # The target suites are the cheapest sound check: the suites are green
      # at base and an empty commit keeps them green at the worker's head.
      {_, 0} =
        System.cmd("git", ["-C", worktree, "commit", "-q", "--allow-empty", "-m", "multi smoke"],
          env: env
        )

      head = git(worktree, ["rev-parse", "HEAD"])

      {:ok, _epoch, _receipt} =
        Lease.close(token, head, :alive, %{"note" => "scripted multi-repo worker"})

      :ok
    end

    assert {:ok, report} =
             Autonomic.run(
               repo: "nounverb,eds",
               provider: @provider,
               worker: worker,
               capacity: 2,
               max_attempts: 2,
               rate_backoff_ms: 10,
               only: [nv_item, eds_item]
             )

    # The standing law across repos: every item done AND every repo's own
    # canonical court passed.
    assert report["standing"] == "ALIVE"
    assert report["repo"] == ["eds", "nounverb"]

    assert report["base_shas"] == %{"eds" => eds_base, "nounverb" => nv_base}

    # One done item per repo, each tagged with its repo, each court-verified.
    assert length(report["items"]) == 2

    assert %{"status" => "done"} = Enum.find(report["items"], &(&1["item"] == nv_item))
    assert %{"status" => "done"} = Enum.find(report["items"], &(&1["item"] == eds_item))
    assert Enum.all?(report["items"], &(&1["fabric_verifier"]["status"] == "pass"))

    repos_of_items = Enum.map(report["items"], & &1["repo"]) |> Enum.sort()
    assert repos_of_items == ["eds", "nounverb"]

    # Per-repo suites: the eds item was judged by eds-dod, the nounverb item
    # by nounverb-dod (the fabric verdict names the suite).
    by_item = Map.new(report["items"], &{&1["item"], &1})
    assert by_item[eds_item]["fabric_verifier"]["suite"] == "eds-dod"
    assert by_item[nv_item]["fabric_verifier"]["suite"] == "nounverb-dod"

    # Each repo got its OWN integration worktree + its OWN canonical court.
    assert MapSet.new(Map.keys(report["integration"])) == MapSet.new(["eds", "nounverb"])
    assert MapSet.new(Map.keys(report["canonical"])) == MapSet.new(["eds", "nounverb"])

    for {alias, integration} <- report["integration"] do
      assert integration["head"] != report["base_shas"][alias]
      assert integration["branch"] =~ "#{alias}-autonomic-"
      assert report["canonical"][alias]["status"] == "pass"
    end

    # Per-repo attribution rode on the RUN rows.
    runs =
      Enum.filter(
        Ash.read!(Run, action: :read_unscoped, authorize?: false),
        &(&1.provider == @provider)
      )

    assert length(runs) == 2
    aliases = Enum.map(runs, & &1.execution_repo_alias) |> Enum.sort()
    assert aliases == ["eds", "nounverb"]

    # The epochs' exact subjects name their repo.
    subjects =
      for run <- runs,
          epoch <- Ash.read!(Epoch, action: :read_unscoped, authorize?: false),
          epoch.run_id == run.id,
          do: epoch.exact_subject

    assert Enum.any?(subjects, &String.starts_with?(&1, "eds-autonomic:#{eds_item}#"))
    assert Enum.any?(subjects, &String.starts_with?(&1, "nounverb-autonomic:#{nv_item}#"))

    # The ledger start event names EVERY repo with its per-repo base sha --
    # the exact step-[7] acceptance fact.
    lines = ledger_lines(report)

    assert [%{"data" => %{"repo" => ["eds", "nounverb"], "repos" => repos}}] =
             Enum.filter(lines, &(&1["event"] == "start"))

    assert Map.keys(repos) |> Enum.sort() == ["eds", "nounverb"]
    assert repos["eds"] == eds_base and repos["nounverb"] == nv_base

    # The receipt invariant holds per repo: every done item sealed a
    # head-verified, court-pass receipt.
    for item_id <- [nv_item, eds_item] do
      assert [%{evidence: evidence, fv: fv} | _] = receipts_for_item(item_id)
      assert evidence["head_verified"] == true
      assert fv["status"] == "pass"
    end
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  defp sense_items(repo_alias, repo_path) do
    script_name =
      Application.get_env(:xaas, :ultracode_backlog_scripts)
      |> Map.fetch!(repo_alias)

    script = Path.join(:code.priv_dir(:xaas), Path.join("verifiers", script_name))

    {out, 0} =
      System.cmd("python3", [script, "--repo", repo_path],
        env: [{"PYTHONDONTWRITEBYTECODE", "1"}]
      )

    %{"items" => items} = Jason.decode!(out)
    items
  end

  defp receipts_for_item(item_id) do
    for run <- Ash.read!(Run, action: :read_unscoped, authorize?: false),
        run.provider == @provider,
        epoch <- Ash.read!(Epoch, action: :read_unscoped, authorize?: false),
        epoch.run_id == run.id,
        String.contains?(epoch.exact_subject, "#{item_id}#"),
        receipt <-
          Receipt
          |> Ash.Query.for_read(:for_epoch, %{epoch_id: epoch.id})
          |> Ash.read!(authorize?: false),
        Map.has_key?(receipt.evidence, "head_verified") do
      %{
        outcome: receipt.outcome,
        evidence: receipt.evidence,
        fv: receipt.evidence["fabric_verifier"] || %{}
      }
    end
  end

  defp ledger_lines(report) do
    report["receipt_path"]
    |> Path.dirname()
    |> Path.join("ledger.ndjson")
    |> File.stream!()
    |> Enum.map(&Jason.decode!/1)
  end

  defp git(repo, args) do
    {out, 0} = System.cmd("git", ["-C", repo | args], stderr_to_stdout: true)
    String.trim(out)
  end

  defp mktmp(name) do
    dir =
      Path.join(System.tmp_dir!(), "#{name}-#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    dir
  end
end
