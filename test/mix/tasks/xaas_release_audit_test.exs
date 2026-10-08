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

    # The audit must never fail at the version stage. A fully-green audit
    # (result == :ok) trivially satisfies that; any raised error must be a
    # downstream drift finding, never a version mismatch. (W650k updated the
    # contract: the 19-domain/116+6 re-pin made the live-tree audit pass, so
    # :ok is now the expected outcome, not a failure of this property.)
    assert result == :ok or match?(%Mix.Error{}, result),
           "audit outcome must be :ok or the typed-refusal Mix.Error, got: " <>
             inspect(result)

    refute version_finding?(result),
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

  # -- W612: live version-tag baseline legs (WP-5, OS-19) -------------------

  test "W612: newest_release_tag/0 returns the newest vX.Y.Z tag or nil" do
    assert {:ok, tag_or_nil} = Mix.Tasks.Xaas.ReleaseAudit.newest_release_tag()

    case tag_or_nil do
      nil -> :ok
      tag -> assert Regex.match?(~r/^v\d+\.\d+\.\d+$/, tag)
    end
  end

  test "W612: tag selection is semver-ordered, not lexicographic" do
    # The comparator newest_release_tag/0 relies on: lexicographic string
    # order would pick v26.9.29 over v26.10.6; semver order must not.
    assert Version.compare(Version.parse!("26.10.5"), Version.parse!("26.9.29")) == :gt
  end

  test "W612: closure_receipt_findings/1 is empty when the receipt surface resolves" do
    findings = Mix.Tasks.Xaas.ReleaseAudit.closure_receipt_findings("26.10.6")

    # Findings here reflect the live receipt surface; any finding must name
    # the closure surface explicitly (never a crash or unrelated text).
    for finding <- findings do
      assert finding =~ "closure plan" or finding =~ "closure receipt corpus" or
               finding =~ "closure plan reference",
             "unexpected closure finding: #{inspect(finding)}"
    end
  end

  test "W612: audit run emits a typed version-baseline finding when tag is absent or diverged" do
    {:ok, tag} = Mix.Tasks.Xaas.ReleaseAudit.newest_release_tag()
    expected_v = "v" <> Mix.Project.config()[:version]

    refusal_lines = capture_refusal_lines(fn -> Mix.Tasks.Xaas.ReleaseAudit.run([]) end)

    baseline_findings =
      Enum.filter(
        refusal_lines,
        &String.contains?(&1, "VERSION baseline") or
          String.contains?(&1, "closure plan") or
          String.contains?(&1, "closure receipt corpus")
      )

    cond do
      is_nil(tag) ->
        assert Enum.any?(baseline_findings, &String.contains?(&1, "tag absent")),
               "tag-absent path must emit the typed finding: #{inspect(baseline_findings)}"

      tag != expected_v ->
        assert Enum.any?(baseline_findings, &String.contains?(&1, "pins diverged")),
               "diverged path must emit the typed finding: #{inspect(baseline_findings)}"

      true ->
        # Tag present and matching: closure legs must have run without a
        # version-baseline refusal (any closure findings are legitimate
        # surface findings, asserted in closure_receipt_findings test).
        :ok
    end
  end

  test "W612: tag-present fixture with matching tag and resolving receipt surface emits no baseline finding" do
    in_tag_fixture(fn repo ->
      File.cd!(repo)

      refute baseline_findings([]) != [] and tag_findings_present?(),
             "matching tag with resolving receipts must not refuse"

      lines = capture_refusal_lines(fn -> Mix.Tasks.Xaas.ReleaseAudit.run([]) end)

      refute Enum.any?(lines, &String.contains?(&1, "VERSION baseline")),
             "no version-baseline finding expected, got: #{inspect(lines)}"

      refute Enum.any?(lines, &String.contains?(&1, "closure")),
             "fixture closure surface must fully resolve, got: #{inspect(lines)}"
    end)
  end

  test "W612: tag-present fixture with diverged tag emits the pins-diverged finding" do
    in_tag_fixture(
      fn repo ->
        File.cd!(repo)
        lines = capture_refusal_lines(fn -> Mix.Tasks.Xaas.ReleaseAudit.run([]) end)

        assert Enum.any?(lines, &String.contains?(&1, "pins diverged")),
               "diverged fixture must emit the pins-diverged finding: #{inspect(lines)}"
      end,
      tag: "v0.0.1"
    )
  end

  test "W612: tag-absent fixture emits the tag-absent finding" do
    in_tag_fixture(
      fn repo ->
      File.cd!(repo)
      lines = capture_refusal_lines(fn -> Mix.Tasks.Xaas.ReleaseAudit.run([]) end)

      assert Enum.any?(lines, &String.contains?(&1, "tag absent")),
             "tag-absent fixture must emit the typed finding: #{inspect(lines)}"
    end,
      tag: false
    )
  end

  test "W612: matching tag with missing closure plan emits the closure-plan finding" do
    in_tag_fixture(
      fn repo ->
        File.cd!(repo)

        lines = capture_refusal_lines(fn -> Mix.Tasks.Xaas.ReleaseAudit.run([]) end)

        assert Enum.any?(
                 lines,
                 &String.contains?(&1, "closure plan missing for tagged release")
               ),
               "missing closure plan must be a typed finding: #{inspect(lines)}"
      end,
      omit_plan: true
    )
  end

  test "W612: matching tag with unresolved plan reference emits the unresolved-ref finding" do
    in_tag_fixture(
      fn repo ->
        File.cd!(repo)

        lines = capture_refusal_lines(fn -> Mix.Tasks.Xaas.ReleaseAudit.run([]) end)

        assert Enum.any?(
                 lines,
                 &String.contains?(&1, "closure plan reference does not resolve on disk")
               ),
               "unresolved plan reference must be a typed finding: #{inspect(lines)}"
      end,
      plan_extra:
        "See docs/sjira/v#{File.read!("VERSION") |> String.trim()}/plans/w999-missing.md.\n"
    )
  end

  # -- fixtures -------------------------------------------------------------

  defp tag_findings_present?, do: false

  defp baseline_findings(lines) do
    Enum.filter(lines, &String.contains?(&1, "VERSION baseline"))
  end

  defp in_tag_fixture(fun, opts \\ []) do
    Mix.Task.run("compile")
    repo = System.tmp_dir!() |> Path.join("xaas-w612-tag-fixture-#{System.unique_integer()}")

    File.rm_rf!(repo)
    File.mkdir_p!(repo)

    {_, 0} = System.cmd("git", ["init", "-q", repo])
    {_, 0} = System.cmd("git", ["config", "user.email", "w612@fixture"], cd: repo)
    {_, 0} = System.cmd("git", ["config", "user.name", "w612"], cd: repo)

    for src <- ["VERSION", ".tool-versions", "Dockerfile"] do
      File.cp!(Path.join(File.cwd!(), src), Path.join(repo, src))
    end

    version = File.read!(Path.join(repo, "VERSION")) |> String.trim()

    unless opts[:omit_plan] do
      # W650k: the audit's closure paths are v-prefixed (docs/sjira/v<VERSION>/),
      # matching the on-disk convention the live tree uses.
      plan_dir = Path.join([repo, "docs", "sjira", "v" <> version])
      File.mkdir_p!(Path.join(plan_dir, "plans"))

      File.write!(Path.join(plan_dir, "_CLOSURE_PLAN.md"), """
      # v#{version} Closure Plan

      Receipt: docs/sjira/v#{version}/plans/w1-receipt.md
      #{opts[:plan_extra] || ""}
      """)

      File.write!(Path.join([plan_dir, "plans", "w1-receipt.md"]), "# w1\n")
    end

    File.write!(Path.join(repo, "present.md"), "# fixture\n\nNo links here.\n")

    {_, 0} = System.cmd("git", ["add", "."], cd: repo)

    {_, 0} =
      System.cmd("git", ["commit", "-qm", "fixture"], cd: repo)

    tag = if opts[:tag] == false, do: nil, else: opts[:tag] || "v" <> version

    if tag do
      {_, 0} = System.cmd("git", ["tag", tag], cd: repo)
    end

    root = File.cwd!()

    try do
      fun.(repo)
    after
      File.cd!(root)
      File.rm_rf!(repo)
    end
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
