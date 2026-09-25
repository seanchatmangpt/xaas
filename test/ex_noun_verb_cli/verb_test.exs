defmodule ExNounVerbCli.VerbTest do
  use ExUnit.Case, async: true

  alias ExNounVerbCli.Verb

  test "new/1 builds a real struct from a keyword list" do
    verb = Verb.new(noun: "calc", verb: "add", module: Kernel, function: :+, doc: "adds")

    assert %Verb{noun: "calc", verb: "add", module: Kernel, function: :+, doc: "adds"} = verb
    assert verb.info == %{}
  end

  test "new/1 builds a real struct from a map" do
    verb = Verb.new(%{noun: "calc", verb: "multiply", module: Kernel, function: :*})

    assert verb.noun == "calc"
    assert verb.verb == "multiply"
  end

  test "new/1 raises ArgumentError naming the missing field when noun is absent" do
    error =
      assert_raise ArgumentError, fn ->
        Verb.new(verb: "add", module: Kernel, function: :+)
      end

    assert error.message =~ ":noun"
  end

  test "new/1 raises ArgumentError naming all missing fields" do
    error =
      assert_raise ArgumentError, fn ->
        Verb.new(noun: "calc")
      end

    assert error.message =~ ":verb"
    assert error.message =~ ":module"
    assert error.message =~ ":function"
  end
end
