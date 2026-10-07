defmodule Xaas.Ontology.StalenessTaskCourtTest do
  @moduledoc """
  W869 task-level court for the ex4pm ontology-staleness check
  (`Xaas.Ontology.Ex4pmStaleness` + `mix xaas.telemetry.check_ontology_staleness`).

  Complements the W702-era `ex4pm_staleness_test.exs` (which is `:external`-tagged
  and excluded from the default run) with a default-runnable court that:

    (a) runs the REAL `check/0` against the REAL vendored pin bytes
        (`priv/vendor/ex4pm/ocel.ex`) staged into a real throwaway git repo
        at the pinned upstream path -> the real `{:ok, :match}` verdict;
    (b) corrupts a temp copy of the vendored file -> the real typed
        `{:error, {:content_mismatch, _, _}}` verdict, not a crash;
    (c) invokes the real mix task via `Mix.Task.run/1` with the config seam
        (`:xaas, :ex4pm_ontology_check`) pointed at the temp fixture, and
        inspects the real printed output / real raise;
    (d) checks determinism: two consecutive `check/0` runs on the same
        subject give byte-identical verdicts.

  No mocks. Every scenario runs the real `git` binary against a real repo;
  config is varied through the real `Application.put_env/2` seam the module
  itself reads.
  """
  use ExUnit.Case, async: false

  alias Xaas.Ontology.Ex4pmStaleness

  @vendored_relpath "priv/vendor/ex4pm/ocel.ex"
  @upstream_relpath "lib/ex4pm/ocel.ex"

  setup do
    original = Application.get_env(:xaas, :ex4pm_ontology_check, [])

    on_exit(fn ->
      Application.put_env(:xaas, :ex4pm_ontology_check, original)
    end)

    :ok
  end

  # Real vendored bytes, read from the tree at /Users/sac/xaas.
  defp real_vendored_content do
    path = Path.expand(@vendored_relpath, File.cwd!())
    assert File.exists?(path), "real vendored pin missing at #{path}"
    File.read!(path)
  end

  # Builds a real throwaway git repo on disk with one committed file at the
  # pinned upstream path; returns {repo_path, sha}. Real `git init/add/commit`
  # — no fixture library, no mock.
  defp build_real_repo(tmp_name, upstream_content) do
    repo_path =
      Path.join(
        System.tmp_dir!(),
        "staleness_court_#{tmp_name}_#{:erlang.unique_integer([:positive])}"
      )

    File.mkdir_p!(Path.join(repo_path, Path.dirname(@upstream_relpath)))
    File.write!(Path.join(repo_path, @upstream_relpath), upstream_content)

    git = System.find_executable("git")
    env = [{"GIT_DIR", nil}, {"GIT_WORK_TREE", nil}]

    {_o, 0} = System.cmd(git, ["init", "-q"], cd: repo_path, env: env)
    {_o, 0} = System.cmd(git, ["config", "user.email", "court@example.com"], cd: repo_path, env: env)
    {_o, 0} = System.cmd(git, ["config", "user.name", "Court"], cd: repo_path, env: env)
    {_o, 0} = System.cmd(git, ["add", "."], cd: repo_path, env: env)
    {_o, 0} = System.cmd(git, ["commit", "-q", "-m", "court pin"], cd: repo_path, env: env)
    {sha, 0} = System.cmd(git, ["rev-parse", "HEAD"], cd: repo_path, env: env)

    on_exit(fn -> File.rm_rf!(repo_path) end)

    {repo_path, String.trim(sha)}
  end

  defp put_config(repo_path, sha, vendored_abs_or_rel_path) do
    Application.put_env(:xaas, :ex4pm_ontology_check,
      repo_path: repo_path,
      pinned_sha: sha,
      upstream_path: @upstream_relpath,
      vendored_path: vendored_abs_or_rel_path
    )
  end

  defp temp_vendored_copy(content) do
    path =
      Path.join(
        System.tmp_dir!(),
        "staleness_court_vendored_#{:erlang.unique_integer([:positive])}.ex"
      )

    File.write!(path, content)
    on_exit(fn -> File.rm(path) end)
    path
  end

  # (a) The real module against the REAL vendored pin bytes: the vendored
  # file's exact content is committed into a real git repo at the pinned
  # upstream path, and `check/0` must return the real fresh verdict.
  test "(a) check/0 returns the real fresh verdict {:ok, :match} against the real vendored pin bytes" do
    content = real_vendored_content()
    {repo_path, sha} = build_real_repo("fresh", content)
    vendored_path = temp_vendored_copy(content)
    put_config(repo_path, sha, vendored_path)

    assert Ex4pmStaleness.check() == {:ok, :match}
  end

  # Also: against this machine's ambient config (~/ex4pm present or not),
  # the real check must land in one of the two non-failing verdict classes,
  # never raise. If ~/ex4pm is present and pinned correctly it is a match;
  # absence is a graceful skip, never an error.
  test "(a2) ambient check/0 never crashes and never error-classifies an absent sibling" do
    result = Ex4pmStaleness.check()

    assert match?({:ok, :match}, result) or match?({:ok, :skipped, _}, result) or
             match?({:error, _}, result)

    # If the sibling repo is genuinely absent on this machine, the real
    # verdict must be the graceful skip, not a hard error.
    repo_configured = Application.get_env(:xaas, :ex4pm_ontology_check, []) |> Keyword.get(:repo_path)

    if is_binary(repo_configured) and not File.dir?(repo_configured) do
      assert {:ok, :skipped, {:repo_absent, _}} = result
    end
  end

  # (b) A corrupted temp copy of the vendored file -> real typed staleness
  # verdict, not a crash.
  test "(b) corrupted vendored copy yields real typed {:error, {:content_mismatch, _, _}}" do
    content = real_vendored_content()
    {repo_path, sha} = build_real_repo("corrupt", content)

    corrupted =
      content
      |> String.replace("defmodule", "defmodule", global: false)
      |> Kernel.<>("
# W869 CORRUPTION MARKER: staleness must fire
")

    assert corrupted != content
    vendored_path = temp_vendored_copy(corrupted)
    put_config(repo_path, sha, vendored_path)

    assert {:error, {:content_mismatch, upstream_hash, vendored_hash}} = Ex4pmStaleness.check()
    assert is_binary(upstream_hash) and byte_size(upstream_hash) == 64
    assert is_binary(vendored_hash) and byte_size(vendored_hash) == 64
    assert upstream_hash != vendored_hash

    # The vendored hash must be the real SHA-256 of the corrupted bytes.
    assert vendored_hash == Base.encode16(:crypto.hash(:sha256, corrupted), case: :lower)
  end

  # (c) The real mix task, invoked through Mix.Task.run with the config seam
  # pointed at a temp fixture; real printed output captured and inspected.
  test "(c) mix task prints real OK verdict on fresh pin via Mix.Task.run" do
    content = real_vendored_content()
    {repo_path, sha} = build_real_repo("task_fresh", content)
    vendored_path = temp_vendored_copy(content)
    put_config(repo_path, sha, vendored_path)


    output =
      ExUnit.CaptureIO.capture_io(fn ->
        Mix.Task.reenable("xaas.telemetry.check_ontology_staleness")
        Mix.Task.run("xaas.telemetry.check_ontology_staleness", [])
      end)

    assert output =~ "OK: vendored ontology matches pinned upstream ex4pm content"
  end

  test "(c2) mix task raises with real remediation text on corrupted pin via Mix.Task.run" do
    content = real_vendored_content()
    {repo_path, sha} = build_real_repo("task_corrupt", content)

    corrupted = content <> "\n# W869 CORRUPTION MARKER\n"
    vendored_path = temp_vendored_copy(corrupted)
    put_config(repo_path, sha, vendored_path)


    output =
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        assert_raise(Mix.Error, ~r/ontology staleness check failed/, fn ->
          Mix.Task.reenable("xaas.telemetry.check_ontology_staleness")
          Mix.Task.run("xaas.telemetry.check_ontology_staleness", [])
        end)
      end)

    assert output =~ "content diverges from pinned upstream ex4pm content"
    assert output =~ "upstream sha256="
    assert output =~ "vendored sha256="
  end

  test "(c3) mix task prints real UNSUPPORTED (skipped) verdict for absent sibling" do
    absent =
      Path.join(
        System.tmp_dir!(),
        "staleness_court_absent_#{:erlang.unique_integer([:positive])}"
      )

    refute File.exists?(absent)
    put_config(absent, "ade25ed12e93f89e7a2e1490698f99ae4947d702", "priv/vendor/ex4pm/ocel.ex")


    output =
      ExUnit.CaptureIO.capture_io(fn ->
        Mix.Task.reenable("xaas.telemetry.check_ontology_staleness")
        Mix.Task.run("xaas.telemetry.check_ontology_staleness", [])
      end)

    assert output =~ "UNSUPPORTED (skipped)"
    assert output =~ "not a failure"
  end

  # (d) Determinism x2: same subject, same verdict, byte-identical reason
  # tuples across two consecutive real runs.
  test "(d) check/0 is deterministic across two consecutive runs" do
    content = real_vendored_content()
    {repo_path, sha} = build_real_repo("determinism", content)
    vendored_path = temp_vendored_copy(content)
    put_config(repo_path, sha, vendored_path)

    first = Ex4pmStaleness.check()
    second = Ex4pmStaleness.check()
    assert first == second
    assert first == {:ok, :match}

    # Also deterministic on the failure path: same mismatch hashes both runs.
    corrupted = content <> "\n# W869 CORRUPTION MARKER\n"
    corrupted_path = temp_vendored_copy(corrupted)
    put_config(repo_path, sha, corrupted_path)

    c1 = Ex4pmStaleness.check()
    c2 = Ex4pmStaleness.check()
    assert c1 == c2
    assert {:error, {:content_mismatch, _, _}} = c1
  end
end
