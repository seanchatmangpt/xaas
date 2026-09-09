defmodule Xaas.Ontology.Ex4pmStalenessScenariosTest do
  @moduledoc """
  Real, non-mocked scenario tests for `Xaas.Ontology.Ex4pmStaleness.check/0`
  that exercise each branch by manipulating real application config and
  real files on disk -- never by stubbing the module itself.

  Three scenarios:

    1. A real matching pair (a real temp file whose content is copied
       byte-for-byte from a real `git show` of the pinned SHA) -> `:match`.
    2. A real deliberately-stale pair (same upstream blob, but the
       "vendored" file on disk has different content) -> `{:error,
       {:content_mismatch, ...}}`.
    3. The ex4pm repo path temporarily renamed/hidden on disk -> graceful
       `{:ok, :skipped, _}`, never a raise/crash.

  All three require a real `/Users/sac/ex4pm` (or `$EX4PM_REPO_PATH`)
  checkout with git available -- tagged `:external` and excluded from the
  default `mix test` run for the same reason as
  `ex4pm_staleness_test.exs`. Run with `mix test --include external`.
  """
  use ExUnit.Case, async: false

  @moduletag :external

  alias Xaas.Ontology.Ex4pmStaleness

  setup do
    original = Application.get_env(:xaas, :ex4pm_ontology_check, [])
    on_exit(fn -> Application.put_env(:xaas, :ex4pm_ontology_check, original) end)
    %{original: original}
  end

  defp real_repo_path(original) do
    Keyword.get(original, :repo_path)
  end

  defp git_available?(repo_path) do
    is_binary(repo_path) and File.dir?(repo_path) and
      not is_nil(System.find_executable("git"))
  end

  test "reports :match against the real, current, non-stale ex4pm content", %{
    original: original
  } do
    repo_path = real_repo_path(original)

    if git_available?(repo_path) do
      pinned_sha = Keyword.fetch!(original, :pinned_sha)
      upstream_path = Keyword.fetch!(original, :upstream_path)

      {upstream_content, 0} =
        System.cmd("git", ["show", "#{pinned_sha}:#{upstream_path}"],
          cd: repo_path,
          env: [{"GIT_DIR", nil}, {"GIT_WORK_TREE", nil}],
          stderr_to_stdout: true
        )

      tmp_path =
        Path.join(System.tmp_dir!(), "ex4pm_staleness_match_#{System.unique_integer([:positive])}")

      File.write!(tmp_path, upstream_content)
      on_exit(fn -> File.rm(tmp_path) end)

      relative_vendored_path = Path.relative_to(tmp_path, File.cwd!())

      Application.put_env(
        :xaas,
        :ex4pm_ontology_check,
        Keyword.put(original, :vendored_path, relative_vendored_path)
      )

      assert {:ok, :match} = Ex4pmStaleness.check()
    else
      # ex4pm not present on this machine -- graceful skip is the correct
      # outcome for this environment, not a failure of the test itself.
      assert {:ok, :skipped, _reason} = Ex4pmStaleness.check()
    end
  end

  test "detects drift against a deliberately-stale fixture with different content", %{
    original: original
  } do
    repo_path = real_repo_path(original)

    if git_available?(repo_path) do
      pinned_sha = Keyword.fetch!(original, :pinned_sha)
      upstream_path = Keyword.fetch!(original, :upstream_path)

      tmp_path =
        Path.join(System.tmp_dir!(), "ex4pm_staleness_stale_#{System.unique_integer([:positive])}")

      # Deliberately different content from whatever the real upstream
      # blob is -- proves the byte-comparison genuinely detects drift
      # rather than passing vacuously.
      File.write!(tmp_path, "DELIBERATELY STALE FIXTURE -- #{:erlang.unique_integer()}\n")
      on_exit(fn -> File.rm(tmp_path) end)

      relative_vendored_path = Path.relative_to(tmp_path, File.cwd!())

      Application.put_env(
        :xaas,
        :ex4pm_ontology_check,
        Keyword.merge(original,
          pinned_sha: pinned_sha,
          upstream_path: upstream_path,
          vendored_path: relative_vendored_path
        )
      )

      assert {:error, {:content_mismatch, upstream_hash, vendored_hash}} =
               Ex4pmStaleness.check()

      assert is_binary(upstream_hash)
      assert is_binary(vendored_hash)
      assert upstream_hash != vendored_hash
    else
      assert {:ok, :skipped, _reason} = Ex4pmStaleness.check()
    end
  end

  test "degrades gracefully to :skipped, never raising, when the ex4pm path is unavailable",
       %{original: original} do
    repo_path = real_repo_path(original)

    if is_binary(repo_path) and File.dir?(repo_path) do
      hidden_path = repo_path <> ".hidden_for_test_#{System.unique_integer([:positive])}"

      File.rename!(repo_path, hidden_path)

      on_exit(fn ->
        # Restore no matter what -- this must never leave the real ex4pm
        # checkout renamed on disk after the test run.
        if File.dir?(hidden_path) and not File.dir?(repo_path) do
          File.rename!(hidden_path, repo_path)
        end
      end)

      # repo_path in config still points at the now-renamed-away location.
      assert {:ok, :skipped, reason} = Ex4pmStaleness.check()
      assert is_tuple(reason)
    else
      # Already unavailable on this machine -- same graceful-skip
      # assertion, just without needing to rename anything ourselves.
      Application.put_env(
        :xaas,
        :ex4pm_ontology_check,
        Keyword.put(original, :repo_path, "/nonexistent/definitely/not/a/real/path")
      )

      assert {:ok, :skipped, reason} = Ex4pmStaleness.check()
      assert is_tuple(reason)
    end
  end
end
