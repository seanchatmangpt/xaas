defmodule Xaas.Ultracode.SemanticReceiptTest do
  @moduledoc """
  Chicago-style: real Postgres sandbox, real git worktrees, real leases, the
  real `Lease.close/4` fabric verifier running a real shell suite. The worker
  is a scripted protocol client (it claims, edits, commits and closes through
  `Xaas.Ultracode.Lease`); it stands in only for the model's judgment.
  """

  use ExUnit.Case, async: false

  alias Xaas.Ultracode.{Lease, SemanticReceipt, SemanticWork}
  alias Xaas.Ultracode.SemanticReceipt.ApsDod

  @provider "zcode-semantic-receipt"

  @bridge %{
    "identity" => "SJ-T-1",
    "definition_digest" => "sha256:" <> String.duplicate("d", 64),
    "source_snapshot_digest" => "sha256:" <> String.duplicate("e", 64),
    "ledger_tail" => "sha256:" <> String.duplicate("0", 64),
    "repository" => "seanchatmangpt/demo",
    "subject" => "semantic-jira:test:1",
    "requires" => %{
      "courts" => ["court"],
      "acceptance" => ["CHI-ASSERT", "obs-acceptance-delta", "unmapped-criterion"],
      "falsifiers" => ["obs-falsifier-delta"]
    }
  }

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    original = %{
      repos: Application.get_env(:xaas, :ultracode_repos),
      root: Application.get_env(:xaas, :ultracode_worktree_root),
      suites: Application.get_env(:xaas, :ultracode_verifier_suites),
      tickets: Application.get_env(:xaas, :ultracode_ticket_dir)
    }

    base = mktmp("receipt")
    repo = Path.join(base, "repo")
    File.mkdir_p!(repo)
    sha = init_repo(repo)

    Application.put_env(:xaas, :ultracode_repos, %{"demo" => repo})
    Application.put_env(:xaas, :ultracode_worktree_root, Path.join(base, "runs"))
    Application.put_env(:xaas, :ultracode_ticket_dir, Path.join(base, "tickets"))

    Application.put_env(:xaas, :ultracode_verifier_suites, %{
      "sem-pass" => suite("test -f hello.txt"),
      "sem-fail" => suite("test -f no-such-file.txt")
    })

    on_exit(fn ->
      restore_env(:ultracode_repos, original.repos)
      restore_env(:ultracode_worktree_root, original.root)
      restore_env(:ultracode_verifier_suites, original.suites)
      restore_env(:ultracode_ticket_dir, original.tickets)
    end)

    %{sha: sha, base: base}
  end

  describe "bridge persistence" do
    test "the descriptor bridge is stored on the Run verbatim and never interpreted", %{sha: sha} do
      assert {:ok, %{run: run}} = SemanticWork.materialize(descriptor(sha, "sem-pass"))
      assert run.semantic_bridge == @bridge

      reread =
        Ash.get!(Xaas.Ultracode.Run, run.id, action: :read_unscoped, authorize?: false)

      assert reread.semantic_bridge == @bridge
    end

    test "a descriptor without a bridge still materializes; a non-object bridge is refused",
         %{sha: sha} do
      no_bridge = Map.delete(descriptor(sha, "sem-pass"), "bridge")
      assert {:ok, %{run: run}} = SemanticWork.materialize(no_bridge)
      assert run.semantic_bridge == nil

      assert {:error, {:refused_semantic_work, {:invalid, :bridge}}} =
               SemanticWork.admit(Map.put(descriptor(sha, "sem-pass"), "bridge", "not-an-object"))
    end
  end

  describe "export" do
    test "a verified ALIVE close exports the sealed facts, the bridge and a recomputable digest",
         %{sha: sha} do
      {epoch, head} = run_worker(sha, "sem-pass")

      assert {:ok, export} = SemanticReceipt.export(epoch.id)
      assert export["outcome"] == "alive"
      assert export["final_head"] == head
      assert export["head_verified"] == true
      assert export["bridge"] == @bridge
      assert export["epoch_id"] == epoch.id

      assert export["fabric_verifier"] == %{
               "status" => "pass",
               "steps" => [%{"id" => "court", "status" => "pass"}]
             }

      assert export["receipt_digest"] == SemanticReceipt.receipt_digest(export)
      assert "sha256:" <> hex = export["receipt_digest"]
      assert hex =~ ~r/\A[0-9a-f]{64}\z/
      assert export == export |> Jason.encode!() |> Jason.decode!()
    end

    test "the digest binds every field: changing one changes it", %{sha: sha} do
      {epoch, _head} = run_worker(sha, "sem-pass")
      {:ok, export} = SemanticReceipt.export(epoch.id)

      tampered = put_in(export, ["fabric_verifier", "status"], "fail")
      refute SemanticReceipt.receipt_digest(tampered) == export["receipt_digest"]

      moved = Map.put(export, "final_head", String.duplicate("f", 40))
      refute SemanticReceipt.receipt_digest(moved) == export["receipt_digest"]
    end

    test "a claimed ALIVE that fails the suite exports build_broken, never alive", %{sha: sha} do
      {epoch, _head} = run_worker(sha, "sem-fail")

      assert {:ok, export} = SemanticReceipt.export(epoch.id)
      assert export["outcome"] == "build_broken"
      assert export["fabric_verifier"]["status"] == "fail"
      assert export["fabric_verifier"]["steps"] == [%{"id" => "court", "status" => "fail"}]
      refute Map.has_key?(export["fabric_verifier"], "court_receipt")
    end

    test "typed refusals: unknown epoch, no bridge, not completed", %{sha: sha} do
      assert {:error, :epoch_not_found} = SemanticReceipt.export(Ecto.UUID.generate())

      assert {:ok, %{epoch: open}} = SemanticWork.materialize(descriptor(sha, "sem-pass"))
      assert {:error, {:epoch_not_completed, :running}} = SemanticReceipt.export(open.id)

      no_bridge = Map.delete(descriptor(sha, "sem-pass", "urn:t:no-bridge"), "bridge")
      assert {:ok, %{epoch: bare}} = SemanticWork.materialize(no_bridge)
      assert {:error, :no_semantic_bridge} = SemanticReceipt.export(bare.id)
    end

    test "canonical form is key-sorted [key, value] pairs, compact JSON, sha256-prefixed" do
      value = %{"b" => 1, "a" => [true, nil, "x"], :c => :atom}
      expected = ~s([["a",[true,null,"x"]],["b",1],["c","atom"]])

      assert SemanticReceipt.digest(value) ==
               "sha256:" <> (:crypto.hash(:sha256, expected) |> Base.encode16(case: :lower))
    end
  end

  describe "aps-dod court adapter" do
    @passing for id <-
                   ~w(CHI-EXACT-HEAD CHI-INDEPENDENT CHI-SCOPE CHI-MOCK CHI-ASSERT CHI-CANONICAL CHI-MUTATION),
                 do: %{"id" => id, "pass" => true, "kind" => "gate", "ms" => 1}

    defp court(gates) do
      %{
        "receiptId" => "r-1",
        "resultDigest" => "d",
        "standing" => "ALIVE",
        "observation" => %{"gates" => gates}
      }
    end

    defp requires(acceptance, falsifiers),
      do: %{"acceptance" => acceptance, "falsifiers" => falsifiers}

    test "observed passing gates map onto gate ids and observation-edge criteria" do
      result =
        ApsDod.observe(
          court(@passing),
          requires(
            ["CHI-ASSERT", "obs-acceptance-delta", "obs-acceptance-guard"],
            ["CHI-MUTATION", "obs-falsifier-delta"]
          )
        )

      assert result["acceptance_results"] == %{
               "CHI-ASSERT" => true,
               "obs-acceptance-delta" => true,
               "obs-acceptance-guard" => true
             }

      assert result["falsifier_results"] == %{
               "CHI-MUTATION" => "survived",
               "obs-falsifier-delta" => "survived"
             }

      assert result["source"] == %{
               "receiptId" => "r-1",
               "resultDigest" => "d",
               "standing" => "ALIVE"
             }
    end

    test "a failed gate makes exactly the criteria that depend on it false / killed" do
      gates =
        Enum.map(@passing, &if(&1["id"] == "CHI-ASSERT", do: %{&1 | "pass" => false}, else: &1))

      result =
        ApsDod.observe(
          court(gates),
          requires(["CHI-ASSERT", "CHI-SCOPE", "obs-acceptance-delta"], ["obs-falsifier-delta"])
        )

      assert result["acceptance_results"] == %{
               "CHI-ASSERT" => false,
               "CHI-SCOPE" => true,
               "obs-acceptance-delta" => false
             }

      assert result["falsifier_results"] == %{"obs-falsifier-delta" => "killed"}
    end

    test "strings the court cannot speak to, and gates it did not report, are left out" do
      gates = Enum.reject(@passing, &(&1["id"] == "CHI-MUTATION"))

      result =
        ApsDod.observe(
          court(gates),
          requires(["unmapped-criterion", "obs-acceptance-guard"], [
            "CHI-MUTATION",
            "obs-falsifier-delta"
          ])
        )

      assert result["acceptance_results"] == %{"obs-acceptance-guard" => false}
      assert result["falsifier_results"] == %{}
    end

    test "the suite's real court step stands for exactly the court nodes bound to it" do
      iri = "https://ggen-igniter.dev/ontology/semantic-jira#court-aps-dod"
      other = "https://ggen-igniter.dev/ontology/semantic-jira#court-gall-001"

      assert ApsDod.court_steps(
               [%{"id" => "court", "status" => "pass"}],
               [iri, other, :not_a_binary]
             ) == [%{"id" => iri, "status" => "pass"}]

      assert ApsDod.court_steps(
               [%{"id" => "court", "status" => "fail"}],
               [iri]
             ) == [%{"id" => iri, "status" => "fail"}]

      assert ApsDod.court_steps([%{"id" => "other", "status" => "pass"}], [iri]) == []
    end

    test "only an ALIVE court receipt yields the court-receipt evidence requirement" do
      alive = ApsDod.observe(court(@passing), requires([], []))
      assert alive["evidence_types"] == [ApsDod.evidence_iri()]

      broken = ApsDod.observe(%{court(@passing) | "standing" => "BUILD_BROKEN"}, requires([], []))
      assert broken["evidence_types"] == []
    end

    test "no gates in the court receipt means no observations at all" do
      assert ApsDod.observe(%{"standing" => "ALIVE"}, requires(["CHI-ASSERT"], [])) == nil
    end
  end

  describe "mix xaas.semantic.materialize" do
    test "materializes a descriptor file, prints ids and files the ticket", %{
      sha: sha,
      base: base
    } do
      path = Path.join(base, "descriptor.json")
      ticket = Path.join(base, "ticket-in.json")
      File.write!(path, Jason.encode!(descriptor(sha, "sem-pass", "urn:t:mix-task")))
      File.write!(ticket, ~s({"schemaVersion":"aps-ticket/1"}))

      Mix.shell(Mix.Shell.Process)
      on_exit(fn -> Mix.shell(Mix.Shell.IO) end)

      Mix.Tasks.Xaas.Semantic.Materialize.run(["--descriptor", path, "--ticket-file", ticket])

      assert_received {:mix_shell, :info, [json]}
      printed = Jason.decode!(json)
      assert %{"run_id" => run_id, "epoch_id" => epoch_id, "worktree" => worktree} = printed
      assert File.dir?(worktree)

      assert Ash.get!(Xaas.Ultracode.Epoch, epoch_id, action: :read_unscoped, authorize?: false).state ==
               :running

      ticket_dir = Application.fetch_env!(:xaas, :ultracode_ticket_dir)

      assert File.read!(Path.join(ticket_dir, "#{run_id}.json")) ==
               ~s({"schemaVersion":"aps-ticket/1"})
    end
  end

  # -- fixtures -------------------------------------------------------------------

  defp run_worker(sha, suite) do
    {:ok, %{epoch: epoch, worktree: worktree}} =
      SemanticWork.materialize(
        descriptor(sha, suite, "urn:t:#{suite}:#{System.unique_integer([:positive])}")
      )

    {:ok, _claimed, token, _run} =
      Lease.claim_next(@provider, "worker-#{suite}", epoch_id: epoch.id)

    File.write!(Path.join(worktree, "worker-note.txt"), "done\n")
    git!(worktree, ["add", "worker-note.txt"])
    git!(worktree, ["commit", "-q", "-m", "worker"], commit_env())
    head = git!(worktree, ["rev-parse", "HEAD"])
    {:ok, _epoch, _receipt} = Lease.close(token, head, :alive, %{"note" => "worker done"})
    {Ash.get!(Xaas.Ultracode.Epoch, epoch.id, action: :read_unscoped, authorize?: false), head}
  end

  defp descriptor(sha, suite, iri \\ "urn:t:work-order:1") do
    %{
      "work_order_iri" => iri,
      "checkpoint_iri" => "urn:t:checkpoint:1",
      "graph_digest" => "sha256:" <> String.duplicate("a", 64),
      "repository_identity" => "seanchatmangpt/demo",
      "execution_repo_alias" => "demo",
      "base_sha" => sha,
      "goal" => "Add a file.",
      "provider" => @provider,
      "verifier_suite" => suite,
      "execution_policy" => "autonomic_wave_attempt",
      "dependencies" => [],
      "bridge" => @bridge
    }
  end

  defp suite(script) do
    %{
      env: %{"PATH" => "/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin"},
      max_output_bytes: 4096,
      steps: [%{id: "court", argv: ["/bin/sh", "-c", script], timeout_ms: 20_000}]
    }
  end

  defp mktmp(label) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "xaas-sem-receipt-#{label}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    {out, 0} = System.cmd("sh", ["-c", ~s(cd "$1" && pwd -P), "sh", dir])
    String.trim(out)
  end

  defp commit_env do
    [
      {"GIT_AUTHOR_NAME", "t"},
      {"GIT_AUTHOR_EMAIL", "t@t"},
      {"GIT_COMMITTER_NAME", "t"},
      {"GIT_COMMITTER_EMAIL", "t@t"}
    ]
  end

  defp init_repo(repo) do
    {_, 0} =
      System.cmd("git", ["-C", repo, "init", "--quiet", "-b", "main"], stderr_to_stdout: true)

    File.write!(Path.join(repo, "hello.txt"), "hello\n")
    git!(repo, ["add", "hello.txt"])
    git!(repo, ["commit", "-m", "init", "--quiet"], commit_env())
    git!(repo, ["rev-parse", "HEAD"])
  end

  defp git!(dir, args, env \\ []) do
    {out, 0} = System.cmd("git", ["-C", dir | args], stderr_to_stdout: true, env: env)
    String.trim(out)
  end

  defp restore_env(key, nil), do: Application.delete_env(:xaas, key)
  defp restore_env(key, value), do: Application.put_env(:xaas, key, value)
end
