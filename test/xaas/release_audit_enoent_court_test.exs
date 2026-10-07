defmodule Xaas.ReleaseAuditEnoentCourtTest do
  @moduledoc """
  W873 regression court for the release_audit typed-absent behavior
  (W845/W872 hardening).

  The post-W845/W872 check functions (`check_stale_claims/2`, `check_json/2`,
  `check_markdown_links/2`, `check_text_integrity/2`, `required_input!/1`) are
  all private with no fixture-path seam, so — following the OS-19 test file's
  convention — each property is observed through real `run/0` executions:

  1. Required-input contract (W872): running the audit with `VERSION` absent
     from the working directory must terminate in the loud typed refusal
     `REFUSED(release_audit, detail: %{finding: "required release-audit input
     VERSION unreadable: :enoent"})` — a `Mix.Error`, never a `File.Error`.
  2. Scanned-doc contract (W845): tracked-but-absent `.json`/`.md`/text files
     yield typed `:enoent` findings and the audit still terminates in its
     findings-count refusal — never a crash.
  3. Determinism: the scanned-doc probe run twice emits byte-identical
     `REFUSED` lines.

  cwd is swapped per test and restored in `on_exit`; no tracked file is ever
  mutated (the absent files exist only in the fixture repo's index).
  """

  use ExUnit.Case, async: false

  @repo_root File.cwd!()

  setup do
    # Guarantee the compile task is memoized for this VM *before* any cwd
    # swap, so the fixture probes never attempt to compile a non-project.
    Mix.Task.run("compile")

    on_exit(fn ->
      File.cd(@repo_root)
      File.rm_rf(probe_dir())
      File.rm_rf(fixture_repo())
    end)

    :ok
  end

  test "W872: VERSION absent in cwd is a loud typed refusal, not a File.Error" do
    File.mkdir_p!(probe_dir())
    File.cd!(probe_dir())

    result =
      try do
        Mix.Tasks.Xaas.ReleaseAudit.run([])
        :ok
      rescue
        e -> e
      end

    assert %Mix.Error{message: message} = result,
           "expected the typed-refusal Mix.Error, got: " <> inspect(result)

    assert message =~ "required release-audit input VERSION unreadable: :enoent",
           "refusal must name the required input and the :enoent: #{message}"

    assert message =~ "REFUSED(release_audit,",
           "refusal must carry the machine-readable REFUSED line: #{message}"
  end

  test "W872: every required input path takes the same typed-absent refusal arm" do
    # Source-shape check (same convention as the OS-19 file): required_input!
    # must be the sole read path for VERSION/.tool-versions/Dockerfile — no
    # bare File.read!/File.read on those paths outside required_input!/1.
    source = File.read!("lib/mix/tasks/xaas.release_audit.ex")

    assert source =~ ~r/defp required_input!/,
           "required_input!/1 seam must exist"

    # VERSION at module top is the OS-19/W700-mandated `@version
    # File.read!("VERSION")` derive-from read — a known-allowed exception,
    # NOT an unguarded W872 scan site (see w896-enoent-court-owner.md). The
    # scan scopes to the `def run` body (excluding the module-attribute line)
    # and the pattern only targets .tool-versions/Dockerfile paths.
    body = source |> String.split("def run", parts: 2) |> Enum.at(1)

    read_sites =
      Regex.scan(~r/File\.read!?[((]"(\.tool-versions|Dockerfile)"/, body)
      |> Enum.map(&hd/1)

    assert read_sites == [],
           "required inputs must only be read through required_input!/1, found: #{inspect(read_sites)}"
  end

  test "W845: tracked-but-absent json/md/text files yield typed :enoent findings, never a crash" do
    in_fixture_repo(fn ->
      result =
        try do
          Mix.Tasks.Xaas.ReleaseAudit.run([])
          :ok
        rescue
          e -> e
        end

      assert %Mix.Error{message: message} = result,
             "expected the findings-count refusal, got: " <> inspect(result)

      assert message =~ ~r/failed with \d+ finding\(s\)/,
             "audit must terminate in the findings-count refusal: #{message}"

      refusal_lines = capture_refusal_lines(fn -> Mix.Tasks.Xaas.ReleaseAudit.run([]) end)

      # Findings arrive wrapped as REFUSED(release_audit, detail: %{finding: "…"})
      # (W896 court-shape defect 1: bare-vs-wrapped mismatch) — extract the
      # bare finding strings from the wrapped shape, then assert on those.
      findings =
        refusal_lines
        |> Enum.flat_map(&Regex.scan(~r/REFUSED\(release_audit, detail: %\{finding: "([^"]*)"\}\)/, &1))
        |> Enum.map(&Enum.at(&1, 1))

      expected = [
        "tracked JSON file absent in worktree: absent.json",
        "tracked markdown file absent in worktree: absent.md",
        "stale-claim scan: tracked file absent in worktree: absent.json",
        "stale-claim scan: tracked file absent in worktree: absent.md",
        "cannot read tracked text file absent.json: :enoent"
      ]

      for finding <- expected do
        assert finding in findings,
               "missing typed :enoent finding #{inspect(finding)} in: #{inspect(findings)}"
      end
    end)
  end

  test "determinism: the typed-absent refusal set is identical across two runs" do
    in_fixture_repo(fn ->
      lines_1 = capture_refusal_lines(fn -> Mix.Tasks.Xaas.ReleaseAudit.run([]) end)
      lines_2 = capture_refusal_lines(fn -> Mix.Tasks.Xaas.ReleaseAudit.run([]) end)

      assert lines_1 == lines_2,
             "typed refusal lines must be deterministic across runs"

      assert lines_1 != [], "expected at least one typed refusal line"
    end)
  end

  # -- fixture -------------------------------------------------------------

  defp probe_dir do
    Path.join(@repo_root, "_build-laneW873/enoent_probe")
  end

  defp fixture_repo do
    System.tmp_dir!() |> Path.join("xaas-w873-enoent-fixture")
  end

  # Builds a real git repo whose index tracks files deleted from the
  # worktree — exactly the tracked-but-absent-in-worktree state the typed
  # :enoent arms exist for — plus copies of the real required inputs so the
  # audit traverses past `required_input!/1` into the scan checks.
  defp in_fixture_repo(fun) do
    repo = fixture_repo()
    File.rm_rf!(repo)
    File.mkdir_p!(repo)

    {_, 0} = System.cmd("git", ["init", "-q", repo])

    File.cp!(Path.join(@repo_root, "VERSION"), Path.join(repo, "VERSION"))
    File.cp!(Path.join(@repo_root, ".tool-versions"), Path.join(repo, ".tool-versions"))
    File.cp!(Path.join(@repo_root, "Dockerfile"), Path.join(repo, "Dockerfile"))

    # Safe content: no stale-claim patterns, no markdown links.
    File.write!(Path.join(repo, "present.md"), "# fixture\n\nNo links here.\n")
    File.write!(Path.join(repo, "absent.json"), ~s({"fixture": true}\n))
    File.write!(Path.join(repo, "absent.md"), "# absent\n")

    {_, 0} = System.cmd("git", ["add", "."], cd: repo)

    File.rm!(Path.join(repo, "absent.json"))
    File.rm!(Path.join(repo, "absent.md"))

    {tracked, 0} = System.cmd("git", ["ls-files"], cd: repo)
    tracked_paths = String.split(tracked, "\n", trim: true)

    assert "absent.json" in tracked_paths and "absent.md" in tracked_paths,
           "fixture precondition: absent files must still be tracked"

    refute File.exists?(Path.join(repo, "absent.json"))
    refute File.exists?(Path.join(repo, "absent.md"))

    File.cd!(repo)
    fun.()
  end

  defp capture_refusal_lines(fun) do
    ExUnit.CaptureIO.capture_io(:stderr, fn ->
      try do
        fun.()
      rescue
        Mix.Error -> :ok
      end
    end)
    |> String.split("\n", trim: true)
    |> Enum.filter(&String.starts_with?(&1, "REFUSED(release_audit,"))
  end
end
