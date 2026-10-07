defmodule Mix.Tasks.Xaas.EuAiActPack do
  @shortdoc "Assembles the EU AI Act conformance evidence pack from on-disk evidence (fail-closed)"

  @moduledoc """
  Assembles the machine-readable EU AI Act (Art. 12/14/15/50) conformance
  evidence bundle from REAL on-disk evidence: the v26.10.6 coverage map
  (`docs/sjira/v26.10.6/eu-ai-act-nist-coverage-map.md`), the refusal ledger
  corpus stats, and cited receipt/artifact paths.

  Usage:

      mix xaas.eu_ai_act_pack --out docs/cro/artifacts/eu-ai-act-pack.json

  Fail-closed generation: if any cited evidence path is missing on disk, the
  coverage map is missing, or the extracted typed-gaps section is empty, the
  task raises with a typed refusal and writes nothing (`REFUSED_EVIDENCE_PATH_MISSING`,
  `REFUSED_COVERAGE_MAP_MISSING`, `REFUSED_EMPTY_TYPED_GAPS`). The pack never
  claims a gap closed: the typed-gaps section is carried verbatim from the map.
  """

  use Mix.Task

  @map_path "docs/sjira/v26.10.6/eu-ai-act-nist-coverage-map.md"
  @ledger_path "docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json"
  @schema "xaas.eu_ai_act_pack/v1"

  @switches [out: :string]

  # Article-keyed verdicts, each traceable to the coverage map rows / aggregate
  # verdict section. Articles with no rows in the map carry a typed
  # NOT_MAPPED verdict — the pack never manufactures coverage.
  @articles %{
    "art5" => %{
      verdict: "NOT_MAPPED_IN_COVERAGE_MAP",
      note:
        "Art. 5 (prohibited AI practices) has no rows in the v26.10.6 coverage map; no coverage is claimed.",
      evidence: [@map_path]
    },
    "art9/10" => %{
      verdict: "NOT_MAPPED_IN_COVERAGE_MAP",
      note:
        "Art. 9/10 (risk management / data governance) have no rows in the v26.10.6 coverage map. Adjacent, not equivalent: NIST MAP rows + x7 risk register exist on disk.",
      evidence: [@map_path, "docs/sjira/v26.10.6/plans/x7-risk-register.md"]
    },
    "art11/12" => %{
      verdict: "PARTIAL — GAP(NO_RUNTIME_EXPORT_API)",
      note:
        "Art. 12(1)/(1)-(3)/(b)/(3) rows: EVIDENCED at refusal-as-logged-consequence class (OS-18 inverted gap disclosed); 12(3) narrowed to GAP(NO_RUNTIME_EXPORT_API) — doc-level export landed, automated runtime surface + retention artifact still open.",
      evidence: [
        @map_path,
        @ledger_path,
        "lib/xaas/telemetry/ocel_ndjson.ex",
        "lib/xaas/castle.ex",
        "lib/xaas/actuation.ex",
        "docs/sjira/v26.10.6/plans/w236-refusal-capstone.md",
        "docs/sjira/v26.10.6/plans/w379-actuation-kill.md"
      ]
    },
    "art13/14" => %{
      verdict: "EVIDENCED (with OS-18 inverted gap disclosed)",
      note:
        "Art. 14 rows 14(1), 14(4)(a)-(e): EVIDENCED at refusal-as-consequence class; 14(4)(e) code-level EVIDENCED + doc-class EVIDENCED-with-limitations (bias-awareness measures, OS-15 CLOSED 2026-10-06). Art. 13 has no dedicated rows in the map (typed refusal vocabulary serves the machine-readable class).",
      evidence: [
        @map_path,
        "lib/xaas/actuation.ex",
        "test/xaas/actuation_refusal_negative_test.exs",
        "docs/cro/artifacts/bias-awareness-measures-v26.10.6.md"
      ]
    },
    "art15" => %{
      verdict: "EVIDENCED",
      note:
        "Art. 15 rows 15(1)(a)(c)(d): drift refusal, fail-closed cybersecurity floor (plug/body-limit/revocation/CLOAK_KEY prod guard per OS-17 FIXED), refusal-first resilience.",
      evidence: [
        @map_path,
        "lib/xaas/castle.ex",
        "lib/xaas/vault.ex",
        "test/xaas_web/plugs/require_internal_api_token_test.exs",
        "test/xaas_web/endpoint_body_limit_test.exs",
        "test/xaas/accounts/token_revocation_test.exs"
      ]
    },
    "art50" => %{
      verdict: "PARTIAL — GAP(NO_END_USER_DISCLOSURE)",
      note:
        "Art. 50 rows: machine-readable refusal vocabulary + wire-conformant A2A v1 surface (w270 SSE, w385 26/26 in-repo conformance courts) are EVIDENCED; end-user-facing disclosure absent (OS-16 open; TCK-certified remains UNSUPPORTED).",
      evidence: [
        @map_path,
        "lib/xaas/actuation.ex",
        "test/xaas_web/a2a/v1_sse_test.exs",
        "docs/sjira/v26.10.6/plans/w385-conformance-court.md",
        "docs/cro/artifacts/end-user-disclosure-v26.10.6.md"
      ]
    },
    "art72/86" => %{
      verdict: "NOT_MAPPED_IN_COVERAGE_MAP",
      note:
        "Art. 72/86 (post-market monitoring / penalties) have no rows in the v26.10.6 coverage map; no coverage is claimed.",
      evidence: [@map_path]
    }
  }

  @typed_gaps %{
    source: @map_path,
    note:
      "Verbatim gap/state lines extracted from the coverage map at generation time. The pack never claims gaps closed.",
    lines: nil
  }

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")

    {parsed, _rest, _invalid} = OptionParser.parse(argv, strict: @switches)

    case parsed[:out] do
      nil ->
        Mix.raise("xaas.eu_ai_act_pack refused: REFUSED_MISSING_OUT_PATH (--out <path> required)")

      out ->
        case build() do
          {:ok, pack} ->
            json = Jason.encode!(pack, pretty: true)
            File.mkdir_p!(Path.dirname(Path.expand(out)))
            File.write!(out, json <> "\n")
            Mix.shell().info("wrote #{out} (#{Enum.count(pack.articles)} articles)")
            Mix.shell().info("verdict summary: #{summary_line(pack)}")

          {:refused, reason} ->
            Mix.shell().error(Jason.encode!(%{"refused" => inspect(reason)}))
            Mix.raise("xaas.eu_ai_act_pack refused: #{inspect(reason)}")
        end
    end
  end

  @doc """
  Builds the pack map. Returns `{:ok, pack}` or `{:refused, reason}` —
  fail-closed on any missing cited evidence path, missing coverage map,
  or empty typed-gaps extraction.
  """
  def build(now \\ DateTime.utc_now()) do
    with {:ok, map_path} <- require_file(@map_path),
         {:ok, gaps} <- extract_typed_gaps(map_path),
         articles <- verify_articles(),
         {:ok, ledger} <- load_ledger(),
         {:ok, subject} <- git_subject() do
      pack = %{
        schema: @schema,
        generated_at: DateTime.to_iso8601(now),
        subject: subject,
        source_map: %{path: @map_path},
        articles: articles,
        refusal_corpus: ledger,
        typed_gaps: Map.put(@typed_gaps, :lines, gaps)
      }

      {:ok, pack}
    end
  end

  defp require_file(path) do
    if File.exists?(path) do
      {:ok, path}
    else
      {:refused, {:REFUSED_COVERAGE_MAP_MISSING, path}}
    end
  end

  defp verify_articles do
    Enum.map(@articles, fn {key, spec} ->
      :ok = verify_paths!(spec.evidence)
      {key, %{verdict: spec.verdict, note: spec.note, evidence: spec.evidence}}
    end)
    |> Map.new()
  end

  @doc """
  Fail-closed evidence verification: every cited path must exist on disk at
  generation time. Raises `Mix.Error` with a typed refusal on the first
  missing path. Public so the fail-closed contract is directly testable
  against the real filesystem.
  """
  def verify_paths!(paths) when is_list(paths) do
    Enum.each(paths, fn path ->
      unless File.exists?(path) do
        refusal({:REFUSED_EVIDENCE_PATH_MISSING, path})
      end
    end)

    :ok
  end

  defp extract_typed_gaps(map_path) do
    gaps =
      map_path
      |> File.read!()
      |> String.split("\n")
      |> Enum.filter(fn line ->
        String.contains?(line, "GAP(") or Regex.match?(~r/OS-1[4-9]\b/, line)
      end)

    if gaps == [] do
      {:refused, :REFUSED_EMPTY_TYPED_GAPS}
    else
      {:ok, gaps}
    end
  end

  defp load_ledger do
    if File.exists?(@ledger_path) do
      case Jason.decode(File.read!(@ledger_path)) do
        {:ok, ledger} ->
          {:ok,
           %{
             status: "PRESENT",
             path: @ledger_path,
             counts: ledger["counts"],
             subject: ledger["subject"],
             notes: ledger["notes"]
           }}

        {:error, reason} ->
          {:refused, {:REFUSED_LEDGER_UNREADABLE, inspect(reason)}}
      end
    else
      {:ok, %{status: "ABSENT", expected_path: @ledger_path}}
    end
  end

  defp git_subject do
    case {git(["rev-parse", "HEAD"]), git(["rev-parse", "--abbrev-ref", "HEAD"])} do
      {{sha, 0}, {branch, 0}} ->
        {:ok, %{branch: String.trim(branch), head_sha: String.trim(sha)}}

      _ ->
        {:refused, :REFUSED_GIT_SUBJECT_UNAVAILABLE}
    end
  end

  defp git(args) do
    {out, code} = System.cmd("git", args, stderr_to_stdout: true)
    {out, code}
  end

  defp summary_line(pack) do
    pack.articles
    |> Enum.map(fn {k, v} -> "#{k}=#{v.verdict}" end)
    |> Enum.join("; ")
  end

  defp refusal(reason) do
    Mix.raise("xaas.eu_ai_act_pack refused: #{inspect(reason)}")
  end
end
