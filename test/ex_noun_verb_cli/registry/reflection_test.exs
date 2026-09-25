defmodule ExNounVerbCli.Registry.ReflectionTest do
  use ExUnit.Case, async: true

  alias ExNounVerbCli.Registry.Reflection
  alias ExNounVerbCli.Verb

  test "list_verbs/0 discovers at least one real verb from a module exporting the marker" do
    # Ensure the fixture module is loaded so the BEAM/application module
    # index actually contains it before scanning.
    Code.ensure_loaded!(ExNounVerbCli.Test.CalcFixture)

    verbs = Reflection.list_verbs()

    assert Enum.any?(verbs, fn
             %Verb{noun: "calc", verb: "add", module: ExNounVerbCli.Test.CalcFixture} -> true
             _ -> false
           end)
  end

  test "a module not exporting the marker contributes nothing" do
    refute Code.ensure_loaded?(ExNounVerbCli.Error) and
             function_exported?(ExNounVerbCli.Error, :__noun_verb_marker__, 0)
  end
end
