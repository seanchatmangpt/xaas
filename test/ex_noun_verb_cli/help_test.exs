defmodule ExNounVerbCli.HelpTest do
  use ExUnit.Case, async: true

  alias ExNounVerbCli.{Help, Introspect}
  alias ExNounVerbCli.Examples.Calc.Registry, as: ExamplesRegistry
  alias ExNounVerbCli.Test.CalcRegistry

  # Help is a projection of the manifest (ARD F1): everything rendered
  # must be implied by the manifest of the SAME registry. The examples
  # registry carries real doc strings; the test fixture does not -- both
  # shapes are asserted.
  test "renders usage, every verb, options with types and required markers" do
    help = Help.render(Introspect.manifest(CalcRegistry), "calcbench")

    assert help =~ "calcbench <noun> <verb> [options]"
    assert help =~ "--introspect [<noun>]"
    assert help =~ "--completions <bash|zsh|fish>"

    for verb <- Introspect.manifest(CalcRegistry)["verbs"] do
      assert help =~ verb["verb"]
    end

    assert help =~ "--x <integer> (required)"
    assert help =~ "--y <integer> (required)"
    assert help =~ "--profile-id <string> (required)"
  end

  test "renders doc strings when the registry carries them" do
    help = Help.render(Introspect.manifest(ExamplesRegistry), "calcbench")

    assert help =~ "Adds --x and --y."
    assert help =~ "Multiplies --x and --y."
  end

  test "the chaining quick reference comes from the manifest's own token table" do
    help = Help.render(Introspect.manifest(CalcRegistry), "calcbench")

    assert help =~ "Chaining (++ separates groups):"

    for %{"token" => token} <- Introspect.manifest(CalcRegistry)["chaining"]["tokens"] do
      assert help =~ token
    end
  end

  test "an empty verb table still renders usage and chaining, never raises" do
    help = Help.render(Introspect.manifest(CalcRegistry, "nope"), "calcbench")

    assert help =~ "calcbench <noun> <verb> [options]"
    refute help =~ "--x <integer>"
  end
end
