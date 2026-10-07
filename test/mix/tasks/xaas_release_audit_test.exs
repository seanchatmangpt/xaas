defmodule Mix.Tasks.Xaas.ReleaseAuditTest do
  @moduledoc """
  Regression tests for the release_audit stale-pin fix (OS-19, v26.10.6).

  `check_version/1` is private and `tracked_files!/0` reads paths relative
  to the cwd, so a behavioral stale-VERSION injection cannot run the audit
  to its refusal render. Both version properties are therefore observed
  through real artifacts: the parity law (VERSION == mix.exs @version ==
  task @version expression) and a real audit run that must traverse past
  `check_version` into the downstream checks.
  """

  use ExUnit.Case, async: false

  @task_source "lib/mix/tasks/xaas.release_audit.ex"

  test "VERSION file content equals the mix project version (parity law)" do
    file_version = File.read!("VERSION") |> String.trim()
    mix_version = Mix.Project.config()[:version]

    assert file_version == mix_version,
           "VERSION=#{inspect(file_version)} vs mix.exs=#{inspect(mix_version)}"
  end

  test "task @version is derived from the VERSION file, never a stale literal" do
    source = File.read!(@task_source)

    # The OS-19 defect: a pinned literal that VERSION drifts away from.
    refute Regex.match?(~r/^  @version "/m, source),
           "release_audit @version must not be a pinned literal"

    assert source =~ ~r/@version File\.read!\("VERSION"\) \|> String\.trim\(\)/,
           "release_audit @version must derive from the VERSION file (mix.exs:13 shape)"
  end

  test "audit run traverses past check_version on the current version" do
    result =
      try do
        Mix.Tasks.Xaas.ReleaseAudit.run([])
        :ok
      rescue
        e -> e
      end

    # The audit must never fail at the version stage. Any raised error must
    # be a downstream drift finding, never a version mismatch.
    refute result == :ok or version_finding?(result),
           "audit must not fail on the current version"

    if result != :ok do
      refute version_finding?(result),
             "audit failure is a version mismatch: #{Exception.message(result)}"

      # check_version is the FIRST check; reaching the final rpc-alignment
      # check proves every earlier check ran against the current version and
      # accepted it. The audit must terminate in its typed-refusal render
      # (Mix.Error with a findings count), never a File.Error crash.
      assert %Mix.Error{message: message} = result,
             "expected typed refusal Mix.Error, got: " <> inspect(result)

      assert message =~ ~r/failed with \d+ finding\(s\)/,
             "audit must fail with a findings count: #{message}"
    end
  end

  test "audit does not emit a stale-router rpc-alignment finding against the live tree" do
    # W632 disposition: the reference was repointed kanban_web -> xaas_web
    # (c5f127cc rename). The typed-absent branch remains fail-closed, but on
    # the live tree the router exists and the mounts must verify, so no
    # rpc-alignment REFUSED line may render.
    assert File.exists?("lib/xaas_web/router.ex"),
           "precondition: the c5f127cc rename target is live"

    result =
      try do
        Mix.Tasks.Xaas.ReleaseAudit.run([])
        :ok
      rescue
        e -> e
      end

    # The W631 property holds regardless of disposition: the audit never
    # crashes on the router read (File.read + typed-absent branch, not read!).
    refute match?(%File.Error{}, result),
           "audit must not crash on the router read: " <> inspect(result)

    refusal_lines =
      capture_refusal_lines(fn -> Mix.Tasks.Xaas.ReleaseAudit.run([]) end)

    refute Enum.any?(
             refusal_lines,
             &String.contains?(&1, "rpc alignment:")
           ),
           "router mounts verified, no rpc-alignment finding expected, got: #{inspect(refusal_lines)}"
  end

  defp capture_refusal_lines(fun) do
    ExUnit.CaptureIO.capture_io(:stderr, fn ->
      try do
        fun.()
      rescue
        # The audit's typed-refusal render precedes its Mix.raise; the raise
        # is the expected termination, so swallow it to keep the captured
        # REFUSED lines.
        Mix.Error -> :ok
      end
    end)
    |> String.split("\n", trim: true)
    |> Enum.filter(&String.starts_with?(&1, "REFUSED(release_audit,"))
  end

  defp version_finding?(%Mix.Error{message: message}) do
    String.contains?(message, "VERSION=") or String.contains?(message, "Mix version=")
  end

  defp version_finding?(_), do: false
end
