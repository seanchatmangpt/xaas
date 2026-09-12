defmodule Xaas.Ontology.Ex4pmStaleness do
  @moduledoc """
  Real, gracefully-degrading staleness check between our vendored ontology
  copy and the pinned upstream ex4pm source it was copied from.

  Config surface (see `config/config.exs`, key `:xaas, :ex4pm_ontology_check`):

    * `:repo_path` - path to a local ex4pm checkout (default
      `$EX4PM_REPO_PATH` or `~/ex4pm`)
    * `:pinned_sha` - the exact 40-char commit SHA the vendored copy was
      taken from
    * `:upstream_path` - path (relative to the ex4pm repo root) of the
      upstream source file at that SHA
    * `:vendored_path` - path (relative to this repo's cwd) of our vendored
      copy

  `check/0` never raises on missing/absent environment - the entire point of
  this module is that ex4pm is a sibling repo that may not exist on a given
  machine (a contributor's laptop, most CI runners). Absence is reported as
  `{:ok, :skipped, reason}`, never as an error and never by raising. A real
  `{:error, reason}` is only returned when ex4pm is present, reachable, and
  git itself ran successfully but reported a real problem (bad SHA, moved
  path, permission issue) or the content genuinely diverges.

  ## Non-goals (v1, explicitly bounded scope)

  This is a byte-identical SHA-256 comparison only. It deliberately does
  NOT:

    * detect semantic-only reformatting (whitespace/comment changes that
      don't change meaning)
    * follow git renames
    * handle LFS pointers, gitlinks (submodules), or symlink/tree git
      objects specially - it assumes `git show <sha>:<path>` yields a plain
      blob
    * verify repo lineage/identity beyond path + SHA (it does not check
      that `repo_path` is "really" ex4pm, only that git can resolve the
      given SHA/path pair inside it)

  These are intentional scope limits, not oversights - broadening this
  check is a deliberate, separate decision, not a default to reach for.
  """

  @type reason :: term()

  @spec check() :: {:ok, :match} | {:ok, :skipped, reason()} | {:error, reason()}
  def check do
    case find_git() do
      {:skip, reason} ->
        {:ok, :skipped, reason}

      {:ok, git} ->
        case find_repo() do
          {:skip, reason} ->
            {:ok, :skipped, reason}

          {:ok, repo_path} ->
            case verify_git_repo(git, repo_path) do
              {:skip, reason} -> {:ok, :skipped, reason}
              :ok -> compare(git, repo_path)
            end
        end
    end
  end

  defp config do
    Application.get_env(:xaas, :ex4pm_ontology_check, [])
  end

  defp find_git do
    case System.find_executable("git") do
      nil -> {:skip, {:git_not_found}}
      path -> {:ok, path}
    end
  end

  defp find_repo do
    repo_path = Keyword.get(config(), :repo_path)

    cond do
      is_nil(repo_path) -> {:skip, {:repo_absent, repo_path}}
      not File.dir?(repo_path) -> {:skip, {:repo_absent, repo_path}}
      true -> {:ok, repo_path}
    end
  end

  defp verify_git_repo(git, repo_path) do
    case run_git(git, ["rev-parse", "--git-dir"], repo_path) do
      {:ok, {_out, 0}} -> :ok
      {:ok, {_out, _non_zero}} -> {:skip, {:not_a_git_repo, repo_path}}
      {:error, reason} -> {:skip, {:git_exec_failed, reason}}
    end
  end

  defp compare(git, repo_path) do
    pinned_sha = Keyword.fetch!(config(), :pinned_sha)
    upstream_path = Keyword.fetch!(config(), :upstream_path)
    vendored_path = Keyword.fetch!(config(), :vendored_path)

    object_ref = "#{pinned_sha}:#{upstream_path}"

    case run_git(git, ["show", object_ref], repo_path) do
      {:ok, {upstream_content, 0}} ->
        compare_content(upstream_content, vendored_path)

      {:ok, {stderr, exit_code}} ->
        {:error, classify_git_show_failure(stderr, exit_code, pinned_sha, upstream_path)}

      {:error, reason} ->
        {:ok, :skipped, {:git_exec_failed, reason}}
    end
  end

  defp compare_content(upstream_content, vendored_path) do
    expanded_vendored_path = Path.expand(vendored_path, File.cwd!())

    case File.read(expanded_vendored_path) do
      {:ok, vendored_content} ->
        upstream_hash = :crypto.hash(:sha256, upstream_content)
        vendored_hash = :crypto.hash(:sha256, vendored_content)

        if upstream_hash == vendored_hash do
          {:ok, :match}
        else
          {:error,
           {:content_mismatch, Base.encode16(upstream_hash, case: :lower),
            Base.encode16(vendored_hash, case: :lower)}}
        end

      {:error, posix} ->
        {:error, {:vendored_file_unreadable, expanded_vendored_path, posix}}
    end
  end

  defp classify_git_show_failure(stderr, exit_code, pinned_sha, upstream_path) do
    cond do
      String.contains?(stderr, "bad object") or String.contains?(stderr, "unable to read") ->
        {:sha_unreachable, pinned_sha}

      String.contains?(stderr, "does not exist in") ->
        {:path_not_found, upstream_path, pinned_sha}

      String.contains?(stderr, "detected dubious ownership") ->
        {:unsafe_directory, stderr}

      String.contains?(stderr, "permission denied") or
          String.contains?(stderr, "Permission denied") ->
        {:permission_denied, stderr}

      true ->
        {:git_show_failed, exit_code, stderr}
    end
  end

  # Runs git with ambient GIT_DIR/GIT_WORK_TREE explicitly cleared (a
  # hijacked ambient env is a real footgun when `cd:` is also given), and
  # rescues ErlangError for the git-binary-vanishes-mid-run race, which
  # System.cmd/3 raises for rather than returning.
  defp run_git(git, args, repo_path) do
    result =
      System.cmd(git, args,
        cd: repo_path,
        env: [{"GIT_DIR", nil}, {"GIT_WORK_TREE", nil}],
        stderr_to_stdout: true
      )

    {:ok, result}
  rescue
    e in ErlangError -> {:error, Exception.message(e)}
  end
end
