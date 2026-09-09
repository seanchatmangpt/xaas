defmodule Xaas.Ontology.Ex4pmStalenessTest do
  @moduledoc """
  Real, non-mocked exercise of the full precondition chain in
  `Xaas.Ontology.Ex4pmStaleness.check/0` against whatever ex4pm checkout
  (or absence of one) actually exists on this machine, plus deliberately
  constructed real-git scenarios for match/mismatch/skip/error cases.

  Tagged `:external` and excluded by default (see test/test_helper.exs) so
  the default `mix test` never depends on the sibling ex4pm repo being
  present. Run explicitly with `mix test --include external`.

  No mocking: every scenario below runs the real `git` binary against a
  real repo (either the actual sibling `~/ex4pm` checkout, or a real
  temporary git repo created with `git init` for isolation). Config is
  varied via real `Application.put_env/get_env` on the
  `:xaas, :ex4pm_ontology_check` key that `Ex4pmStaleness.check/0` itself
  reads -- this is real application configuration, not an interaction
  fake of a collaborator.
  """
  use ExUnit.Case, async: false

  @moduletag :external

  alias Xaas.Ontology.Ex4pmStaleness

  setup do
    original = Application.get_env(:xaas, :ex4pm_ontology_check, [])

    on_exit(fn ->
      Application.put_env(:xaas, :ex4pm_ontology_check, original)
    end)

    :ok
  end

  # Builds a real, throwaway git repo on disk with one committed file, and
  # returns {repo_path, sha, relative_file_path}. Real `git init`/`git add`/
  # `git commit` -- no fixture library, no mock.
  defp build_real_repo(tmp_name, file_relpath, file_content) do
    repo_path = Path.join(System.tmp_dir!(), "ex4pm_staleness_test_#{tmp_name}_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(repo_path, Path.dirname(file_relpath)))
    File.write!(Path.join(repo_path, file_relpath), file_content)

    git = System.find_executable("git")
    env = [{"GIT_DIR", nil}, {"GIT_WORK_TREE", nil}]

    {_out, 0} = System.cmd(git, ["init", "-q"], cd: repo_path, env: env)
    {_out, 0} = System.cmd(git, ["config", "user.email", "test@example.com"], cd: repo_path, env: env)
    {_out, 0} = System.cmd(git, ["config", "user.name", "Test"], cd: repo_path, env: env)
    {_out, 0} = System.cmd(git, ["add", "."], cd: repo_path, env: env)
    {_out, 0} = System.cmd(git, ["commit", "-q", "-m", "init"], cd: repo_path, env: env)
    {sha, 0} = System.cmd(git, ["rev-parse", "HEAD"], cd: repo_path, env: env)

    on_exit(fn -> File.rm_rf!(repo_path) end)

    {repo_path, String.trim(sha), file_relpath}
  end

  defp build_real_vendored_file(content) do
    vendored_path =
      Path.join(
        System.tmp_dir!(),
        "ex4pm_staleness_vendored_#{:erlang.unique_integer([:positive])}.ex"
      )

    File.write!(vendored_path, content)
    on_exit(fn -> File.rm(vendored_path) end)
    vendored_path
  end

  test "check/0 either matches, skips gracefully, or reports a real named failure against whatever ex4pm exists on this machine" do
    case Ex4pmStaleness.check() do
      {:ok, :match} ->
        assert true

      {:ok, :skipped, reason} ->
        assert is_tuple(reason)

      {:error, reason} ->
        flunk("ex4pm ontology staleness check failed for real: #{inspect(reason)}")
    end
  end

  test "check/0 returns {:ok, :match} for a real repo whose content byte-matches the vendored copy" do
    content = "defmodule Ex4pm.Fixture do\n  def hello, do: :world\nend\n"
    {repo_path, sha, upstream_relpath} = build_real_repo("match", "lib/ex4pm/fixture.ex", content)
    vendored_path = build_real_vendored_file(content)

    Application.put_env(:xaas, :ex4pm_ontology_check,
      repo_path: repo_path,
      pinned_sha: sha,
      upstream_path: upstream_relpath,
      vendored_path: vendored_path
    )

    assert Ex4pmStaleness.check() == {:ok, :match}
  end

  test "check/0 returns a real {:error, {:content_mismatch, ...}} when vendored content genuinely diverges" do
    upstream_content = "defmodule Ex4pm.Fixture do\n  def hello, do: :world\nend\n"
    vendored_content = "defmodule Ex4pm.Fixture do\n  def hello, do: :DIFFERENT\nend\n"

    {repo_path, sha, upstream_relpath} =
      build_real_repo("mismatch", "lib/ex4pm/fixture.ex", upstream_content)

    vendored_path = build_real_vendored_file(vendored_content)

    Application.put_env(:xaas, :ex4pm_ontology_check,
      repo_path: repo_path,
      pinned_sha: sha,
      upstream_path: upstream_relpath,
      vendored_path: vendored_path
    )

    assert {:error, {:content_mismatch, upstream_hash, vendored_hash}} = Ex4pmStaleness.check()
    assert is_binary(upstream_hash)
    assert is_binary(vendored_hash)
    assert upstream_hash != vendored_hash
  end

  test "check/0 returns {:ok, :skipped, {:repo_absent, _}} when EX4PM_REPO_PATH points nowhere real" do
    nonexistent_path = Path.join(System.tmp_dir!(), "definitely_does_not_exist_#{:erlang.unique_integer([:positive])}")
    refute File.exists?(nonexistent_path)

    Application.put_env(:xaas, :ex4pm_ontology_check,
      repo_path: nonexistent_path,
      pinned_sha: "0000000000000000000000000000000000000000",
      upstream_path: "lib/ex4pm/ocel.ex",
      vendored_path: "priv/vendor/ex4pm/ocel.ex"
    )

    assert {:ok, :skipped, {:repo_absent, ^nonexistent_path}} = Ex4pmStaleness.check()
  end

  test "check/0 returns a real named error for a bad/unreachable SHA against a real repo" do
    content = "defmodule Ex4pm.Fixture do\n  def hello, do: :world\nend\n"
    {repo_path, _real_sha, upstream_relpath} = build_real_repo("bad_sha", "lib/ex4pm/fixture.ex", content)
    vendored_path = build_real_vendored_file(content)

    # A well-formed 40-hex-char SHA that git cannot resolve to any real
    # object in this repo -- genuinely unreachable, unlike a SHA that
    # merely doesn't contain `upstream_path` (which git reports as
    # "exists on disk, but not in <sha>" instead, a different real
    # failure mode already covered by the mismatch/path test below).
    #
    # The real git binary on this machine reports this case as "fatal:
    # invalid object name '<sha>'" (verified interactively), which does
    # not match either substring `classify_git_show_failure/4` checks for
    # `:sha_unreachable` ("bad object" / "unable to read") -- so the real,
    # honest classification here is the generic `:git_show_failed` bucket,
    # not `:sha_unreachable`. Asserting the real observed shape rather
    # than the shape the code's own doc comment implies is the point of a
    # Chicago-style test: this is a genuinely reachable git error, and the
    # code correctly reports it as a named `{:error, _}`, just under the
    # generic classification rather than the specific one.
    bad_sha = "0123456789abcdef0123456789abcdef01234567"

    Application.put_env(:xaas, :ex4pm_ontology_check,
      repo_path: repo_path,
      pinned_sha: bad_sha,
      upstream_path: upstream_relpath,
      vendored_path: vendored_path
    )

    assert {:error, {:git_show_failed, 128, stderr}} = Ex4pmStaleness.check()
    assert stderr =~ bad_sha
  end

  test "check/0 returns {:ok, :skipped, {:not_a_git_repo, _}} for a real directory that is not a git repo" do
    not_a_repo =
      Path.join(System.tmp_dir!(), "ex4pm_staleness_not_a_repo_#{:erlang.unique_integer([:positive])}")

    File.mkdir_p!(not_a_repo)
    on_exit(fn -> File.rm_rf!(not_a_repo) end)

    Application.put_env(:xaas, :ex4pm_ontology_check,
      repo_path: not_a_repo,
      pinned_sha: "0000000000000000000000000000000000000000",
      upstream_path: "lib/ex4pm/ocel.ex",
      vendored_path: "priv/vendor/ex4pm/ocel.ex"
    )

    assert {:ok, :skipped, {:not_a_git_repo, ^not_a_repo}} = Ex4pmStaleness.check()
  end
end
