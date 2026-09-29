defmodule Xaas.Ultracode.VerifierProbesTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Chicago-style qualification of the verifier's FALSIFIER PROBES: a DoD that
  cannot fail is VACUOUS and is refused with typed `vacuous_dod`.

  Everything is real: git repos and linked worktrees on disk, the real
  `Verifier.run/2` (containment root, `env -i`, process groups), real
  `/bin/sh` suites, real mutations applied to real scratch clones. The
  deliberately vacuous suite is `exit 0`. Assertions are on the returned
  result, on the real worktree's git state, and on leaked temp dirs.
  """

  alias Xaas.Test.DodFixture, as: Fx
  alias Xaas.Ultracode.Verifier

  @env %{"PATH" => "/usr/bin:/bin"}

  # DoD under test: a strong suite checks BOTH the answer and the feature file.
  @strong ~s|test "$(cat answer.txt)" = 42 && test -f feature.txt|

  setup do
    original = %{
      suites: Application.get_env(:xaas, :ultracode_verifier_suites),
      root: Application.get_env(:xaas, :ultracode_worktree_root),
      tickets: Application.get_env(:xaas, :ultracode_ticket_dir),
      targets: Application.get_env(:xaas, :ultracode_target_suites)
    }

    root = Fx.tmp("root")
    origin_parent = Fx.tmp("origin")
    Application.put_env(:xaas, :ultracode_worktree_root, root)
    Application.delete_env(:xaas, :ultracode_target_suites)

    on_exit(fn ->
      restore(:ultracode_verifier_suites, original.suites)
      restore(:ultracode_worktree_root, original.root)
      restore(:ultracode_ticket_dir, original.tickets)
      restore(:ultracode_target_suites, original.targets)
    end)

    {repo, _} = Fx.repo(origin_parent, %{"answer.txt" => "42\n", "notes.txt" => "notes\n"})
    head = Fx.commit(repo, %{"feature.txt" => "feature\n"}, "add feature")
    worktree = Fx.linked_worktree(repo, root, head)

    %{root: root, repo: repo, worktree: worktree, head: head, parent: origin_parent}
  end

  defp restore(key, nil), do: Application.delete_env(:xaas, key)
  defp restore(key, value), do: Application.put_env(:xaas, key, value)

  defp sh(script, extra \\ %{}),
    do: Map.merge(%{id: "dod", argv: ["/bin/sh", "-c", script], timeout_ms: 20_000}, extra)

  defp put_suite(name, script, extra \\ %{}) do
    suite = Map.merge(%{env: @env, steps: [sh(script)]}, extra)
    Application.put_env(:xaas, :ultracode_verifier_suites, %{name => suite})
    name
  end

  defp ctx(worktree, extra \\ %{}) do
    Map.merge(
      %{
        worktree: worktree,
        head: Fx.head(worktree),
        run_id: Ecto.UUID.generate(),
        epoch_id: Ecto.UUID.generate(),
        executor: "worker-probes"
      },
      extra
    )
  end

  defp answer_probe(id \\ "wrong-answer"),
    do: %{
      "id" => id,
      "kind" => "replace",
      "file" => "answer.txt",
      "pattern" => "42",
      "replacement" => "41"
    }

  defp assert_real_worktree_untouched(worktree, head) do
    assert Fx.head(worktree) == head
    assert Fx.status(worktree) == ""
    assert File.read!(Path.join(worktree, "answer.txt")) == "42\n"
  end

  test "a vacuous DoD (exit 0) is refused with typed vacuous_dod, never pass", %{
    worktree: wt,
    head: head
  } do
    put_suite("vacuous", "exit 0")
    ctx = ctx(wt, %{probes: [answer_probe()]})

    assert {:ok, result} = Verifier.run("vacuous", ctx)

    assert result["status"] == "error"
    assert result["refusal"] == "vacuous_dod"
    assert result["reason"] =~ "vacuous_dod"
    assert result["reason"] =~ "wrong-answer"

    assert [%{"id" => "wrong-answer", "verdict" => "survived", "kind" => "replace"}] =
             result["probes"]

    assert result["probe_summary"] == %{"declared" => 1, "killed" => 0, "survived" => 1}

    # the real worktree was never touched and nothing leaked
    assert_real_worktree_untouched(wt, head)
    assert Fx.leftover_tmp(ctx.epoch_id) == []
  end

  test "a strong DoD kills its probes and keeps its pass verdict", %{worktree: wt, head: head} do
    put_suite("strong", @strong)

    probes = [
      answer_probe(),
      %{
        "id" => "no-feature",
        "kind" => "delete_file",
        "file" => "feature.txt",
        "falsifier" => "feature missing accepted"
      }
    ]

    ctx = ctx(wt, %{probes: probes})
    assert {:ok, result} = Verifier.run("strong", ctx)

    assert result["status"] == "pass"
    refute Map.has_key?(result, "refusal")
    assert result["probe_summary"] == %{"declared" => 2, "killed" => 2, "survived" => 0}

    assert [
             %{"verdict" => "killed"},
             %{"verdict" => "killed", "falsifier" => "feature missing accepted"}
           ] =
             result["probes"]

    assert [%{"id" => "dod", "status" => "fail", "exit" => 1}] = hd(result["probes"])["steps"]
    assert_real_worktree_untouched(wt, head)
    assert Fx.leftover_tmp(ctx.epoch_id) == []
  end

  test "one surviving probe among killed ones makes the whole DoD vacuous and names it", %{
    worktree: wt
  } do
    put_suite("half", @strong)

    unrelated = %{
      "id" => "notes-changed",
      "kind" => "replace",
      "file" => "notes.txt",
      "pattern" => "notes",
      "replacement" => "changed"
    }

    assert {:ok, result} = Verifier.run("half", ctx(wt, %{probes: [answer_probe(), unrelated]}))

    assert result["status"] == "error"
    assert result["refusal"] == "vacuous_dod"
    assert result["reason"] =~ "notes-changed"
    refute result["reason"] =~ "wrong-answer"

    assert Enum.map(result["probes"], &{&1["id"], &1["verdict"]}) == [
             {"wrong-answer", "killed"},
             {"notes-changed", "survived"}
           ]
  end

  test "probes declared on the suite itself are enforced (atom-keyed config)", %{worktree: wt} do
    put_suite("declared", "exit 0", %{
      probes: [
        %{
          id: "wrong-answer",
          kind: "replace",
          file: "answer.txt",
          pattern: "42",
          replacement: "41"
        }
      ]
    })

    assert {:ok, %{"status" => "error", "refusal" => "vacuous_dod"}} =
             Verifier.run("declared", ctx(wt))
  end

  test "a revert_commit probe (data: the feature commit) is killed by a DoD that checks the feature",
       %{
         worktree: wt,
         head: head
       } do
    put_suite("strong", @strong)
    revert = %{"id" => "revert-feature", "kind" => "revert_commit", "commit" => head}

    assert {:ok, %{"status" => "pass", "probes" => [%{"verdict" => "killed"}]}} =
             Verifier.run("strong", ctx(wt, %{probes: [revert]}))

    put_suite("answer-only", ~s|test "$(cat answer.txt)" = 42|)

    assert {:ok, %{"status" => "error", "refusal" => "vacuous_dod"}} =
             Verifier.run("answer-only", ctx(wt, %{probes: [revert]}))
  end

  test "a probe that cannot be applied proves nothing: probes_refused, not vacuous and not pass",
       %{worktree: wt} do
    put_suite("strong", @strong)

    absent = %{
      "id" => "absent",
      "kind" => "replace",
      "file" => "answer.txt",
      "pattern" => "NOT-THERE",
      "replacement" => "x"
    }

    assert {:ok, result} = Verifier.run("strong", ctx(wt, %{probes: [absent]}))
    assert result["status"] == "error"
    assert result["refusal"] == "probes_refused"
    assert [%{"verdict" => "unapplicable", "reason" => reason}] = result["probes"]
    assert reason =~ "pattern_not_found"
  end

  test "a malformed probe declaration refuses the run BEFORE any step executes", %{
    worktree: wt,
    root: root
  } do
    marker = Path.join(root, "ran-marker")
    put_suite("marker", "touch #{marker}")

    assert {:ok, result} =
             Verifier.run(
               "marker",
               ctx(wt, %{probes: [%{"id" => "x", "kind" => "rm_rf", "file" => "/"}]})
             )

    assert result["status"] == "error"
    assert result["refusal"] == "probes_refused"
    assert result["reason"] =~ "unknown_kind"
    refute File.exists?(marker)
  end

  test "a probe whose rerun times out is inconclusive: probes_refused, never a kill", %{
    worktree: wt
  } do
    put_suite("hangs-when-broken", ~s|test "$(cat answer.txt)" = 42 \|\| sleep 30|, %{
      steps: [sh(~s|test "$(cat answer.txt)" = 42 \|\| sleep 30|, %{timeout_ms: 800})]
    })

    assert {:ok, result} = Verifier.run("hangs-when-broken", ctx(wt, %{probes: [answer_probe()]}))
    assert result["status"] == "error"
    assert result["refusal"] == "probes_refused"
    assert [%{"verdict" => "inconclusive", "reason" => "rerun_timeout"}] = result["probes"]
  end

  test "a suite that already fails on the real head is fail and runs no probes", %{worktree: wt} do
    put_suite("red", "exit 1")

    assert {:ok, result} = Verifier.run("red", ctx(wt, %{probes: [answer_probe()]}))
    assert result["status"] == "fail"
    refute Map.has_key?(result, "probes")
    refute Map.has_key?(result, "refusal")
  end

  test "require_probes refuses a suite that declares none", %{worktree: wt} do
    put_suite("needs-probes", @strong, %{require_probes: true})

    assert {:ok, result} = Verifier.run("needs-probes", ctx(wt))
    assert result["status"] == "error"
    assert result["refusal"] == "probes_refused"
    assert result["reason"] =~ "probes_required"

    # ... and is satisfied by any probe source
    assert {:ok, %{"status" => "pass"}} =
             Verifier.run("needs-probes", ctx(wt, %{probes: [answer_probe()]}))
  end

  test "a suite without probes behaves exactly as before (no probe keys)", %{worktree: wt} do
    put_suite("plain", @strong)
    assert {:ok, result} = Verifier.run("plain", ctx(wt))
    assert result["status"] == "pass"
    refute Map.has_key?(result, "probes")
    refute Map.has_key?(result, "probe_summary")
    refute Map.has_key?(result, "refusal")
  end

  describe "order probes carried in the controller-written {ticket} file" do
    setup %{root: root} do
      dir = Path.join(root, "tickets")
      File.mkdir_p!(dir)
      Application.put_env(:xaas, :ultracode_ticket_dir, dir)
      %{ticket_dir: dir}
    end

    test "ticket probes are enforced: a vacuous DoD is refused", %{worktree: wt, ticket_dir: dir} do
      put_suite("vacuous", "exit 0")
      ctx = ctx(wt)

      File.write!(
        Path.join(dir, "#{ctx.run_id}.json"),
        Jason.encode!(%{"item" => "x", "probes" => [answer_probe("from-order")]})
      )

      assert {:ok, %{"status" => "error", "refusal" => "vacuous_dod", "reason" => reason}} =
               Verifier.run("vacuous", ctx)

      assert reason =~ "from-order"
    end

    test "an order whose probes were invalid (probes_error) is refused, not ignored", %{
      worktree: wt,
      ticket_dir: dir
    } do
      put_suite("strong", @strong)
      ctx = ctx(wt)

      File.write!(
        Path.join(dir, "#{ctx.run_id}.json"),
        Jason.encode!(%{"probes_error" => "unanchored"})
      )

      assert {:ok, %{"status" => "error", "refusal" => "probes_refused", "reason" => reason}} =
               Verifier.run("strong", ctx)

      assert reason =~ "order_probes_invalid"
    end

    test "a legacy ticket with no probes key (APS shape) leaves the verdict untouched", %{
      worktree: wt,
      ticket_dir: dir
    } do
      put_suite("strong", @strong)
      ctx = ctx(wt)

      File.write!(
        Path.join(dir, "#{ctx.run_id}.json"),
        Jason.encode!(%{"item" => "x", "mutants" => []})
      )

      assert {:ok, %{"status" => "pass"} = result} = Verifier.run("strong", ctx)
      refute Map.has_key?(result, "probes")
    end
  end
end
