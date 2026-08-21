defmodule Xaas.Autofde.StatusParser do
  @moduledoc """
  Plain (non-Ash) parser for the sibling `autofde-lab` repo's
  `docs/STATUS.md` dispatch sheet.

  `STATUS.md` uses two real heading shapes, both handled here:

    * `Last update: **pass N** (YYYY-MM-DD) — TEXT` / `Prior update: **pass N** (...) — TEXT`
      (the running narrative summary at the top of the file)
    * `## Pass N — TEXT (YYYY-MM-DD)` (the historical per-pass section headers)

  Verdict is inferred from the summary text: a negative signal ("does not",
  "not beat", "fail", case-insensitive) maps to `:mixed`; otherwise a
  `BLOCKED` marker (case-insensitive, as in `BLOCKED:ENVIRONMENT`) maps to
  `:blocked`; else `:pass`.

  Evidence paths are extracted from inline code spans in the summary that
  look like real repo-relative paths (contain a `/` and end in a known
  extension), e.g. `` `docs/2026-08-09-representative-sample-batch-results.tsv` ``.
  """

  @type verdict :: :pass | :blocked | :mixed

  @type entry :: %{
          pass: integer(),
          date: Date.t() | nil,
          verdict: verdict(),
          summary: String.t(),
          evidence_paths: [String.t()]
        }

  @default_path Path.expand("../autofde-lab/docs/STATUS.md", File.cwd!())

  @doc "Returns the real default `STATUS.md` path this module resolves against."
  @spec default_path() :: String.t()
  def default_path, do: @default_path

  @doc """
  Parses the real `STATUS.md` file at `path` (defaults to the sibling
  `autofde-lab` repo's `docs/STATUS.md`) into a list of `t:entry/0`
  structs, most-recent pass first as they appear in the file.

  Returns `{:error, :not_found}` if the file does not exist, rather than
  raising -- the sibling repo may not be checked out on this machine.
  """
  @spec parse(String.t()) :: [entry()] | {:error, :not_found}
  def parse(path \\ @default_path) do
    if File.exists?(path) do
      content = File.read!(path)
      do_parse(content)
    else
      {:error, :not_found}
    end
  end

  @update_header ~r/^(?:Last|Prior) update:\s*\*\*pass\s+(\d+)\*\*\s*\((\d{4}-\d{2}-\d{2})\)\s*—\s*(.*)$/

  @section_header ~r/^##\s*Pass\s+(\d+)\s*—\s*(.*?)\s*\((\d{4}-\d{2}-\d{2})\)\s*$/

  defp do_parse(content) do
    lines = String.split(content, "\n")

    lines
    |> Enum.with_index()
    |> Enum.flat_map(fn {line, idx} -> match_header(line, lines, idx) end)
    |> Enum.map(&build_entry/1)
  end

  # "Last update:"/"Prior update:" narrative headers: date and first line of
  # summary are on the header line itself; body continues on following
  # non-blank lines until the next header or a blank-line paragraph break
  # followed by another header/section.
  defp match_header(line, lines, idx) do
    case Regex.run(@update_header, line) do
      [_, pass, date, first_summary_line] ->
        [
          {String.to_integer(pass), date,
           gather_summary(first_summary_line, lines, idx + 1)}
        ]

      nil ->
        match_section_header(line, lines, idx)
    end
  end

  defp match_section_header(line, lines, idx) do
    case Regex.run(@section_header, line) do
      [_, pass, title, date] ->
        [{String.to_integer(pass), date, gather_summary(title, lines, idx + 1)}]

      nil ->
        []
    end
  end

  # Collect continuation lines belonging to the same pass entry: stop at the
  # next header line (either shape) or a blank line (paragraph/section
  # break in this file's real formatting).
  defp gather_summary(first_line, lines, start_idx) do
    continuation =
      lines
      |> Enum.drop(start_idx)
      |> Enum.take_while(fn l ->
        not Regex.match?(@update_header, l) and not Regex.match?(@section_header, l)
      end)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    [first_line | continuation]
    |> Enum.join(" ")
    |> String.trim()
  end

  defp build_entry({pass, date_str, summary}) do
    %{
      pass: pass,
      date: parse_date(date_str),
      verdict: infer_verdict(summary),
      summary: summary,
      evidence_paths: extract_evidence_paths(summary)
    }
  end

  defp parse_date(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end

  defp infer_verdict(summary) do
    downcased = String.downcase(summary)

    cond do
      mixed_signal?(downcased) -> :mixed
      String.contains?(downcased, "blocked") -> :blocked
      true -> :pass
    end
  end

  defp mixed_signal?(downcased) do
    String.contains?(downcased, "does not") or
      String.contains?(downcased, "not beat") or
      String.contains?(downcased, "fail")
  end

  @evidence_re ~r/`([\w\-\/\.]+\/[\w\-\.]+\.\w+)`/

  defp extract_evidence_paths(summary) do
    @evidence_re
    |> Regex.scan(summary)
    |> Enum.map(fn [_, path] -> path end)
    |> Enum.uniq()
  end
end
