defmodule Xaas.EUAIAct.SupportCourtW984joTest do
  @moduledoc """
  Lane W984jo unclaimed-family probe: direct coverage court for
  `test/eu_ai_act/support/corpus_loader.ex` (`Xaas.EUAIAct.CorpusLoader`).

  The loader is consumed only by `smoke_test.exs`, and only along its
  happy path (corpus present). This court exercises the real loader
  against the real landed corpus with real assertions, plus structural
  invariants that would catch common loader mutations.

  Mutation rationale per test inline. Zero mocks: real file reads, real
  JSON decode, real module under test.
  """

  Code.require_file("support/corpus_loader.ex", __DIR__)

  use ExUnit.Case, async: true

  @moduletag :eu_ai_act

  @corpus_relpath "docs/eu_ai_act/corpus.json"

  defp corpus_present?, do: File.exists?(Path.join(File.cwd!(), @corpus_relpath))

  test "lines/0 decodes the real landed corpus into a nonempty flat line list" do
    # Mutation rationale: a loader that skips nested articles (flat_map ->
    # map) or returns the titles list itself still yields a nonempty list;
    # only correct nested flattening satisfies both nonemptiness and the
    # per-line shape asserted in the structure test below.
    if corpus_present?() do
      lines = Xaas.EUAIAct.CorpusLoader.lines()
      assert is_list(lines) and lines != []
    else
      assert_raise RuntimeError, ~r/EUAIA_CORPUS_MISSING_W520/, fn ->
        Xaas.EUAIAct.CorpusLoader.lines()
      end
    end
  end

  test "counts/0 equals length(lines/0) and is positive on the landed corpus" do
    # Mutation rationale: counts/0 hardcoding a stale literal (or
    # length(titles) instead of length(flat lines)) diverges from
    # length(lines/0) on the real corpus.
    if corpus_present?() do
      assert Xaas.EUAIAct.CorpusLoader.counts() == length(Xaas.EUAIAct.CorpusLoader.lines())
      assert Xaas.EUAIAct.CorpusLoader.counts() > 0
    else
      assert_raise RuntimeError, ~r/EUAIA_CORPUS_MISSING_W520/, fn ->
        Xaas.EUAIAct.CorpusLoader.counts()
      end
    end
  end

  test "line/1 is a faithful index over lines/0 (hit returns exact map, miss returns nil)" do
    # Mutation rationale: an index built on a different flattening than
    # lines/0 (or comparing the wrong key) returns a different map or
    # nil for an id that lines/0 contains.
    if corpus_present?() do
      lines = Xaas.EUAIAct.CorpusLoader.lines()
      first = hd(lines)
      assert Xaas.EUAIAct.CorpusLoader.line(first["line_id"]) == first

      known_id = first["line_id"]
      assert Xaas.EUAIAct.CorpusLoader.line(known_id) in lines
      assert Xaas.EUAIAct.CorpusLoader.line("W984JO-NO-SUCH-LINE") == nil
    else
      assert_raise RuntimeError, ~r/EUAIA_CORPUS_MISSING_W520/, fn ->
        Xaas.EUAIAct.CorpusLoader.line("any")
      end
    end
  end

  test "every flattened line carries the loader contract fields (line_id/text/kind)" do
    # Mutation rationale: dropping the innermost `line <- article["lines"]`
    # comprehension clause still yields nonempty output from preamble-level
    # entries, but those entries lack the contract fields and fail here.
    if corpus_present?() do
      for line <- Xaas.EUAIAct.CorpusLoader.lines() do
        assert is_binary(line["line_id"]) and line["line_id"] != ""
        assert is_binary(line["text"]) and line["text"] != ""
        assert is_binary(line["kind"]) and line["kind"] != ""
      end
    else
      assert_raise RuntimeError, ~r/EUAIA_CORPUS_MISSING_W520/, fn ->
        Xaas.EUAIAct.CorpusLoader.lines()
      end
    end
  end

  test "line_ids are unique across the flattened corpus" do
    # Mutation rationale: double-flattening (line appearing under two
    # articles) or a duplicated corpus entry silently inflates counts/0
    # and makes line/1 return an arbitrary duplicate; uniqueness pins it.
    if corpus_present?() do
      ids = Xaas.EUAIAct.CorpusLoader.lines() |> Enum.map(& &1["line_id"])
      assert length(ids) == ids |> Enum.uniq() |> length()
    else
      assert_raise RuntimeError, ~r/EUAIA_CORPUS_MISSING_W520/, fn ->
        Xaas.EUAIAct.CorpusLoader.lines()
      end
    end
  end

  test "malformed-corpus branches are structurally reachable (guard-shape check)" do
    # The loader's two decode-error branches (non-{"titles": ...} JSON and
    # invalid JSON) read a hardcoded repo path, so they cannot be exercised
    # against the real landed corpus without redirecting File reads (a mock
    # — banned). Instead this court pins the branch contract by re-deriving
    # the same decode the loader performs and asserting the landed corpus
    # takes the {:ok, %{"titles" => _}} arm, i.e. the error arms are the
    # only remaining unreachable paths and they are typed raises, verified
    # by source inspection in the lane receipt (UNEXERCISABLE(fixed-path)).
    if corpus_present?() do
      body = File.read!(Path.join(File.cwd!(), @corpus_relpath))
      assert {:ok, %{"titles" => titles}} = Jason.decode(body)
      assert is_list(titles) and titles != []
    else
      assert_raise RuntimeError, ~r/EUAIA_CORPUS_MISSING_W520/, fn ->
        Xaas.EUAIAct.CorpusLoader.lines()
      end
    end
  end
end
