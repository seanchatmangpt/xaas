defmodule Docs.NavCoverageTest do
  @moduledoc """
  Nav-coverage court for the canonical documentation surface.

  Port of ggen-marketplace `tests/test_book_nav_coverage.py` to xaas conventions
  (ExUnit, no mocks). The collaborators are the real
  `docs/claude/diataxis/README.md` and the real `docs/claude/diataxis/` tree on
  disk — both read in-process; nothing is mocked or stubbed. Both directions of
  the file <-> navigation correspondence must hold:

    1. every README entry resolves to a real file (no dangling links);
    2. every markdown file under docs/claude/diataxis/ appears in the README
       (no orphans — a committed page no reader surface links to).
  """
  use ExUnit.Case, async: true

  @repo_root Path.expand("..", __DIR__)
  @diataxis Path.join(@repo_root, "docs/claude/diataxis")
  @readme Path.join(@diataxis, "README.md")

  # The index itself is the navigation surface, not an entry within it.
  @excluded_files MapSet.new(["README.md"])

  @entry_re ~r{^-\s+\[`([^`]+)`\]\(([^)]+)\)}
  @heading_re ~r{^##\s+(.+)$}

  defp readme_lines do
    @readme
    |> File.read!()
    |> String.split(["\r\n", "\n"])
  end

  defp entries do
    readme_lines()
    |> Enum.map(fn line ->
      case Regex.run(@entry_re, line) do
        [_ , label, link] -> {label, link}
        nil -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp resolve(link) do
    # Markdown links are relative to the README's own directory.
    Path.expand(link, @diataxis)
  end

  defp declared_targets do
    entries()
    |> Enum.map(fn {_label, link} -> resolve(link) end)
  end

  defp files_on_disk do
    @diataxis
    |> Path.join("**/*.md")
    |> Path.wildcard()
    |> Enum.map(&Path.expand/1)
  end

  test "README exists and declares navigation entries" do
    assert File.regular?(@readme), "missing navigation surface: #{@readme}"

    assert length(entries()) > 0,
           "docs/claude/diataxis/README.md declares no nav entries at all"

    assert File.dir?(@diataxis), "missing diataxis tree: #{@diataxis}"
  end

  test "every README nav entry resolves to a real file" do
    dangling =
      declared_targets()
      |> Enum.reject(&File.regular?/1)
      |> Enum.uniq()
      |> Enum.sort()

    assert dangling == [],
           "README nav entries with no corresponding file on disk (broken " <>
             "chapters): " <> Enum.join(dangling, ", ")
  end

  test "every markdown file under docs/claude/diataxis has a README entry (no orphans)" do
    declared = MapSet.new(declared_targets())

    orphans =
      files_on_disk()
      |> Enum.reject(&MapSet.member?(declared, &1))
      |> Enum.reject(&MapSet.member?(@excluded_files, Path.basename(&1)))
      |> Enum.sort()

    assert orphans == [],
           "these docs/claude/diataxis pages have no README entry, so they are " <>
             "absent from the canonical navigation surface: " <>
             Enum.join(orphans, ", ") <>
             ". Add an entry to docs/claude/diataxis/README.md (the fix is " <>
             "indexing, not deleting), then re-run this court."
  end

  test "README headings are non-empty (list format not silently changed)" do
    headings =
      readme_lines()
      |> Enum.map(fn line -> Regex.run(@heading_re, line) end)
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&List.last/1)

    assert length(headings) >= 5,
           "docs/claude/diataxis/README.md headings collapsed; the entry " <>
             "regex depends on `- [`label`](link)` list format under `##` sections"
  end
end
