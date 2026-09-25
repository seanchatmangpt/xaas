defmodule ExNounVerbCli.Registry.GeneratedTest do
  use ExUnit.Case, async: true

  alias ExNounVerbCli.Test.CalcRegistry
  alias ExNounVerbCli.Verb

  test "list_verbs/0 returns real Verb structs built from the :verbs option" do
    verbs = CalcRegistry.list_verbs()

    assert length(verbs) == 4
    assert Enum.all?(verbs, &match?(%Verb{}, &1))

    add = Enum.find(verbs, &(&1.verb == "add"))
    assert add.noun == "calc"
    assert add.module == ExNounVerbCli.Test.CalcFixture
    assert add.function == :add
  end

  test "the using module implements the Registry behaviour" do
    assert ExNounVerbCli.Registry in CalcRegistry.module_info(:attributes)[:behaviour]
  end
end
