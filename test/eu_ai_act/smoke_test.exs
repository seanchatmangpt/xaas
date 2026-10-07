defmodule Xaas.EUAIAct.SmokeTest do
  @moduledoc """
  Structure gate for the EU AI Act compliance suite (lane W526).

  When the W520 corpus is absent, this test asserts the typed-absent behavior
  (loader raises REFUSED(EUAIA_CORPUS_MISSING_W520)). Once W520 lands, the
  same test asserts corpus structure: every line has line_id + text + kind.

  Per-title contract (each obligation line, filled by per-title generators):

    test "EUAI-ACT <line_id>: <kind> — <short>" do
      # EVIDENCED      -> assert the real product/test path exists and passes
      # NOT_APPLICABLE -> assert/annotate with a typed reason
      # OPEN_GAP       -> flunk "OPEN_GAP: <what is missing>"  (FAILS BY DESIGN
      #                    until implemented — executable compliance pressure;
      #                    every OPEN_GAP is listed in the lane receipt)
    end
  """

  # test/support/ is not on elixirc_paths in this repo; load the loader directly.
  Code.require_file("support/corpus_loader.ex", __DIR__)

  use ExUnit.Case, async: true

  @moduletag :eu_ai_act

  @corpus_relpath "docs/eu_ai_act/corpus.json"
  @missing_message_regex ~r/EUAIA_CORPUS_MISSING_W520/

  test "corpus loads (or typed-absent when W520 has not landed)" do
    if File.exists?(Path.join(File.cwd!(), @corpus_relpath)) do
      lines = Xaas.EUAIAct.CorpusLoader.lines()
      assert is_list(lines) and lines != []
    else
      assert_raise RuntimeError, @missing_message_regex, fn ->
        Xaas.EUAIAct.CorpusLoader.lines()
      end
    end
  end

  test "every corpus line has line_id + text + kind (structure gate)" do
    if File.exists?(Path.join(File.cwd!(), @corpus_relpath)) do
      for line <- Xaas.EUAIAct.CorpusLoader.lines() do
        assert is_binary(line["line_id"]) and line["line_id"] != "",
               "missing line_id in: #{inspect(line)}"

        assert is_binary(line["text"]) and line["text"] != "",
               "missing text for #{line["line_id"]}"

        assert is_binary(line["kind"]) and line["kind"] != "",
               "missing kind for #{line["line_id"]}"
      end
    else
      assert_raise RuntimeError, @missing_message_regex, fn ->
        Xaas.EUAIAct.CorpusLoader.counts()
      end
    end
  end

  test "line/1 returns the matching line and nil for unknown ids (typed-absent honored)" do
    if File.exists?(Path.join(File.cwd!(), @corpus_relpath)) do
      first = hd(Xaas.EUAIAct.CorpusLoader.lines())
      assert Xaas.EUAIAct.CorpusLoader.line(first["line_id"]) == first
      assert Xaas.EUAIAct.CorpusLoader.line("EUAIA-DOES-NOT-EXIST") == nil
    else
      assert_raise RuntimeError, @missing_message_regex, fn ->
        Xaas.EUAIAct.CorpusLoader.line("any")
      end
    end
  end
end
