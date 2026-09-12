defmodule Mix.Tasks.Xaas.Telemetry.CheckOntologyStaleness do
  @shortdoc "Checks our vendored ontology copy against pinned upstream ex4pm"

  @moduledoc """
  Real, gracefully-degrading staleness check between the vendored ontology
  copy in this repo and the pinned upstream ex4pm source it was copied
  from. See `Xaas.Ontology.Ex4pmStaleness` for the full contract and
  non-goals.

  Exit behavior:

    * upstream matches vendored copy -> prints OK, exits 0
    * ex4pm sibling repo absent/unreachable/not a git repo -> prints
      UNSUPPORTED (skipped) with the reason, exits 0 (never a hard failure
      just because the sibling repo isn't present on this machine)
    * ex4pm present and reachable but the pinned SHA/path is broken, or the
      content genuinely diverges -> prints a remediation and raises
      (non-zero exit)

  Does not run `app.start` - this is a pure check with no application
  dependencies.
  """

  use Mix.Task

  alias Xaas.Ontology.Ex4pmStaleness

  @impl Mix.Task
  def run(_args) do
    case Ex4pmStaleness.check() do
      {:ok, :match} ->
        Mix.shell().info("OK: vendored ontology matches pinned upstream ex4pm content")

      {:ok, :skipped, reason} ->
        Mix.shell().info(
          "UNSUPPORTED (skipped): #{skip_explanation(reason)} -- this is not a failure, " <>
            "the ex4pm sibling repo is simply not present/reachable on this machine"
        )

      {:error, reason} ->
        Mix.shell().error(remediation(reason))
        Mix.raise("ontology staleness check failed: #{inspect(reason)}")
    end
  end

  defp skip_explanation({:git_not_found}) do
    "the `git` executable was not found on PATH"
  end

  defp skip_explanation({:repo_absent, repo_path}) do
    "ex4pm repo not found at #{inspect(repo_path)} (set EX4PM_REPO_PATH or config :xaas, :ex4pm_ontology_check, repo_path: ...)"
  end

  defp skip_explanation({:not_a_git_repo, repo_path}) do
    "#{inspect(repo_path)} exists but is not a git repository (checked via `git rev-parse --git-dir`)"
  end

  defp skip_explanation({:git_exec_failed, reason}) do
    "git could not be executed: #{inspect(reason)}"
  end

  defp skip_explanation(other), do: inspect(other)

  defp remediation({:sha_unreachable, sha}) do
    "pinned_sha #{sha} is not reachable in the ex4pm repo. Remediation: verify the SHA with " <>
      "`git -C <ex4pm repo> rev-parse --verify #{sha}^{commit}`, or re-pin per " <>
      "docs/claude/diataxis/reference/ex4pm-ontology-pin.md if the upstream history was rewritten."
  end

  defp remediation({:path_not_found, upstream_path, sha}) do
    "#{upstream_path} does not exist at #{sha} in the ex4pm repo. Remediation: the upstream file " <>
      "moved or was renamed -- find its new path with `git -C <ex4pm repo> log --follow --diff-filter=R " <>
      "-- #{upstream_path}` and update `upstream_path` in config/config.exs accordingly."
  end

  defp remediation({:unsafe_directory, detail}) do
    "git refused the ex4pm repo as an unsafe directory: #{detail}. Remediation: run " <>
      "`git config --global --add safe.directory <ex4pm repo path>`."
  end

  defp remediation({:permission_denied, detail}) do
    "permission denied reading the ex4pm repo: #{detail}. Remediation: check file permissions on the repo path."
  end

  defp remediation({:content_mismatch, upstream_sha256, vendored_sha256}) do
    "vendored ontology content diverges from pinned upstream ex4pm content " <>
      "(upstream sha256=#{upstream_sha256}, vendored sha256=#{vendored_sha256}). " <>
      "Remediation: re-vendor per docs/claude/diataxis/reference/ex4pm-ontology-pin.md " <>
      "(re-copy via `git show <new_sha>:<upstream_path> > <vendored_path>`, never a raw " <>
      "working-tree `cp`), and update `pinned_sha` in config/config.exs in the same commit."
  end

  defp remediation({:vendored_file_unreadable, path, posix}) do
    "could not read our vendored ontology file at #{path}: #{inspect(posix)}. Remediation: " <>
      "confirm `vendored_path` in config/config.exs points at a real, readable file."
  end

  defp remediation({:git_show_failed, exit_code, stderr}) do
    "`git show` failed (exit #{exit_code}): #{stderr}"
  end

  defp remediation(other), do: "ontology staleness check failed: #{inspect(other)}"
end
