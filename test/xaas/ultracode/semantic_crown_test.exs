defmodule Xaas.Ultracode.SemanticCrownTest do
  @moduledoc """
  The autonomics crown, Chicago-style and end to end. Every collaborator is
  real except the model: sandboxed Postgres, the real APS clone (exact base
  SHA), real git worktrees, the real Python backlog generator and
  definition-of-done court, real leases with the real `Lease.close/4` fabric
  verifier, and REAL `mix semantic_jira.*` OS processes in a ggen_igniter
  checkout for observation, SHACL admission, frontier, descriptor, receipt
  mapping and reconciliation.

  The worker is a scripted protocol client: it claims the exact epoch it is
  given, writes the tests a model worker wrote in the recorded live APS run
  (`aps-autonomic-3e46cf.bundle`), commits and closes. It stands in only for
  the model's judgment; nothing decides "done" except the fabric court.

  Tagged `:subprocess` and skipped by name when the operator APS clone,
  python3, mdbook or the ggen_igniter checkout is missing. Set
  `GGEN_IGNITER_DIR` to point at a checkout that carries the
  `semantic_jira.*` tasks (branch feat/semantic-jira-descriptor-bridge).
  """

  use ExUnit.Case, async: false

  alias Xaas.Ultracode.{Epoch, Lease, Run, SemanticCrown}

  @moduletag :subprocess
  @moduletag timeout: 1_800_000

  @source Path.expand("~/xaas/worktrees/repos/aps")
  @ggen_dir System.get_env("GGEN_IGNITER_DIR") || Path.expand("~/ggen_igniter")
  @bundle Path.expand(
            "docs/ultracode/wave-v26.9.17-receipts/aps-autonomic-dod/aps-autonomic-3e46cf.bundle"
          )
  @provider "zcode"
  @prefix "urn:semantic-jira:work-order:"

  @moduletag skip:
               (cond do
                  not File.dir?(Path.join(@source, ".git")) ->
                    "operator APS clone missing at #{@source}"

                  not File.regular?(@bundle) ->
                    "recorded live-run bundle missing at #{@bundle}"

                  not File.regular?(
                    Path.join(@ggen_dir, "lib/mix/tasks/semantic_jira.descriptor.ex")
                  ) ->
                    "ggen_igniter checkout with semantic_jira.descriptor missing at #{@ggen_dir}"

                  is_nil(System.find_executable("python3")) ->
                    "python3 not on PATH"

                  is_nil(System.find_executable("mdbook")) ->
                    "mdbook not on PATH"

                  true ->
                    false
                end)

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo, ownership_timeout: 3_600_000)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    original =
      for key <- [
            :ultracode_verifier_suites,
            :ultracode_worktree_root,
            :ultracode_ticket_dir,
            :ultracode_repos
          ],
          into: %{},
          do: {key, Application.get_env(:xaas, key)}

    base = mktmp("base")
    repo = Path.join(base, "aps")
    {_, 0} = System.cmd("git", ["clone", "-q", @source, repo], stderr_to_stdout: true)

    {_, 0} =
      System.cmd(
        "git",
        ["-C", repo, "fetch", "-q", @bundle, "aps-autonomic-3e46cf:refs/crown/bundle"],
        stderr_to_stdout: true
      )

    Application.put_env(:xaas, :ultracode_worktree_root, Path.join(base, "runs"))
    Application.put_env(:xaas, :ultracode_ticket_dir, Path.join(base, "tickets"))
    Application.put_env(:xaas, :ultracode_repos, %{"aps" => repo})
    Application.put_env(:xaas, :ultracode_verifier_suites, suites())

    on_exit(fn ->
      for {key, value} <- original do
        if is_nil(value),
          do: Application.delete_env(:xaas, key),
          else: Application.put_env(:xaas, key, value)
      end
    end)

    tests = %{
      "SJ-CROWN-A" =>
        {"tests/test_contract_standing.py", recorded(repo, "tests/test_contract_standing.py")},
      "SJ-CROWN-B" =>
        {"tests/test_contract_evidence_receipt.py",
         recorded(repo, "tests/test_contract_evidence_receipt.py")}
    }

    %{base: base, repo: repo, tests: tests}
  end

  test "receipts are the clock: observe -> admit -> execute -> seal -> reconcile -> unlock -> replay, plus a refused bad candidate",
       %{base: base, tests: tests} do
    work_dir = Path.join(base, "crown")

    assert {:ok, report} =
             SemanticCrown.run(
               ggen_igniter_dir: @ggen_dir,
               work_dir: work_dir,
               worker: scripted(tests),
               controls: %{transport: :local},
               max_attempts: 1
             )

    # standing and shape
    assert report["standing"] == "ALIVE"
    assert report["human_inputs"] == 0
    assert report["shacl"]["conforms"] == true

    # the dependent could only run after its dependency's receipt moved the graph
    assert [a, b] = report["cycles"]

    assert {a["identity"], a["status"], a["outcome"], a["fabric_verifier"]} ==
             {"SJ-CROWN-A", "done", "alive", "pass"}

    assert {b["identity"], b["status"], b["outcome"], b["fabric_verifier"]} ==
             {"SJ-CROWN-B", "done", "alive", "pass"}

    assert a["transition"]["status"] == "applied"
    assert a["transition"]["event"]["seq"] == 1
    assert b["transition"]["event"]["seq"] == 2

    b_descriptor =
      work_dir |> Path.join("SJ-CROWN-B-1-0/descriptor.json") |> File.read!() |> Jason.decode!()

    assert [%{"receipt_digest" => dep_digest, "required_standing" => "ALIVE"}] =
             b_descriptor["dependencies"]

    assert dep_digest == a["receipt_digest"]

    # final projected state, from receipts only
    assert report["final_standings"] == %{"SJ-CROWN-A" => "ALIVE", "SJ-CROWN-B" => "ALIVE"}
    assert report["final_eligible"] == []

    # replay from the ledger + work orders alone, in a fresh directory and OS process
    assert report["replay"]["equal"] == true
    assert report["replay"]["ledger_tail"] == report["ledger_tail"]

    # the sealed fabric facts behind each transition are independently in the database
    for cycle <- [a, b] do
      epoch = Ash.get!(Epoch, cycle["epoch_id"], action: :read_unscoped, authorize?: false)
      assert epoch.state == :completed
      assert epoch.leased_to =~ "crown-worker-"
    end

    # the falsifier: a claimed-ALIVE vacuous candidate is sealed build_broken, refused by the
    # reconciler, leaves the ledger empty and the work order on the frontier
    control = report["controls"]
    assert control["pass"] == true
    assert control["claimed"] == "alive"
    assert control["sealed_outcome"] == "build_broken"
    assert "CHI-ASSERT" in control["failed_gates"]
    assert control["mapped_exit"] == 0
    assert control["reconcile_exit"] == 1
    assert control["ledger_events"] == 0
    assert "SJ-CROWN-A" in control["still_eligible"]
  end

  # -- scripted protocol worker --------------------------------------------------------

  defp scripted(tests) do
    fn epoch, _ctx ->
      run = Ash.get!(Run, epoch.run_id, action: :read_unscoped, authorize?: false)
      identity = String.replace_prefix(run.work_order_iri, @prefix, "")
      {path, content} = Map.fetch!(tests, identity)

      {:ok, claimed, token, _run} =
        Lease.claim_next(@provider, "crown-worker-#{identity}", epoch_id: epoch.id)

      worktree = claimed.worktree
      file = Path.join(worktree, path)
      File.mkdir_p!(Path.dirname(file))
      File.write!(file, content)

      env = [
        {"GIT_AUTHOR_NAME", "scripted"},
        {"GIT_AUTHOR_EMAIL", "s@s"},
        {"GIT_COMMITTER_NAME", "scripted"},
        {"GIT_COMMITTER_EMAIL", "s@s"}
      ]

      {_, 0} = System.cmd("git", ["-C", worktree, "add", path], env: env)

      {_, 0} =
        System.cmd("git", ["-C", worktree, "commit", "-q", "-m", "test(contract): #{identity}"],
          env: env
        )

      head = git(worktree, ["rev-parse", "HEAD"])

      {:ok, _epoch, _receipt} =
        Lease.close(token, head, :alive, %{"note" => "scripted worker done"})

      :ok
    end
  end

  # The test a model worker committed in the recorded live run, read from the recorded bundle.
  defp recorded(repo, path), do: git(repo, ["show", "refs/crown/bundle:#{path}"])

  # -- suites (mirror config/dev.exs: aps-dod) --------------------------------------------

  defp suites do
    {userbase, 0} = System.cmd("python3", ["-m", "site", "--user-base"])

    env = %{
      "PATH" => "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
      "LANG" => "en_US.UTF-8",
      "PYTHONUSERBASE" => String.trim(userbase)
    }

    %{
      "aps-dod" => %{
        env: env,
        max_output_bytes: 65_536,
        steps: [
          %{
            id: "court",
            timeout_ms: 300_000,
            infra_exit_codes: [2],
            receipt: true,
            argv: [
              "python3",
              "priv:verifiers/aps_dod_court.py",
              "--worktree",
              "{worktree}",
              "--head",
              "{head}",
              "--ticket",
              "{ticket}",
              "--executor",
              "{executor}",
              "--verifier-identity",
              "{verifier_id}"
            ]
          }
        ]
      }
    }
  end

  defp mktmp(label) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "xaas-crown-test-#{label}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    {out, 0} = System.cmd("sh", ["-c", ~s(cd "$1" && pwd -P), "sh", dir])
    String.trim(out)
  end

  defp git(dir, args) do
    {out, 0} = System.cmd("git", ["-C", dir | args], stderr_to_stdout: true)
    String.trim(out)
  end
end
