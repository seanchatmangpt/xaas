defmodule Xaas.Version.FamilyCourtW984hfTest do
  @moduledoc """
  W984hf unclaimed-family probe: version/release-audit surface
  (lib/mix/tasks/xaas.release_audit.ex — the repo has no `Xaas.Version`
  module; the version surface IS Mix.Tasks.Xaas.ReleaseAudit).

  Census: W984gv (test/xaas/release_audit/family_court_w984gv_test.exs)
  already courts the 3-tag semver selection, the vX.Y.Z filter, the
  {:error, _} transport arm, render_refusal's happy shape, the
  closure-plan glob expansion, and the empty-corpus / missing-plan arms.
  This court covers the genuinely remaining branches:

  - newest_release_tag/0 {:ok, nil} arm (git repo, zero tags)
  - prerelease / build-metadata tags rejected by the ^v\\d+\\.\\d+\\.\\d+$ filter
  - numeric-vs-lexicographic ordering disagreement (kills the inverted-max_by
    mutant in a shape the W984gv fixture does not)
  - render_refusal/1 guard clause (non-atom code => FunctionClauseError)
  - closure_receipt_findings/1 emitting an unresolved-reference finding

  Zero mocks: real git repos / real temp files only. Mutation rationale
  stated per test.
  """

  use ExUnit.Case, async: false

  @repo_root File.cwd!()

  setup do
    Mix.Task.run("compile")

    on_exit(fn ->
      File.cd(@repo_root)
    end)

    :ok
  end

  alias Mix.Tasks.Xaas.ReleaseAudit

  test "W984hf: newest_release_tag/0 returns {:ok, nil} in a git repo with no tags" do
    # Exercises the [] -> nil arm inside newest_release_tag/0, which W984gv
    # never reaches (its fixtures always create tags). Mutation: return the
    # head of the (empty) listing or {:ok, ""} instead of nil — assert fails.
    in_tag_repo([], fn ->
      assert {:ok, nil} = ReleaseAudit.newest_release_tag()
    end)
  end

  test "W984hf: prerelease and build-metadata tags are filtered out of selection" do
    # The filter is the exact ^v\d+\.\d+\.\d+$ shape, so v1.0.1-rc.1 and
    # v1.0.1+build.5 must not compete (and would crash Version.compare/2
    # against a mismatched shape if admitted... they parse fine, but the
    # contract is exact-shape-only). Mutation: relax the regex to
    # ~r/^v\d+\.\d+\.\d+/ (drop the $) — v1.0.1-rc.1 would be admitted and
    # the selected max becomes v1.0.1-rc.1, failing this assert.
    in_tag_repo(["v1.0.0", "v1.0.1-rc.1", "v1.0.1+build.5"], fn ->
      assert {:ok, "v1.0.0"} = ReleaseAudit.newest_release_tag()
    end)
  end

  test "W984hf: selection is numeric, not lexicographic (1.0.10 > 1.0.9)" do
    # Kills the inverted-max_by mutant in a second shape: lexicographic max
    # of ["v1.0.10", "v1.0.2", "v1.0.9"] is "v1.0.9" (character '9' > '1'),
    # semver max is v1.0.10. The W984gv fixture (v1.0.0/v26.9.29/v26.10.6)
    # also kills lexicographic order, but NOT a mutant that sorts by the
    # parsed-major-only or string-compare of the trimmed body; this shape
    # also pins 10 > 9 > 2 numerically at the patch segment.
    in_tag_repo(["v1.0.10", "v1.0.2", "v1.0.9"], fn ->
      assert {:ok, "v1.0.10"} = ReleaseAudit.newest_release_tag()
    end)
  end

  test "W984hf: render_refusal/1 guard rejects a non-atom code" do
    # The single guard clause `when is_atom(code)` is otherwise uncovered.
    # Mutation: drop the guard (accept any code) — no raise and this assert
    # fails.
    assert_raise FunctionClauseError, fn ->
      ReleaseAudit.render_refusal({"release_audit", %{finding: "boom"}})
    end
  end

  test "W984hf: closure_receipt_findings/1 emits a typed finding for an unresolved plan reference" do
    # The Enum.reduce over unresolved_plan_refs/2 in closure_receipt_findings/1
    # (the finding-emitting arm for refs that do NOT resolve on disk) is
    # unexercised: W984gv only covers the fully-resolving and missing-plan
    # cases. Mutation: remove the unresolved-ref reduce — the finding list
    # becomes [] and this assert fails.
    version = File.read!("VERSION") |> String.trim()
    base = Path.join(System.tmp_dir!(), "w984hf-unres-#{System.unique_integer()}")
    plans = Path.join([base, "docs", "sjira", "v" <> version, "plans"])
    File.mkdir_p!(plans)
    File.write!(Path.join(plans, "w1-receipt.md"), "# w1\n")

    plan = """
    # closure
    Good: docs/sjira/v#{version}/plans/w1-receipt.md
    Bad: docs/sjira/v#{version}/plans/w404-missing.md
    """

    findings = run_closure_findings(base, plan)

    assert [line] =
             Enum.filter(findings, &String.contains?(&1, "closure plan reference does not resolve"))

    assert line =~ "w404-missing.md"

    File.rm_rf!(base)
  end

  # -- fixtures ------------------------------------------------------------

  defp run_closure_findings(base, plan_source) do
    version = File.read!("VERSION") |> String.trim()
    plans = Path.join([base, "docs", "sjira", "v" <> version])

    if plan_source do
      File.mkdir_p!(Path.join(plans, "plans"))
      File.write!(Path.join(plans, "_CLOSURE_PLAN.md"), plan_source)
    end

    File.cd!(base)
    findings = ReleaseAudit.closure_receipt_findings(version)
    File.cd(@repo_root)
    findings
  end

  defp in_tag_repo(tags, fun) do
    repo = Path.join(System.tmp_dir!(), "xaas-w984hf-tags-#{System.unique_integer()}")
    File.rm_rf!(repo)
    File.mkdir_p!(repo)

    {_, 0} = System.cmd("git", ["init", "-q", repo])
    {_, 0} = System.cmd("git", ["config", "user.email", "w984hf@fixture"], cd: repo)
    {_, 0} = System.cmd("git", ["config", "user.name", "w984hf"], cd: repo)
    File.write!(Path.join(repo, "seed.txt"), "seed\n")
    {_, 0} = System.cmd("git", ["add", "."], cd: repo)
    {_, 0} = System.cmd("git", ["commit", "-qm", "seed"], cd: repo)

    for tag <- tags, do: {_, 0} = System.cmd("git", ["tag", tag], cd: repo)

    try do
      File.cd!(repo)
      fun.()
    after
      File.cd(@repo_root)
      File.rm_rf!(repo)
    end
  end
end
