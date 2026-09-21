defmodule Xaas.Ultracode.LeaseVerifierTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Chicago-style qualification of `Lease.close/4` with a fabric verifier suite:
  real Run/Epoch/Receipt rows (sandboxed Postgres), real git worktrees under a
  real containment root, real suite subprocesses. Each assertion is on the
  SEALED receipt the database actually holds, never on a call log.

  The property under test: the fabric, not the worker, decides done. A pass
  never upgrades a claim, a failing suite is falsified evidence, an
  unverifiable suite is partial, and a worker cannot spoof the fabric's
  evidence key.
  """

  alias Xaas.Ultracode.{Epoch, Lease, Receipt, Run}

  @provider "zcode-verifier-test"
  @env %{"PATH" => "/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin"}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    original = %{
      suites: Application.get_env(:xaas, :ultracode_verifier_suites),
      root: Application.get_env(:xaas, :ultracode_worktree_root)
    }

    root = canonical(mktmp("root"))
    Application.put_env(:xaas, :ultracode_worktree_root, root)

    on_exit(fn ->
      Application.put_env(:xaas, :ultracode_verifier_suites, original.suites)
      Application.put_env(:xaas, :ultracode_worktree_root, original.root)
    end)

    %{root: root}
  end

  defp sh(id, script, extra \\ %{}),
    do: Map.merge(%{id: id, argv: ["/bin/sh", "-c", script], timeout_ms: 10_000}, extra)

  defp register(name, steps),
    do:
      Application.put_env(:xaas, :ultracode_verifier_suites, %{name => %{env: @env, steps: steps}})

  # A leased epoch on a real worktree; returns {token, head, worktree}.
  defp leased(root, suite, worktree \\ nil) do
    worktree = worktree || git_worktree(root)

    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "Verifier qualification.", provider: @provider, verifier_suite: suite},
        authorize?: false
      )
      |> Ash.create()

    {:ok, _epoch} =
      Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{
          run_id: run.id,
          cycle: 0,
          exact_subject: "verifier qualification",
          state: :running,
          worktree: worktree
        },
        authorize?: false
      )
      |> Ash.create()

    {:ok, _epoch, token, _run} = Lease.claim_next(@provider, "worker-vt")
    {token, git_head(worktree), worktree}
  end

  defp sealed(epoch),
    do: Ash.read!(Receipt, authorize?: false) |> Enum.find(&(&1.epoch_id == epoch.id))

  test "a passing suite keeps the claimed outcome and records the fabric verdict", %{root: root} do
    register("t-pass", [sh("ok", ~s(echo "shell var: ${HOME:-none}"; true))])
    {token, head, _wt} = leased(root, "t-pass")

    assert {:ok, epoch, receipt} =
             Lease.close(token, head, :alive, %{"note" => "worker says done"})

    assert epoch.state == :completed
    assert receipt.outcome == :alive
    assert receipt.evidence["head_verified"] == true
    assert receipt.evidence["note"] == "worker says done"

    assert %{"status" => "pass", "suite" => "t-pass", "head" => ^head} =
             receipt.evidence["fabric_verifier"]

    assert [%{"id" => "ok", "exit" => 0}] = receipt.evidence["fabric_verifier"]["steps"]
    assert sealed(epoch).id == receipt.id
  end

  test "a failing suite is falsified evidence: :build_broken, not the worker's :alive", %{
    root: root
  } do
    register("t-fail", [sh("red", "echo 'FAILED (failures=2)'; exit 1")])
    {token, head, _wt} = leased(root, "t-fail")

    assert {:ok, _epoch, receipt} = Lease.close(token, head, :alive)

    assert receipt.outcome == :build_broken
    assert receipt.evidence["head_verified"] == true

    assert %{"status" => "fail", "steps" => [%{"exit" => 1, "output_tail" => tail}]} =
             receipt.evidence["fabric_verifier"]

    assert tail =~ "FAILED (failures=2)"
  end

  test "an unverifiable suite (timeout) is :partial_alive, never :alive", %{root: root} do
    register("t-slow", [sh("hang", "sleep 30", %{timeout_ms: 300})])
    {token, head, _wt} = leased(root, "t-slow")

    assert {:ok, _epoch, receipt} = Lease.close(token, head, :alive)

    assert receipt.outcome == :partial_alive
    assert %{"status" => "timeout"} = receipt.evidence["fabric_verifier"]
  end

  test "a pass never upgrades: a claimed :partial_alive stays :partial_alive", %{root: root} do
    register("t-pass", [sh("ok", "true")])
    {token, head, _wt} = leased(root, "t-pass")

    assert {:ok, _epoch, receipt} = Lease.close(token, head, :partial_alive)
    assert receipt.outcome == :partial_alive
    assert receipt.evidence["fabric_verifier"]["status"] == "pass"
  end

  test "a worker cannot spoof the fabric's evidence key", %{root: root} do
    register("t-fail", [sh("red", "exit 1")])
    {token, head, _wt} = leased(root, "t-fail")

    spoof = %{
      "fabric_verifier" => %{"status" => "pass", "suite" => "t-fail"},
      "head_verified" => true
    }

    assert {:ok, _epoch, receipt} = Lease.close(token, head, :alive, spoof)

    assert receipt.outcome == :build_broken
    assert receipt.evidence["fabric_verifier"]["status"] == "fail"
  end

  test "a worker-supplied fabric_verifier key is dropped when the run names no suite", %{
    root: root
  } do
    {token, head, _wt} = leased(root, nil)

    spoof = %{"fabric_verifier" => %{"status" => "pass"}}
    assert {:ok, _epoch, receipt} = Lease.close(token, head, :alive, spoof)

    # The spoofed court key is dropped (never merged), and with no suite
    # there is no qualifying court -- the receipt law downgrades the :alive
    # claim to the honest :partial_alive instead of sealing it.
    assert receipt.outcome == :partial_alive
    assert receipt.evidence["verifier_suite_absent"] == true
    refute Map.has_key?(receipt.evidence, "fabric_verifier")
  end

  test "claims that are not alive-family are not verified (nothing to judge)", %{root: root} do
    marker = Path.join(mktmp("marker"), "ran")

    Application.put_env(:xaas, :ultracode_verifier_suites, %{
      "t-marker" => %{
        env: Map.put(@env, "MARKER", marker),
        steps: [sh("touch", ~s(touch "$MARKER"))]
      }
    })

    {token, head, _wt} = leased(root, "t-marker")

    assert {:ok, _epoch, receipt} = Lease.close(token, head, :blocked)

    assert receipt.outcome == :blocked
    refute Map.has_key?(receipt.evidence, "fabric_verifier")
    refute File.exists?(marker)
  end

  test "the leased worker id reaches the suite as {executor}", %{root: root} do
    register("t-exec", [
      %{
        id: "who",
        timeout_ms: 5000,
        argv: ["/bin/sh", "-c", ~S(echo "executor=$0"), "{executor}"]
      }
    ])

    {token, head, _wt} = leased(root, "t-exec")

    assert {:ok, _epoch, receipt} = Lease.close(token, head, :alive)
    assert [%{"output_tail" => tail}] = receipt.evidence["fabric_verifier"]["steps"]
    assert String.trim(tail) == "executor=worker-vt"
  end

  test "a worktree outside the containment root is unverifiable, so :partial_alive", %{root: root} do
    marker = Path.join(mktmp("marker"), "ran")

    Application.put_env(:xaas, :ultracode_verifier_suites, %{
      "t-marker" => %{
        env: Map.put(@env, "MARKER", marker),
        steps: [sh("touch", ~s(touch "$MARKER"))]
      }
    })

    outside = git_worktree(canonical(mktmp("elsewhere")))
    {token, head, _wt} = leased(root, "t-marker", outside)

    assert {:ok, _epoch, receipt} = Lease.close(token, head, :alive)

    assert receipt.outcome == :partial_alive

    assert %{"status" => "error", "reason" => "worktree_outside_root"} =
             receipt.evidence["fabric_verifier"]

    refute File.exists?(marker)
  end

  test "a head mismatch is still :build_broken and the suite is never run", %{root: root} do
    marker = Path.join(mktmp("marker"), "ran")

    Application.put_env(:xaas, :ultracode_verifier_suites, %{
      "t-marker" => %{
        env: Map.put(@env, "MARKER", marker),
        steps: [sh("touch", ~s(touch "$MARKER"))]
      }
    })

    {token, _head, _wt} = leased(root, "t-marker")

    assert {:ok, _epoch, receipt} = Lease.close(token, String.duplicate("b", 40), :alive)

    assert receipt.outcome == :build_broken
    assert receipt.evidence["head_verified"] == false
    refute Map.has_key?(receipt.evidence, "fabric_verifier")
    refute File.exists?(marker)
  end

  test "a Run can only name a suite the operator registered" do
    register("known", [sh("ok", "true")])

    assert {:error, error} =
             Run
             |> Ash.Changeset.for_create(
               :create,
               %{goal: "g", provider: @provider, verifier_suite: "not-registered"},
               authorize?: false
             )
             |> Ash.create()

    assert Exception.message(error) =~ "unknown_verifier_suite"

    assert {:error, error} =
             Run
             |> Ash.Changeset.for_create(
               :submit,
               %{goal: "g", provider: @provider, verifier_suite: "Bad Name; rm -rf /"},
               authorize?: false
             )
             |> Ash.create()

    assert Exception.message(error) =~ "verifier_suite"
  end

  # ------------------------------------------------------------------

  defp mktmp(label) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "xaas-lease-verifier-#{label}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end

  defp canonical(path) do
    {out, 0} = System.cmd("sh", ["-c", ~s(cd "$1" && pwd -P), "sh", path])
    String.trim(out)
  end

  defp git_worktree(parent) do
    dir = Path.join(parent, "wt-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    {_, 0} = System.cmd("git", ["-C", dir, "init", "--quiet"], stderr_to_stdout: true)

    {_, 0} =
      System.cmd("git", ["-C", dir, "commit", "--allow-empty", "-m", "init", "--quiet"],
        stderr_to_stdout: true,
        env: [
          {"GIT_AUTHOR_NAME", "t"},
          {"GIT_AUTHOR_EMAIL", "t@t"},
          {"GIT_COMMITTER_NAME", "t"},
          {"GIT_COMMITTER_EMAIL", "t@t"}
        ]
      )

    canonical(dir)
  end

  defp git_head(worktree) do
    {out, 0} = System.cmd("git", ["-C", worktree, "rev-parse", "HEAD"])
    String.trim(out)
  end
end
