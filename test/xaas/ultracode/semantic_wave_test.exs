defmodule Xaas.Ultracode.SemanticWaveTest do
  use Xaas.DataCase, async: false

  alias Xaas.Ultracode.{SemanticWave, SemanticWork}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    original = %{
      repos: Application.get_env(:xaas, :ultracode_repos),
      root: Application.get_env(:xaas, :ultracode_worktree_root),
      suites: Application.get_env(:xaas, :ultracode_verifier_suites),
      runner: Application.get_env(:xaas, :ultracode_semantic_wave_runner),
      state_dir: Application.get_env(:xaas, :ultracode_semantic_wave_state_dir)
    }

    base = mktmp("semantic-wave")
    repo = Path.join(base, "repo")
    root = Path.join(base, "runs")
    state = Path.join(base, "state")
    File.mkdir_p!(repo)
    sha = init_repo(repo)

    Application.put_env(:xaas, :ultracode_repos, %{"demo" => repo})
    Application.put_env(:xaas, :ultracode_worktree_root, root)
    Application.put_env(:xaas, :ultracode_verifier_suites, %{"semantic-test" => %{}})

    on_exit(fn ->
      restore_env(:ultracode_repos, original.repos)
      restore_env(:ultracode_worktree_root, original.root)
      restore_env(:ultracode_verifier_suites, original.suites)
      restore_env(:ultracode_semantic_wave_runner, original.runner)
      restore_env(:ultracode_semantic_wave_state_dir, original.state_dir)
    end)

    %{repo: repo, root: root, state: state, sha: sha}
  end

  test "dispatches only already-materialized autonomic-wave policy epochs", %{
    sha: sha,
    state: state
  } do
    assert {:ok, %{epoch: wave_a}} =
             SemanticWork.materialize(descriptor(sha, "a", "autonomic_wave_attempt"))

    assert {:ok, %{epoch: wave_b}} =
             SemanticWork.materialize(descriptor(sha, "b", "autonomic_wave_attempt"))

    assert {:ok, %{epoch: continuous}} =
             SemanticWork.materialize(descriptor(sha, "continuous", "continuous_epoch_run"))

    parent = self()

    worker = fn epoch, _ctx ->
      send(parent, {:semantic_wave_dispatched, epoch.id})
      :ok
    end

    assert {:ok, report} =
             SemanticWave.run(capacity: 2, worker: worker, state_dir: state, max_items: 10)

    assert report["status"] == "DISPATCHED"
    assert report["sensed"] == 2
    assert report["dispatched"] == 2
    assert File.exists?(report["receipt_path"])

    dispatched =
      for _ <- 1..2 do
        assert_receive {:semantic_wave_dispatched, epoch_id}
        epoch_id
      end

    assert MapSet.new(dispatched) == MapSet.new([wave_a.id, wave_b.id])
    refute continuous.id in dispatched
  end

  test "an already-leased semantic Epoch is not redispatched", %{sha: sha, state: state} do
    assert {:ok, %{epoch: wave}} =
             SemanticWork.materialize(descriptor(sha, "leased", "autonomic_wave_attempt"))

    assert {:ok, _epoch, _token, _run} =
             Xaas.Ultracode.Lease.claim_next("zcode", "existing-worker", epoch_id: wave.id)

    parent = self()

    assert {:ok, report} =
             SemanticWave.run(
               worker: fn epoch, _ctx ->
                 send(parent, {:unexpected_dispatch, epoch.id})
                 :ok
               end,
               state_dir: state
             )

    assert report["status"] == "IDLE"
    assert report["sensed"] == 0
    refute_receive {:unexpected_dispatch, _}
  end

  test "AshOban registers semantic and legacy waves on the same serialized queue" do
    built =
      AshOban.config(
        Application.fetch_env!(:xaas, :ash_domains),
        Application.fetch_env!(:xaas, Oban)
      )

    {Oban.Plugins.Cron, opts} =
      Enum.find(built[:plugins], fn
        {Oban.Plugins.Cron, _opts} -> true
        _ -> false
      end)

    semantic_entry =
      Enum.find(opts[:crontab], fn
        {_cron, Xaas.Ultracode.Run.Workers.SemanticWave, _opts} -> true
        _ -> false
      end)

    legacy_entry =
      Enum.find(opts[:crontab], fn
        {_cron, Xaas.Ultracode.Run.Workers.AutonomicWave, _opts} -> true
        _ -> false
      end)

    assert {semantic_cron, _, _} = semantic_entry
    assert {legacy_cron, _, _} = legacy_entry
    assert to_string(semantic_cron) == "*/30 * * * *"
    assert to_string(legacy_cron) == "*/30 * * * *"
    assert Application.fetch_env!(:xaas, Oban)[:queues][:ultracode_wave] == 1
  end

  test "scheduled semantic action invokes capacity five without promoting standing", %{
    state: state
  } do
    {:ok, _pid} = Agent.start_link(fn -> nil end, name: __MODULE__.RunnerProbe)
    Application.put_env(:xaas, :ultracode_semantic_wave_runner, {__MODULE__, :capture_runner})
    Application.put_env(:xaas, :ultracode_semantic_wave_state_dir, state)

    assert {:ok, result} =
             Xaas.Ultracode.Run
             |> Ash.ActionInput.for_action(:semantic_wave, %{}, authorize?: false)
             |> Ash.run_action()

    assert Agent.get(__MODULE__.RunnerProbe, & &1) == [capacity: 5]
    assert result == %{status: "IDLE", receipt: "/tmp/semantic-wave.json"}
    refute Map.has_key?(result, :standing)
  end

  def capture_runner(opts) do
    Agent.update(__MODULE__.RunnerProbe, fn _ -> opts end)
    {:ok, %{"status" => "IDLE", "receipt_path" => "/tmp/semantic-wave.json"}}
  end

  defp descriptor(sha, suffix, policy) do
    %{
      work_order_iri: "urn:gall:work-order:xaas:#{suffix}",
      checkpoint_iri: "urn:gall:checkpoint:xaas:#{suffix}",
      graph_digest: "sha256:" <> String.duplicate("a", 64),
      repository_identity: "seanchatmangpt/xaas",
      execution_repo_alias: "demo",
      base_sha: sha,
      goal: "Dispatch the admitted semantic work.",
      provider: "zcode",
      verifier_suite: "semantic-test",
      execution_policy: policy,
      dependencies: []
    }
  end

  defp mktmp(label) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "xaas-#{label}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end

  defp init_repo(repo) do
    env = [
      {"GIT_AUTHOR_NAME", "t"},
      {"GIT_AUTHOR_EMAIL", "t@t"},
      {"GIT_COMMITTER_NAME", "t"},
      {"GIT_COMMITTER_EMAIL", "t@t"}
    ]

    {_, 0} =
      System.cmd("git", ["-C", repo, "init", "--quiet", "-b", "main"], stderr_to_stdout: true)

    File.write!(Path.join(repo, "hello.txt"), "hello\n")
    {_, 0} = System.cmd("git", ["-C", repo, "add", "hello.txt"], stderr_to_stdout: true)

    {_, 0} =
      System.cmd("git", ["-C", repo, "commit", "-m", "init", "--quiet"],
        stderr_to_stdout: true,
        env: env
      )

    git!(repo, ["rev-parse", "HEAD"])
  end

  defp git!(dir, args) do
    {out, 0} = System.cmd("git", ["-C", dir | args], stderr_to_stdout: true)
    String.trim(out)
  end

  defp restore_env(key, nil), do: Application.delete_env(:xaas, key)
  defp restore_env(key, value), do: Application.put_env(:xaas, key, value)
end
