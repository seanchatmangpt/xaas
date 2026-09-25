defmodule ExNounVerbCli.CompletionsTest do
  use ExUnit.Case, async: true

  alias ExNounVerbCli.{Completions, Introspect}
  alias ExNounVerbCli.Test.CalcRegistry

  # ARD falsifier: every command string in a generated script must come
  # from the real registry manifest -- these tests assert containment
  # against the real fixture registry's actual nouns/verbs/flags.
  @manifest Introspect.manifest(CalcRegistry)
  @verbs @manifest["verbs"]

  test "bash script completes nouns, verbs, and per-verb option flags" do
    script = Completions.script(@manifest, :bash, "calcbench")

    for noun <- Map.keys(@manifest["nouns"]) do
      assert script =~ noun
    end

    for verb <- @verbs do
      assert script =~ verb["verb"]

      for {flag, _type} <- verb["schema"] do
        assert script =~ "--#{flag}"
      end
    end

    assert script =~ "complete -F _calcbench_completions calcbench"
    assert String.ends_with?(script, "\n")
    refute script =~ "\r\n"
  end

  test "zsh script completes nouns and verbs and registers via #compdef" do
    script = Completions.script(@manifest, :zsh, "calcbench")

    assert script =~ "#compdef calcbench"

    for noun <- Map.keys(@manifest["nouns"]) do
      assert script =~ noun
    end

    for verb <- @verbs, do: assert(script =~ verb["verb"])
  end

  test "fish script completes nouns, verbs, and per-verb long flags" do
    script = Completions.script(@manifest, :fish, "calcbench")

    assert script =~ "complete -c calcbench"

    for verb <- @verbs do
      assert script =~ verb["verb"]

      for {flag, _type} <- verb["schema"] do
        assert script =~ "-l #{flag}"
      end
    end
  end

  test "a flag absent from the registry cannot appear in any script (falsifier)" do
    for shell <- [:bash, :zsh, :fish] do
      refute Completions.script(@manifest, shell, "calcbench") =~ "--nonexistent-flag"
    end
  end
end
