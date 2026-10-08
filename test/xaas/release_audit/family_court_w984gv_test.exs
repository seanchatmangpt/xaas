defmodule Xaas.ReleaseAudit.FamilyCourtW984gvTest do
  @moduledoc """
  W984gv unclaimed-family probe: release/versioning surface of
  `Mix.Tasks.Xaas.ReleaseAudit` (lib/mix/tasks/xaas.release_audit.ex).

  Census finding: the OS-19 file (test/mix/tasks/xaas_release_audit_test.exs)
  pins the W650k *comparator law* only as a literal `Version.compare` assert
  and never drives `newest_release_tag/0` over a real multi-tag repo, so both
  remediated bugs (v-prefix `Version.parse` rejection; inverted `max_by`)
  could regress with every existing test green. This court adds real
  fixture-repo regression pins plus genuinely unexercised branches:
  `newest_release_tag/0`'s `{:error, reason}` transport arm, the
  non-vX.Y.Z tag filter, `render_refusal/1`, and the glob-expansion branch
  of `unresolved_plan_refs/2`.

  Zero mocks: every test invokes the real public functions over real git
  repos / real files in temp dirs. Mutation rationale is stated per test.
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

  # ---------------------------------------------------------------------
  # W650k regression pins (both remediated bugs, one real multi-tag repo)
  #
  # Mutation 1 (v-prefix rejection reintroduced: parse the tag WITH the
  # "v"): every tag fails Version.parse/1 and max_by collapses to the
  # lexically-first listing -> returns "v1.0.0" (lex-min of the three).
  # Mutation 2 (inverted max_by: plain lexicographic max over tags):
  # returns "v26.9.29", not "v26.10.6". Both mutants fail this test;
  # the pre-existing literal Version.compare pin passes under both.
  # ---------------------------------------------------------------------
  test "W984gv: newest_release_tag/0 picks the semver-newest tag over a real 3-tag repo" do
    in_tag_repo(["v1.0.0", "v26.9.29", "v26.10.6"], fn ->
      assert {:ok, "v26.10.6"} = Mix.Tasks.Xaas.ReleaseAudit.newest_release_tag()
    end)
  end

  test "W984gv: tags not matching vX.Y.Z are filtered before selection" do
    # Mutation: drop the Regex.filter in newest_release_tag/0 — the raw
    # listing would then include "rel-26.99" and "v26" (the latter fails
    # Version.parse -> 0.0.0 fallback), changing the selected max/first
    # element. Only the exact ^v\d+\.\d+\.\d+$ shape may compete.
    in_tag_repo(["v1.0.0", "v26", "rel-26.99"], fn ->
      assert {:ok, "v1.0.0"} = Mix.Tasks.Xaas.ReleaseAudit.newest_release_tag()
    end)
  end

  test "W984gv: newest_release_tag/0 in a non-git cwd returns {:error, reason}, never raises" do
    # Typed transport-failure arm: System.cmd git failure must surface as
    # {:error, _}, not an exception. Mutation: replace the {:error, ...}
    # arm with a raise or an :ok-wrapped value — this test fails.
    probe = Path.join(System.tmp_dir!(), "w984gv-nongit-#{System.unique_integer()}")
    File.mkdir_p!(probe)

    try do
      File.cd!(probe)

      assert {:error, reason} = Mix.Tasks.Xaas.ReleaseAudit.newest_release_tag()
      assert is_binary(reason) and reason != ""
    after
      File.cd(@repo_root)
      File.rm_rf!(probe)
    end
  end

  test "W984gv: render_refusal/1 emits the machine-readable REFUSED(code, detail:) shape" do
    # Mutation: drop the "REFUSED(" prefix or the detail inspect — the
    # exact string assert fails. This is the sole public renderer for the
    # audit's typed-refusal contract (Vector-2 §E) and had no direct pin.
    line = Mix.Tasks.Xaas.ReleaseAudit.render_refusal({:release_audit, %{finding: "boom"}})

    assert line == "REFUSED(release_audit, detail: %{finding: \"boom\"})"
    assert line =~ ~r/^REFUSED\([a-z_]+, detail: %\{.*\}\)$/
  end

  test "W984gv: closure_receipt_findings/1 accepts a resolving glob plan reference" do
    # Exercises the Path.wildcard branch of unresolved_plan_refs/2 (the
    # `Path.wildcard(&1) != []` reject). Mutation: resolve references with
    # File.exists? instead of glob expansion — the bracket reference
    # (a literal-nonexistent path under exists?, a resolving glob under
    # wildcard) would emit a finding and this test fails.
    version = File.read!("VERSION") |> String.trim()
    base = Path.join(System.tmp_dir!(), "w984gv-glob-#{System.unique_integer()}")
    plans = Path.join([base, "docs", "sjira", "v" <> version, "plans"])
    File.mkdir_p!(plans)
    File.write!(Path.join(plans, "w1-receipt.md"), "# w1\n")

    plan = """
    # closure
    Receipt: docs/sjira/v#{version}/plans/w1-receipt.md
    Glob: docs/sjira/v#{version}/plans/w[0-9]-receipt.md
    """

    assert [] = run_closure_findings(base, plan)

    # Anti-vacuity: the same glob shape that matches nothing must still be
    # flagged (the reject must not silently pass every reference).
    unresolved_plan = """
    # closure
    Receipt: docs/sjira/v#{version}/plans/w1-receipt.md
    Glob: docs/sjira/v#{version}/plans/w[0-9]-MISSING.md
    """

    assert findings = run_closure_findings(base, unresolved_plan)
    assert Enum.any?(findings, &String.contains?(&1, "w[0-9]-MISSING.md"))

    File.rm_rf!(base)
  end

  test "W984gv: closure_receipt_findings/1 flags an empty receipt corpus and a missing plan as typed findings" do
    # Real temp-tree invocation of both fail-closed arms: missing plan file
    # -> "closure plan missing", present plan + no plans dir -> "closure
    # receipt corpus empty". Mutation: relax either require_true to pass on
    # empty input and the corresponding assert fails.
    version = File.read!("VERSION") |> String.trim()
    base = Path.join(System.tmp_dir!(), "w984gv-empty-#{System.unique_integer()}")
    File.mkdir_p!(base)

    missing_plan =
      run_closure_findings(base, nil)
      |> Enum.filter(&String.contains?(&1, "closure plan missing"))

    assert missing_plan != []

    corpus_empty =
      run_closure_findings(base, "# plan with no receipts\n")
      |> Enum.filter(&String.contains?(&1, "closure receipt corpus empty"))

    assert corpus_empty != []

    File.rm_rf!(base)
  end

  # -- fixtures ------------------------------------------------------------

  # Runs closure_receipt_findings/1 with cwd temporarily at `base` (the
  # function reads relative paths), restoring cwd in all paths.
  defp run_closure_findings(base, plan_source) do
    version = Path.join(@repo_root, "VERSION") |> File.read!() |> String.trim()
    plans = Path.join([base, "docs", "sjira", "v" <> version])

    if plan_source do
      File.mkdir_p!(Path.join(plans, "plans"))
      File.write!(Path.join(plans, "_CLOSURE_PLAN.md"), plan_source)
    end

    File.cd!(base)
    findings = Mix.Tasks.Xaas.ReleaseAudit.closure_receipt_findings(version)
    File.cd(@repo_root)
    findings
  end

  defp in_tag_repo(tags, fun) do
    repo = Path.join(System.tmp_dir!(), "xaas-w984gv-tags-#{System.unique_integer()}")
    File.rm_rf!(repo)
    File.mkdir_p!(repo)

    {_, 0} = System.cmd("git", ["init", "-q", repo])
    {_, 0} = System.cmd("git", ["config", "user.email", "w984gv@fixture"], cd: repo)
    {_, 0} = System.cmd("git", ["config", "user.name", "w984gv"], cd: repo)
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
