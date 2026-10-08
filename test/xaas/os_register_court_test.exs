defmodule Xaas.OsRegisterCourtTest do
  @moduledoc """
  Machine-checkable standing court for the v26.10.6 OS register
  (`docs/sjira/v26.10.6/_CLOSURE_PLAN.md` §4, rows `| OS-…`).

  Recomputes each row's evidence leg from disk on every run:
    1. every file-shaped receipt citation (`*.md`) in an OS row must resolve to a
       real file (repo-root-relative, `plans/`-prefixed under this wave dir, or a
       bare receipt name under `docs/sjira/v26.10.6/plans/`);
    2. every OS row that names a cited test file (`test/**.exs`) must have that
       file on disk;
    3. the register must actually carry the full OS-1..OS-21 row set (a truncated
       register is a register failure, not a pass).
  """

  use ExUnit.Case, async: true

  @wave_dir "docs/sjira/v26.10.6"
  @register_path Path.join(@wave_dir, "_CLOSURE_PLAN.md")

  @doc """
  Extract OS rows from the register as `{id, line}` tuples.
  Public so lanes can re-run the same parse the court asserts on.
  """
  def os_rows do
    case File.read(@register_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.filter(&String.starts_with?(&1, "| OS-"))
        |> Enum.map(fn line ->
          id =
            line
            |> parse_cell()
            |> hd()
            |> String.trim_trailing(" ")

          {id, line}
        end)

      {:error, reason} ->
        raise "OS register unreadable: #{inspect(reason)} (#{@register_path})"
    end
  end

  defp parse_cell(line) do
    line
    |> String.split("|")
    |> Enum.drop(1)
    |> Enum.map(&String.trim/1)
  |> Enum.take(1)
  end

  @doc """
  Resolve a citation string found in an OS row to a real path on disk.
  """
  def resolve_citation(cite) do
    cond do
      String.starts_with?(cite, "docs/") ->
        cite

      String.starts_with?(cite, "plans/") ->
        Path.join(@wave_dir, cite)

      # bare receipt filename: search this wave's plans dir
      String.match?(cite, ~r/^w\d+[a-z0-9-]*\.md$/) ->
        candidate = Path.join([@wave_dir, "plans", cite])
        if File.exists?(candidate), do: candidate, else: cite

      true ->
        cite
    end
  end

  @doc """
  All file-shaped (`.md`) citations in an OS row line, deduplicated.
  """
  def md_citations(line) do
    Regex.scan(~r/[A-Za-z0-9_\/.-]*w\d+[a-z0-9-]*\.md/, line)
    |> Enum.map(&hd/1)
    |> Enum.uniq()
  end

  @doc """
  Cited test files (`test/**.exs`) named in an OS row line.
  """
  def cited_tests(line) do
    Regex.scan(~r/test\/[A-Za-z0-9_\/.-]+\.exs/, line)
    |> Enum.map(&hd/1)
    |> Enum.uniq()
  end

  test "register carries the full OS-1..OS-21 row set" do
    rows = os_rows()
    ids = Enum.map(rows, &elem(&1, 0))

    for n <- 1..21 do
      id = "OS-#{n}"
      assert id in ids, "register row #{id} missing from #{@register_path}"
    end

    # no duplicate rows
    assert length(ids) == length(Enum.uniq(ids)), "duplicate OS row ids: #{inspect(ids)}"
  end

  # Floor set at run time against the live register (concurrently edited by
  # register-sweep lanes): measured 17 md citations / 3 cited tests on
  # 2026-10-07. Guard against vacuous parse, not against content edits.
  @min_md_citations 12

  test "every .md receipt citation in every OS row resolves to a real file" do
    rows = os_rows()

    total =
      Enum.sum(Enum.map(rows, fn {_id, line} -> length(md_citations(line)) end))

    assert total >= @min_md_citations,
           "court parsed only #{total} .md citations across OS rows " <>
             "(floor #{@min_md_citations}) — parse is drifting vacuous"

    for {id, line} <- rows do
      for cite <- md_citations(line) do
        path = resolve_citation(cite)

        assert File.exists?(path),
               "OS row #{id} cites receipt #{cite}, which does not exist on disk " <>
                 "(resolved: #{path})"
      end
    end
  end

  @min_cited_tests 3

  test "every cited test file in an OS row exists on disk" do
    rows = os_rows()

    total = Enum.sum(Enum.map(rows, fn {_id, line} -> length(cited_tests(line)) end))

    assert total >= @min_cited_tests,
           "court parsed only #{total} cited test files (floor #{@min_cited_tests})"

    for {id, line} <- rows do
      for t <- cited_tests(line) do
        assert File.exists?(t),
               "OS row #{id} cites test #{t}, which does not exist on disk"
      end
    end
  end
end
