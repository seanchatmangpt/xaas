defmodule Xaas.Autofde.StatusParserTest do
  use ExUnit.Case, async: true

  alias Xaas.Autofde.StatusParser

  @sample """
  # STATUS — the standing dispatch for WIP closure

  Last update: **pass 20** (2026-08-09) — **Real, unbiased measurement,
  complete: AutoFDE Lab does not beat sregym's published SOTA.** A real
  finding: 10 of 25 sampled problems are `BLOCKED:ENVIRONMENT`. Raw results:
  `docs/2026-08-09-representative-sample-batch-results.tsv`.

  Prior update: **pass 19** (2026-08-09) — Broadened the elevated-revision
  fallback to app-tier deployments. Real, honest 4-trial aggregate: 3/4 =
  75% Diagnosis, 3/4 = 75% Mitigation. Full transcript:
  `docs/2026-08-09-lane-c-non-llm-planner-design.md`.

  ## Pass 11 — real merge sweep: PR #46 merged to master (2026-08-12)

  Per direct instruction: merged this branch's own work to master, real CI
  showed one failing check.
  """

  describe "parse/1" do
    test "parses real STATUS.md-shaped content into pass entries" do
      path = write_temp_status!(@sample)

      try do
        entries = StatusParser.parse(path)

        assert length(entries) == 3
        [pass20, pass19, pass11] = entries

        assert pass20.pass == 20
        assert pass20.date == ~D[2026-08-09]
        assert pass20.verdict == :mixed
        assert pass20.summary =~ "does not beat sregym"
        assert "docs/2026-08-09-representative-sample-batch-results.tsv" in pass20.evidence_paths

        assert pass19.pass == 19
        assert pass19.date == ~D[2026-08-09]
        assert pass19.verdict == :pass
        assert pass19.summary =~ "Broadened the elevated-revision"
        assert "docs/2026-08-09-lane-c-non-llm-planner-design.md" in pass19.evidence_paths

        assert pass11.pass == 11
        assert pass11.date == ~D[2026-08-12]
        assert pass11.verdict == :mixed
        assert pass11.summary =~ "real merge sweep"
      after
        File.rm!(path)
      end
    end

    test "detects a real :blocked verdict marker" do
      content = """
      ## Pass 3 — attempted the migration, environment unavailable (2026-08-01)

      Result: `BLOCKED:ENVIRONMENT` -- the target cluster was not reachable.
      """

      path = write_temp_status!(content)

      try do
        [entry] = StatusParser.parse(path)
        assert entry.pass == 3
        assert entry.verdict == :blocked
      after
        File.rm!(path)
      end
    end

    # Verbatim heading forms from ~/autofde-lab/docs/STATUS.md (2026-10-06).
    @real_pass47_heading "Last update: **pass 47** (2026-09-25) — **IEC-011 LLM residue census: the *Find* step in"
    @real_pass48_heading "Last update: **pass 48** (2026-09-25/26) — **v26.9.25 ALOOP cycle merged: ALOOP-001"
    @real_pass26_heading "Last update: **pass 26 / cap 11** (2026-09-11) — **LLM candidate-producer pool"
    @real_section11_heading "## Pass 11 — real merge sweep: PR #46 + 15 clean-mergeable open PRs merged to master, 4 conflicting PRs named and left open, no rebase (2026-08-12)"

    test "parses the well-formed real heading shape (pass 47)" do
      path = write_temp_status!(@real_pass47_heading <> "\n" <> @real_section11_heading <> "\n")

      try do
        entries = StatusParser.parse(path)
        assert length(entries) == 2

        [p47, p11] = entries
        assert p47.pass == 47
        assert p47.date == ~D[2026-09-25]
        assert p11.pass == 11
        assert p11.date == ~D[2026-08-12]
      after
        File.rm!(path)
      end
    end

    # Fixed 2026-10-06 (v26.10.6): @update_header now accepts partial second
    # dates (`/MM-DD` or `/DD`) in ranges like `(2026-09-25/26)` — the W63
    # defect class is closed for pass 48.
    test "pass 48's real date-range heading `(2026-09-25/26)` is parsed" do
      content = @real_pass48_heading <> "\ncontinuation line.\n"
      path = write_temp_status!(content)

      try do
        [entry] = StatusParser.parse(path)
        assert entry.pass == 48
      after
        File.rm!(path)
      end
    end

    # Fixed 2026-10-06 (v26.10.6): @update_header now accepts composite labels
    # (`pass 26 / cap 11`) — the W63 defect pin is promoted to a real assertion.
    test "the real `**pass 26 / cap 11**` composite heading is parsed" do
      # W63 receipt 2026-10-06: `Last update: **pass 26 / cap 11** (2026-09-11)`
      # exists verbatim in the real STATUS.md; the pre-fix @update_header's
      # `\*\*pass\s+(\d+)\*\*` demanded `**` right after the digits, so pass 26
      # was silently absent from the real-file parse (observed passes jumped
      # 29 -> 24).
      content = @real_pass26_heading <> "\ncontinuation line.\n"
      path = write_temp_status!(content)

      try do
        [entry] = StatusParser.parse(path)
        assert entry.pass == 26
      after
        File.rm!(path)
      end
    end

    # Flipped 2026-10-06 (v26.10.6): the composite label is now parsed, so the
    # heading yields an entry (W63 defect closed for this shape).
    test "CURRENT-BEHAVIOR PIN: `**pass 26 / cap 11**` composite heading is parsed" do
      content = @real_pass26_heading <> "\ncontinuation line.\n"
      path = write_temp_status!(content)

      try do
        assert [%{pass: 26}] = StatusParser.parse(path)
      after
        File.rm!(path)
      end
    end

    test "REAL FILE: parses the actual sibling STATUS.md; known passes present, duplicates expected" do
      real = StatusParser.default_path()

      if File.exists?(real) do
        entries = StatusParser.parse(real)
        assert is_list(entries)
        passes = Enum.map(entries, & &1.pass)

        # Observed 2026-10-06 against the real file post-v26.10.6 regex fix
        # (48 entries; pass 26 now parsed via composite-label support).
        assert 47 in passes
        assert 26 in passes
        assert 20 in passes
        assert 11 in passes
        assert 2 in passes
        # Pass 48's partial date range now parses (v26.10.6 regex fix).
        assert 48 in passes
        # Both heading shapes match the same line region, so passes 11/10/9/8/6
        # appear twice (narrative header + section header) — observed, pinned.
        assert Enum.count(passes, &(&1 == 11)) == 2
      else
        flunk("sibling STATUS.md missing at #{real}")
      end
    end

    test "negative: body text with no heading yields [], not an error" do
      path = write_temp_status!("Just prose.\nMore prose.\n")

      try do
        assert StatusParser.parse(path) == []
      after
        File.rm!(path)
      end
    end

    test "negative: an almost-heading row (missing ** and date) is skipped, not crashed on" do
      path = write_temp_status!("Last update: pass 99 (bad-date) no dash\n")

      try do
        assert StatusParser.parse(path) == []
      after
        File.rm!(path)
      end
    end

    test "returns {:error, :not_found} for a real nonexistent path" do
      nonexistent =
        Path.join(
          System.tmp_dir!(),
          "does-not-exist-#{System.unique_integer([:positive])}/STATUS.md"
        )

      refute File.exists?(nonexistent)
      assert StatusParser.parse(nonexistent) == {:error, :not_found}
    end
  end

  defp write_temp_status!(content) do
    # run_uid convention: wall clock + unique_integer (cross-VM collision
    # impossible); removed by callers' after-clauses, with an on_exit backstop.
    path =
      Path.join(
        System.tmp_dir!(),
        "status_parser_test_#{System.system_time(:millisecond)}_#{System.unique_integer([:positive])}.md"
      )

    File.write!(path, content)
    on_exit(fn -> File.rm(path) end)
    path
  end
end
