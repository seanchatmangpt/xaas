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

    test "returns {:error, :not_found} for a real nonexistent path" do
      nonexistent = Path.join(System.tmp_dir!(), "does-not-exist-#{System.unique_integer([:positive])}/STATUS.md")

      refute File.exists?(nonexistent)
      assert StatusParser.parse(nonexistent) == {:error, :not_found}
    end
  end

  defp write_temp_status!(content) do
    path =
      Path.join(System.tmp_dir!(), "status_parser_test_#{System.unique_integer([:positive])}.md")

    File.write!(path, content)
    path
  end
end
