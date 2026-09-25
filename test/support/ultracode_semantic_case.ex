defmodule Xaas.Ultracode.SemanticCase do
  @moduledoc """
  Shared Chicago-style setup for the semantic Work/Wave suites
  (`SemanticWorkTest`, `SemanticWaveTest`).

  Root-cause law this template makes impossible to re-break: `Xaas.DataCase`
  establishes sandbox ownership only for `Xaas.LegacyRepo`, while these
  suites touch `Xaas.Repo` Ash resources through `SemanticWork.materialize/2`
  and `SemanticWave.run/1`. Without an explicit `Xaas.Repo` sandbox owner,
  every query raises `DBConnection.OwnershipError` (the repo is pinned
  `:manual` for the whole suite in `test/test_helper.exs`) -- the 5 real
  reds at `semantic_work.ex:141` (the `Xaas.Repo.transaction` inside
  `materialize/2`) and inside `semantic_wave.ex`'s `Task.async_stream`
  dispatch.

  Ownership follows the `EngineTest` law: a scoped
  `Ecto.Adapters.SQL.Sandbox.start_owner!(Xaas.Repo, shared: true)` +
  `stop_owner`. `shared: true` because the dispatch machinery runs its
  workers in `Task.async_stream` processes the test does not control, and
  those processes must join the same sandboxed connection. Scoped (never a
  repo-global `Sandbox.mode/2` flip) because a mode flip outlives the test
  and clobbers the live mode window of another `async: false` module -- the
  real cross-module interference documented in `EngineTest`'s setup.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Xaas.Ultracode.SemanticCase
    end
  end

  setup tags do
    Xaas.DataCase.setup_sandbox(tags)

    owner = Ecto.Adapters.SQL.Sandbox.start_owner!(Xaas.Repo, shared: true)

    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.stop_owner(owner)
    end)

    %{base: base, repo: repo, root: root, state: state, sha: sha} = put_semantic_fixture_env()

    %{base: base, repo: repo, root: root, state: state, sha: sha}
  end

  @doc """
  Installs the fake-repo / worktree-root / verifier-suite application env
  the semantic suites share, registering `on_exit` restoration of every
  key (including the semantic-wave runner and state-dir keys the wave
  suite swaps). Returns the fixture paths and the fake repo's base SHA.
  """
  def put_semantic_fixture_env do
    original = %{
      repos: Application.get_env(:xaas, :ultracode_repos),
      root: Application.get_env(:xaas, :ultracode_worktree_root),
      suites: Application.get_env(:xaas, :ultracode_verifier_suites),
      runner: Application.get_env(:xaas, :ultracode_semantic_wave_runner),
      state_dir: Application.get_env(:xaas, :ultracode_semantic_wave_state_dir)
    }

    base = mktmp("semantic")
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

    %{base: base, repo: repo, root: root, state: state, sha: sha}
  end

  @doc """
  A typed semantic execution descriptor for `SemanticWork.materialize/2`
  (and the wave dispatch suite) against the fixture repo, parameterized by
  a unique work-order suffix and execution policy.
  """
  def semantic_descriptor(sha, suffix, policy) do
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

  def mktmp(label) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "xaas-#{label}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end

  def init_repo(repo) do
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

  def git!(dir, args) do
    {out, 0} = System.cmd("git", ["-C", dir | args], stderr_to_stdout: true)
    String.trim(out)
  end

  def restore_env(key, nil), do: Application.delete_env(:xaas, key)
  def restore_env(key, value), do: Application.put_env(:xaas, key, value)
end
